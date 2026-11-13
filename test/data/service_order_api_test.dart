import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/network/api_client.dart';
import 'package:monitoreo/core/utils/mexico_time.dart';
import 'package:monitoreo/core/utils/uuid.dart';
import 'package:monitoreo/data/repositories/service_order_repository_impl.dart';
import 'package:monitoreo/domain/entities/service_order.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response textResponse(String body, int status) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );

/// Catálogo del ejemplo de la guía (§2).
const catalogResponse = {
  'data': [
    {
      'secciones': {
        'vehiculo_cuenta_con': [
          {
            'clave': 'inmovilizador',
            'nombre': 'Inmovilizador',
            'obligatorio': false
          },
        ],
        'pruebas': [
          {'clave': 'transmision', 'nombre': 'Transmisión'},
          {'clave': 'boton_panico', 'nombre': 'Botón de pánico'},
          {'clave': 'paro_motor', 'nombre': 'Paro de motor'},
        ],
        'fotos': [
          {
            'clave': 'tablero_inicio',
            'nombre': 'Tablero al iniciar',
            'obligatorio': true
          },
          {
            'clave': 'tablero_final',
            'nombre': 'Tablero al finalizar',
            'obligatorio': true
          },
          {
            'clave': 'falla_extra_1',
            'nombre': 'Imagen extra 1',
            'obligatorio': false
          },
          {
            'clave': 'equipo_existente',
            'nombre': 'Equipo existente',
            'obligatorio': false
          },
        ],
        'firmas': [
          {'clave': 'firma_cliente', 'obligatorio': true},
          {'clave': 'firma_tecnico', 'obligatorio': true},
        ],
      },
      'monitoristas': [
        {'id': 15, 'nombre': 'Ana López Ruiz'},
      ],
    },
  ],
};

/// Orden de mantenimiento en borrador con los campos de §3.
const maintenanceOrder = {
  'id': 42,
  'folio': 'OS-000042',
  'estatus': 'borrador',
  'origen': 'agenda',
  'tipoProgramado': 'revision',
  'tipoServicio': 'c_equipo',
  'cita': '2026-10-30T10:00:00.000Z',
  'citaFin': '2026-10-30T12:00:00.000Z',
  'nombreProgramo': 'Laura Operación',
  'observaciones': 'Cliente reporta que no transmite',
  'idCliente': 12,
  'nombreCliente': 'Transportes del Sur',
  'placa': 'ABC1234',
  'numeroEconomico': 'ECO-7',
  'nombreProducto': null,
  'idInstalacionProgramada': 340,
  'idInstalacion': 340,
  'idProducto': 812,
  'referenciaCrm': 'CRM-99',
  'unidad': 2,
  'unidadesTotal': 5,
  'codigoValidado': 1,
  'autorizacion': null,
  'pruebas': [
    {
      'clave': 'transmision',
      'estatus': 'correcta',
      'fechaSolicitud': '2026-10-30T10:42:00.000Z',
      'notaTecnico': 'presioné el pánico 10:42',
      'fechaValidacion': '2026-10-30T10:45:00.000Z',
      'nombreValido': 'Ana López Ruiz',
      'notaOperador': 'Llegó el evento',
    },
    {'clave': 'boton_panico', 'estatus': 'solicitada'},
  ],
  'respuestas': [
    {'seccion': 'vehiculo_cuenta_con', 'clave': 'inmovilizador', 'valor': 1},
  ],
  'archivos': [
    {
      'clave': 'tablero_inicio',
      'fechaCreacion': '2026-10-30T10:40:00.000Z',
      'url': 'https://s3.test/tablero.jpg',
    },
  ],
  'faltantesParaCerrar': [
    'Falta el monitorista',
    'Faltan archivos: firma_cliente'
  ],
  'claveMotivo': null,
};

void main() {
  late List<http.Request> requests;
  late ServiceOrderRepositoryImpl repository;

  void setUpWith(Future<http.Response> Function(http.Request) handler) {
    requests = [];
    repository = ServiceOrderRepositoryImpl(ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    ));
  }

  Map<String, dynamic> body(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  final ok = jsonResponse({
    'status': 'success',
    'data': {'id': 42, 'nombre': 'OS-000042'},
  });

  test('claveApp es un UUID v4', () {
    final key = uuidV4();
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
              r'[0-9a-f]{12}$')
          .hasMatch(key),
      isTrue,
    );
    expect(uuidV4(), isNot(key));
  });

  group('catálogos (§2)', () {
    test('secciones, obligatorios y monitoristas; se guarda en caché',
        () async {
      setUpWith((_) async => jsonResponse(catalogResponse));

      final catalog = await repository.getCatalog();
      await repository.getCatalog();

      expect(requests.single.url.path, '/ordenes-servicio/catalogo');
      expect(catalog.section(ServiceOrderSection.tests).map((o) => o.key),
          ['transmision', 'boton_panico', 'paro_motor']);
      expect(catalog.monitors.single.name, 'Ana López Ruiz');
    });

    test('motivos: solo no_cumplida y técnico', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                'clave': 'cliente_ausente',
                'nombre': 'Cliente ausente',
                'resultado': ['no_cumplida'],
                'quien': ['tecnico'],
                'requiereObservaciones': false,
              },
              {
                'clave': 'otro_tecnico',
                'nombre': 'Otro',
                'resultado': ['no_cumplida'],
                'quien': ['tecnico', 'operacion'],
                'requiereObservaciones': true,
              },
              {
                'clave': 'cliente_cancela',
                'nombre': 'Cliente cancela',
                'resultado': ['cancelada'],
                'quien': ['operacion'],
              },
              {
                'clave': 'solo_operacion',
                'nombre': 'Solo operación',
                'resultado': ['no_cumplida'],
                'quien': ['operacion'],
              },
            ],
          }));

      final reasons = await repository.getReasons();

      expect(requests.single.url.path, '/ordenes-servicio/motivos');
      expect(reasons.map((r) => r.key), ['cliente_ausente', 'otro_tecnico']);
      expect(reasons.last.requiresObservations, isTrue);
    });
  });

  group('agenda y detalle (§3)', () {
    test('agenda con ?estatus=programada y paginación', () async {
      setUpWith((_) async => jsonResponse({
            'data': [maintenanceOrder],
            'paginated': {'total': 51, 'page': 1, 'limit': 50},
          }));

      final page = await repository.listOrders(
        status: ServiceOrderStatus.programada,
      );

      final url = requests.single.url;
      expect(url.path, '/ordenes-servicio/paginado/1/50');
      expect(url.queryParameters, {'estatus': 'programada'});
      expect(page.items.single.folio, 'OS-000042');
      expect(page.hasMore, isTrue);
    });

    test('historial no cumplidas usa no_cumplida', () async {
      setUpWith((_) async => jsonResponse({'data': []}));
      await repository.listOrders(status: ServiceOrderStatus.noCumplida);
      expect(requests.single.url.queryParameters['estatus'], 'no_cumplida');
    });

    test('detalle: lee todos los campos útiles', () async {
      setUpWith((_) async => jsonResponse({
            'data': [maintenanceOrder],
          }));

      final order = await repository.getOrder('42');

      expect(order.status, ServiceOrderStatus.borrador);
      expect(order.scheduledType, ServiceType.revision);
      expect(order.type, ServiceType.cEquipo);
      expect(order.isLegacy, isFalse);
      expect(order.clientName, 'Transportes del Sur');
      expect(order.vehicleLabel, 'ABC1234 · ECO-7');
      expect(order.unitLabel, 'Unidad 2 de 5');
      expect(order.scheduledInstallationId, '340');
      expect(order.codeValidated, isTrue);
      expect(order.requiresCode, isFalse);
      expect(order.hasImmobilizer, isTrue);
      expect(order.test('transmision')!.status, TestStatus.correcta);
      expect(order.test('transmision')!.validatedBy, 'Ana López Ruiz');
      expect(order.hasPendingTests, isTrue);
      expect(order.file('tablero_inicio')!.url, 'https://s3.test/tablero.jpg');
      expect(order.missingToClose, hasLength(2));

      // Hora de pared de la Ciudad de México: se muestra tal cual.
      final wall = MexicoCityTime.from(order.appointment!);
      expect([wall.day, wall.hour], [30, 10]);
    });

    test('detalle: equipo en texto y fotos del vehículo', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                ...maintenanceOrder,
                'instalacion': {
                  'idInstalacion': 340,
                  'tipoEquipo': 'AVL',
                  'dispositivo': 'Suntech ST210 E - IMEI 1111 - Serie: 01',
                  'sim': 'Telcel - ICCID 0001 - Tel: 7770000000',
                },
                'instalacionResultado': {
                  'tipoEquipo': 'AVL',
                  'dispositivo': 'Suntech ST210 I - IMEI 3333 - Serie: 03',
                  'sim': 'Telcel - ICCID 9999 - Tel: 7774859896',
                },
                'fotosVehiculo': [
                  {
                    'clave': 'fotoFrente',
                    'nombre': 'Frontal',
                    'url': 'https://s3.test/frente.jpg',
                  },
                  {
                    'clave': 'foto',
                    'nombre': 'Principal',
                    'url': 'https://s3.test/principal.jpg',
                  },
                  {'clave': 'sin_url', 'nombre': 'Sin URL'},
                ],
              },
            ],
          }));

      final order = await repository.getOrder('42');

      expect(
          order.equipment!.device, 'Suntech ST210 I - IMEI 3333 - Serie: 03');
      expect(order.equipment!.sim, 'Telcel - ICCID 9999 - Tel: 7774859896');
      expect(order.installation!.device, contains('IMEI 1111'));
      expect(order.vehiclePhotos.map((p) => p.name), ['Frontal', 'Principal']);
      expect(order.vehiclePhoto!.url, 'https://s3.test/principal.jpg');
    });

    test('alta en curso: equipo nuevo en texto, separando el tipo', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                ...maintenanceOrder,
                'tipoServicio': 'instalacion',
                'instalacion': {
                  'tipoEquipo': 'AVL',
                  'dispositivo': 'Equipo encontrado - IMEI 1111',
                },
                'dispositivoNuevo':
                    'AVL - Suntech ST210 - IMEI 3333 - Serie: 0003333',
                'simNuevo': 'Telcel - ICCID 0009999 - Tel: 7774859896',
              },
            ],
          }));

      final order = await repository.getOrder('42');

      expect(order.equipment!.equipmentType, 'AVL');
      expect(order.equipment!.device,
          'Suntech ST210 - IMEI 3333 - Serie: 0003333');
      expect(order.equipment!.sim, 'Telcel - ICCID 0009999 - Tel: 7774859896');
    });

    test('alta en curso: equipo nuevo como objeto', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                ...maintenanceOrder,
                'tipoServicio': 'instalacion',
                'dispositivoNuevo': {
                  'tipoEquipo': 'AVL',
                  'dispositivo': 'Suntech ST210 - IMEI 3333',
                },
                'simNuevo': {'iccid': '0009999', 'telefono': '7774859896'},
              },
            ],
          }));

      final equipment = (await repository.getOrder('42')).equipment!;

      expect(equipment.equipmentType, 'AVL');
      expect(equipment.device, 'Suntech ST210 - IMEI 3333');
      expect(equipment.sim, 'ICCID 0009999 - Tel: 7774859896');
    });

    test('sin foto Principal no se usa otra foto del vehículo', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                ...maintenanceOrder,
                'fotosVehiculo': [
                  {
                    'clave': 'fotoFrente',
                    'nombre': 'Frontal',
                    'url': 'https://s3.test/frente.jpg',
                  },
                ],
              },
            ],
          }));

      final order = await repository.getOrder('42');

      expect(order.vehiclePhotos, hasLength(1));
      expect(order.vehiclePhoto, isNull);
    });

    test('detalle sin equipo ni fotos del vehículo', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                ...maintenanceOrder,
                'instalacionResultado': null,
                'fotosVehiculo': [],
              },
            ],
          }));

      final order = await repository.getOrder('42');

      expect(order.equipment, isNull);
      expect(order.vehiclePhotos, isEmpty);
      expect(order.vehiclePhoto, isNull);
    });

    test('alta sobre vehículo con equipo: necesita autorización', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                'id': 7,
                'folio': 'OS-000007',
                'estatus': 'borrador',
                'tipoProgramado': 'instalacion',
                'tipoServicio': 'instalacion',
                'idProducto': 812,
                'autorizacion': null,
                'faltantesParaCerrar': [
                  'El vehículo ya tiene un equipo instalado: pide '
                      'autorización para desinstalarlo',
                ],
              },
            ],
          }));

      final order = await repository.getOrder('7');
      expect(order.needsAuthorization, isTrue);
      expect(order.vehicleLocked, isFalse);
    });

    test('404: la orden ya no es del técnico', () async {
      setUpWith((_) async => textResponse('No existe la orden', 404));
      await expectLater(
        repository.getOrder('42'),
        throwsA(isA<Failure>().having((e) => e.isNotFound, 'isNotFound', true)),
      );
    });
  });

  group('iniciar (§4)', () {
    test('alta: solo claveApp', () async {
      setUpWith((_) async => ok);

      final ref = await repository.startOrder('42', appKey: 'clave-1');

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/ordenes-servicio/42/iniciar');
      expect(body(request), {'claveApp': 'clave-1'});
      expect(ref.folio, 'OS-000042');
    });

    test('mantenimiento: tipo real e instalación distinta', () async {
      setUpWith((_) async => ok);

      await repository.startOrder(
        '42',
        appKey: 'clave-1',
        type: ServiceType.cEquipo,
        installationId: '340',
      );

      expect(body(requests.single), {
        'claveApp': 'clave-1',
        'tipoServicio': 'c_equipo',
        'idInstalacion': 340,
      });
    });

    test('409: ya no está programada', () async {
      setUpWith((_) async =>
          textResponse('La orden está cancelada; no se puede iniciar', 409));
      await expectLater(
        repository.startOrder('42', appKey: 'clave-1'),
        throwsA(isA<ServerFailure>()
            .having((e) => e.isConflict, 'isConflict', true)
            .having((e) => e.message, 'message', contains('cancelada'))),
      );
    });
  });

  group('checklist, archivos y vehículo (§5)', () {
    test('guardado parcial: solo lo indicado, null para borrar', () async {
      setUpWith((_) async => ok);

      await repository.updateOrder(
        '42',
        ServiceOrderUpdate(
          productId: '812',
          newDeviceId: '981',
          outgoingStatus: OutgoingStatus.laboratorio.id,
          monitorId: '15',
          capturedAt: DateTime.utc(2026, 10, 30, 16, 42),
          clear: const {'lat', 'lng'},
          answers: const [
            ServiceOrderAnswer('vehiculo_cuenta_con', 'inmovilizador', true),
          ],
        ),
      );

      final sent = body(requests.single);
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, '/ordenes-servicio/42');
      expect(sent['idProducto'], 812);
      expect(sent['idDispositivoNuevo'], 981);
      expect(sent['estatusSalienteAnterior'], 4);
      expect(sent['idMonitorista'], 15);
      expect(sent['lat'], isNull);
      expect(sent.containsKey('lng'), isTrue);
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')
            .hasMatch(sent['fechaCaptura'] as String),
        isTrue,
      );
      expect(sent['respuestas'], [
        {
          'seccion': 'vehiculo_cuenta_con',
          'clave': 'inmovilizador',
          'valor': true
        },
      ]);
      expect(sent.containsKey('idSimNuevo'), isFalse);
    });

    test('estatus del que sale: solo 3, 4 y 5', () {
      expect(OutgoingStatus.values.map((s) => s.id), [3, 4, 5]);
      expect(RemovalStatus.values.map((s) => s.id), [0, 5]);
    });

    test('guardado parcial vacío no llama al API', () async {
      setUpWith((_) async => jsonResponse({}));
      await repository.updateOrder('42', const ServiceOrderUpdate());
      expect(requests, isEmpty);
    });

    test('archivo: multipart con campo "file"; PNG tal cual', () async {
      setUpWith((_) async => jsonResponse({'status': 'success'}));
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 4, height: 4)),
      );
      await repository.uploadFile('42', 'tablero_inicio', png,
          label: 'Tablero al iniciar');
      final request = requests.single;
      expect(request.url.path, '/ordenes-servicio/42/archivos/tablero_inicio');
      final text = latin1.decode(request.bodyBytes);
      expect(text, contains('name="file"; filename="tablero_inicio.png"'));
      expect(text.toLowerCase(), contains('content-type: image/png'));
    });

    test('archivo en otro formato se convierte a JPG', () async {
      setUpWith((_) async => jsonResponse({'status': 'success'}));
      final bmp = Uint8List.fromList(
        img.encodeBmp(img.Image(width: 4, height: 4)),
      );
      await repository.uploadFile('42', 'falla_extra_1', bmp,
          label: 'Imagen extra 1');
      final text = latin1.decode(requests.single.bodyBytes);
      expect(text, contains('filename="falla_extra_1.jpg"'));
      expect(text.toLowerCase(), contains('content-type: image/jpeg'));
    });

    test('archivo no legible como imagen: no se envía', () async {
      setUpWith((_) async => jsonResponse({}));
      await expectLater(
        repository.uploadFile(
          '42',
          'firma_cliente',
          Uint8List.fromList(List.filled(32, 7)),
          label: 'Firma del cliente',
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(requests, isEmpty);
    });
  });

  test('autorización (§7)', () async {
    setUpWith(
        (_) async => jsonResponse({'message': 'Autorización solicitada'}));
    await repository.requestAuthorization(
      '7',
      observations: ' GPS de otra marca bajo el tablero ',
    );
    expect(requests.single.url.path, '/ordenes-servicio/7/autorizacion');
    expect(body(requests.single),
        {'observaciones': 'GPS de otra marca bajo el tablero'});
  });

  test('autorización de un equipo de otro proveedor (reporte manual)',
      () async {
    setUpWith(
        (_) async => jsonResponse({'message': 'Autorización solicitada'}));
    await repository.requestAuthorization(
      '7',
      observations: 'GPS de otro proveedor',
      thirdParty: true,
    );
    expect(body(requests.single), {
      'observaciones': 'GPS de otro proveedor',
      'equipoTercero': true,
    });
  });

  group('código de verificación (§8)', () {
    test('pedir: sin cuerpo y con la expiración', () async {
      setUpWith((_) async => jsonResponse({
            'status': 'success',
            'message': 'Código generado',
            'data': {'id': 42, 'nombre': 'OS-000042'},
            'expira': '2026-10-30T10:57:00.000Z',
          }));

      final request = await repository.requestCode('42');

      expect(requests.single.url.path, '/ordenes-servicio/42/codigo');
      expect(requests.single.body, isEmpty);
      final wall = MexicoCityTime.from(request.expiresAt!);
      expect([wall.hour, wall.minute], [10, 57]);
    });

    test('validar: 6 dígitos; incorrecto muestra los intentos', () async {
      setUpWith((_) async =>
          textResponse('Código incorrecto (quedan 4 intentos)', 400));

      await expectLater(
        repository.validateCode('42', '482913'),
        throwsA(isA<ServerFailure>()
            .having((e) => e.message, 'message', contains('quedan 4'))),
      );
      expect(requests.single.url.path, '/ordenes-servicio/42/codigo/validar');
      expect(body(requests.single), {'codigo': '482913'});
    });
  });

  test('pruebas: solicitar con nota opcional (§9)', () async {
    setUpWith((_) async => ok);
    await repository.requestTest('42', 'boton_panico',
        observations: 'presioné el pánico 10:42');
    await repository.requestTest('42', 'transmision');

    expect(requests.first.url.path,
        '/ordenes-servicio/42/pruebas/boton_panico/solicitar');
    expect(body(requests.first), {'observaciones': 'presioné el pánico 10:42'});
    expect(requests.last.body, isEmpty);
  });

  group('cerrar y no cumplida (§10, §11)', () {
    test('cerrar: devuelve folio e instalación resultante', () async {
      setUpWith((_) async => jsonResponse({
            'status': 'success',
            'message': 'Orden de servicio cerrada',
            'data': {
              'id': 42,
              'nombre': 'OS-000042',
              'idInstalacionResultado': 77
            },
          }));
      final result = await repository.closeOrder('42');
      expect(requests.single.url.path, '/ordenes-servicio/42/cerrar');
      expect(result.folio, 'OS-000042');
      expect(result.resultingInstallationId, '77');
    });

    test('cerrar incompleta: 400 JSON con faltantes', () async {
      setUpWith((_) async => jsonResponse({
            'message': 'La orden está incompleta',
            'faltantes': [
              'Falta el monitorista',
              'Faltan archivos: firma_cliente'
            ],
          }, 400));
      await expectLater(
        repository.closeOrder('42'),
        throwsA(isA<IncompleteOrderFailure>().having(
          (e) => e.missing,
          'missing',
          ['Falta el monitorista', 'Faltan archivos: firma_cliente'],
        )),
      );
    });

    test('cerrar con otro 400 en texto mantiene el mensaje', () async {
      setUpWith(
          (_) async => textResponse('La orden ya no está en borrador', 400));
      await expectLater(
        repository.closeOrder('42'),
        throwsA(isA<ServerFailure>().having(
            (e) => e.message, 'message', 'La orden ya no está en borrador')),
      );
    });

    test('no cumplida: motivo y observaciones', () async {
      setUpWith((_) async => ok);
      await repository.markNotCompleted(
        '42',
        reasonKey: 'cliente_ausente',
        observations: 'Nadie abrió',
      );
      await repository.markNotCompleted('42', reasonKey: 'cliente_ausente');

      expect(requests.first.url.path, '/ordenes-servicio/42/no-cumplida');
      expect(body(requests.first),
          {'claveMotivo': 'cliente_ausente', 'observaciones': 'Nadie abrió'});
      expect(body(requests.last), {'claveMotivo': 'cliente_ausente'});
    });
  });

  group('PDF y compartir (§12)', () {
    test('PDF: bytes sin decodificar', () async {
      final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 prueba'));
      setUpWith((_) async => http.Response.bytes(pdf, 200,
          headers: {'content-type': 'application/pdf'}));

      final bytes = await repository.downloadPdf('42');

      expect(requests.single.url.path, '/ordenes-servicio/42/pdf');
      expect(requests.single.headers['Accept'], 'application/pdf');
      expect(bytes, pdf);
    });

    test('compartir: teléfono solo con dígitos y enlace de WhatsApp', () async {
      setUpWith((_) async => jsonResponse({
            'data': [
              {
                'id': 1,
                'folio': 'OS-000042',
                'url': 'https://next.test/pdf/abc',
                'vigenciaHoras': 168,
                'whatsapp': 'https://wa.me/527771234567?text=OS-000042',
              },
            ],
          }));

      final link = await repository.shareOrder('42', phone: '777 123 4567');

      expect(requests.single.url.path, '/ordenes-servicio/42/compartir');
      expect(body(requests.single), {'telefono': '7771234567'});
      expect(link.whatsappUrl, startsWith('https://wa.me/'));
      expect(link.validHours, 168);
    });

    test('enviar por correo: lista de correos', () async {
      setUpWith((_) async =>
          jsonResponse({'status': 'success', 'message': 'Correo enviado'}));

      final message = await repository.sendByEmail(
        '42',
        ['cliente@empresa.com', ' otro@empresa.com '],
      );

      expect(requests.single.url.path, '/ordenes-servicio/42/enviar-correo');
      expect(body(requests.single), {
        'correos': ['cliente@empresa.com', 'otro@empresa.com'],
      });
      expect(message, 'Correo enviado');
    });
  });

  test('instalación vigente: solo la del vehículo pedido y estatus 1',
      () async {
    setUpWith((_) async => jsonResponse({
          'data': [
            {'idInstalacion': 1, 'idProducto': 999, 'estatusInstalacion': 1},
            {'idInstalacion': 2, 'estatusInstalacion': 1},
            {'idInstalacion': 3, 'idProducto': 812, 'estatusInstalacion': 3},
            {'idInstalacion': 4, 'idProducto': 812, 'estatusInstalacion': 1},
          ],
        }));

    final current = await repository.findCurrentInstallation(productId: '812');

    expect(body(requests.single)['idProducto'], 812);
    expect(current!.id, '4');
  });
}
