import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/data/datasources/local/local_storage.dart';
import 'package:monitoreo/data/datasources/local/order_key_storage.dart';
import 'package:monitoreo/domain/entities/service_order.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/presentation/service_order/service_order_flow_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_service_order_repository.dart';

void main() {
  late FakeServiceOrderRepository repository;
  late MemoryOrderKeyStorage keys;

  ServiceOrderFlowController controllerFor(
    ServiceOrderRecord order, {
    DeviceLocation? location = (lat: 18.9, lng: -99.2),
    Duration pollInterval = const Duration(milliseconds: 20),
  }) {
    repository = FakeServiceOrderRepository(order);
    keys = MemoryOrderKeyStorage();
    return ServiceOrderFlowController(
      repository: repository,
      keyStorage: keys,
      orderId: order.id,
      readLocation: () async => location,
      clock: () => DateTime.utc(2026, 10, 30, 16, 42),
      pollInterval: pollInterval,
    );
  }

  group('pasos según el tipo', () {
    test('alta: vehículo, instalación, checklist, pruebas y resumen', () async {
      final controller = controllerFor(scheduledOrder(
        type: ServiceType.instalacion,
        status: ServiceOrderStatus.borrador,
      ));
      await controller.load();
      expect(controller.steps, [
        ServiceOrderStep.vehicle,
        ServiceOrderStep.installation,
        ServiceOrderStep.checklist,
        ServiceOrderStep.tests,
        ServiceOrderStep.summary,
      ]);
      // Sin vehículo fijado no se puede avanzar.
      expect(controller.isBlocking(ServiceOrderStep.vehicle), isTrue);
      expect(controller.canEnter(ServiceOrderStep.installation), isFalse);
    });

    test('mantenimiento programado: pide código antes de la instalación',
        () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
      ));
      await controller.load();
      expect(controller.steps.first, ServiceOrderStep.verification);
      expect(controller.currentStep, ServiceOrderStep.verification);
      controller.next();
      expect(controller.currentStep, ServiceOrderStep.verification,
          reason: 'sin código validado no avanza');
    });

    test('borrador sin origen (etapa 1): no pide código', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
        origin: null,
      ).copyLegacy());
      await controller.load();
      expect(controller.steps, isNot(contains(ServiceOrderStep.verification)));
      expect(controller.order!.technicianAnswersTests, isTrue);
    });

    test('al retomar abre el primer paso bloqueado', () async {
      final controller = controllerFor(scheduledOrder(
        type: ServiceType.instalacion,
        status: ServiceOrderStatus.borrador,
        productId: '812',
        authorization: AuthorizationStatus.pendiente,
      ));
      await controller.load();
      expect(controller.currentStep, ServiceOrderStep.vehicle);
      expect(controller.isPolling, isTrue);
      controller.dispose();
    });
  });

  group('iniciar (§4)', () {
    test('usa la claveApp guardada al reintentar y registra la llegada',
        () async {
      final controller = controllerFor(scheduledOrder());
      await controller.load();
      repository.failures['start'] = const NetworkFailure('Sin conexión');

      await expectLater(
        controller.start(type: ServiceType.revision),
        throwsA(isA<NetworkFailure>()),
      );
      repository.onAction = (action, repo) {
        if (action == 'start') {
          repo.order = scheduledOrder(status: ServiceOrderStatus.borrador);
        }
      };
      await controller.start(type: ServiceType.revision);

      expect(repository.started, hasLength(2));
      expect(repository.started.first.$2, repository.started.last.$2,
          reason: 'la misma claveApp en el reintento');
      // El tipo programado no se reenvía.
      expect(repository.started.last.$3, isNull);
      final arrival = repository.updates.single;
      expect(arrival['lat'], 18.9);
      expect(arrival['fechaCaptura'], isNotNull);
      expect(controller.status, ServiceOrderStatus.borrador);
    });

    test('envía el tipo real cuando cambia y la instalación elegida', () async {
      final controller = controllerFor(scheduledOrder());
      await controller.load();
      await controller.start(type: ServiceType.cEquipo, installationId: '77');
      expect(repository.started.single.$3, ServiceType.cEquipo);
      expect(repository.started.single.$4, '77');
    });

    test('sin permiso de ubicación manda lat y lng en null', () async {
      final controller = controllerFor(scheduledOrder(), location: null);
      await controller.load();
      await controller.start();
      final arrival = repository.updates.single;
      expect(arrival.containsKey('lat'), isTrue);
      expect(arrival['lat'], isNull);
      expect(arrival['lng'], isNull);
    });
  });

  group('errores (§13)', () {
    test('404: la orden ya no es del técnico', () async {
      final controller = controllerFor(scheduledOrder());
      await controller.load();
      repository.failures['start'] =
          const ServerFailure('No encontrada', statusCode: 404);
      await expectLater(controller.start(), throwsA(isA<Failure>()));
      expect(controller.isGone, isTrue);
    });

    test('409: recarga la orden antes de reportar', () async {
      final controller = controllerFor(scheduledOrder());
      await controller.load();
      final before = repository.getOrderCalls;
      repository.failures['start'] = const ServerFailure(
        'La orden está cancelada; no se puede iniciar',
        statusCode: 409,
      );
      repository.order = scheduledOrder(status: ServiceOrderStatus.cancelada);

      await expectLater(controller.start(), throwsA(isA<Failure>()));

      expect(repository.getOrderCalls, before + 1);
      expect(controller.status, ServiceOrderStatus.cancelada);
    });
  });

  group('código de verificación (§8)', () {
    test('el sexto código (409) muestra el aviso de operación', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
      ));
      await controller.load();
      repository.failures['code'] = const ServerFailure(
        'Se alcanzó el máximo de códigos',
        statusCode: 409,
      );

      await expectLater(
        controller.requestCode(),
        throwsA(isA<Failure>().having(
          (e) => e.message,
          'message',
          ServiceOrderFlowController.codesExhaustedMessage,
        )),
      );
      expect(controller.codesExhausted, isTrue);
    });

    test('validado: desbloquea la instalación', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
      ));
      await controller.load();
      await controller.requestCode();
      expect(controller.codeRequest, isNotNull);

      repository.onAction = (action, repo) {
        if (action.startsWith('validate:')) {
          repo.order = scheduledOrder(
            status: ServiceOrderStatus.borrador,
            codeValidated: true,
          );
        }
      };
      await controller.validateCode('482913');
      expect(repository.calls, contains('validate:482913'));
      controller.next();
      expect(controller.currentStep, ServiceOrderStep.installation);
    });
  });

  group('autorización y pruebas: consulta periódica', () {
    test('pendiente → autorizada deja de consultar y desbloquea', () async {
      final controller = controllerFor(scheduledOrder(
        type: ServiceType.instalacion,
        status: ServiceOrderStatus.borrador,
        productId: '812',
        missing: const [
          'El vehículo ya tiene un equipo instalado: pide autorización',
        ],
      ));
      await controller.load();
      expect(controller.order!.needsAuthorization, isTrue);

      repository.onAction = (action, repo) {
        if (action == 'authorization') {
          repo.order = scheduledOrder(
            type: ServiceType.instalacion,
            status: ServiceOrderStatus.borrador,
            productId: '812',
            authorization: AuthorizationStatus.pendiente,
          );
        }
      };
      await controller.requestAuthorization(
        photo: Uint8List.fromList([1, 2, 3]),
        photoLabel: 'Equipo encontrado',
        observations: 'GPS de otra marca',
      );
      expect(repository.uploads.single.$1, 'equipo_existente');
      expect(controller.isPolling, isTrue);
      expect(controller.isBlocking(ServiceOrderStep.vehicle), isTrue);

      repository.order = scheduledOrder(
        type: ServiceType.instalacion,
        status: ServiceOrderStatus.borrador,
        productId: '812',
        authorization: AuthorizationStatus.autorizada,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.order!.authorization, AuthorizationStatus.autorizada);
      expect(controller.isPolling, isFalse);
      expect(controller.isBlocking(ServiceOrderStep.vehicle), isFalse);
      controller.dispose();
    });

    test('rechazada: la orden queda no cumplida', () async {
      final controller = controllerFor(scheduledOrder(
        type: ServiceType.instalacion,
        status: ServiceOrderStatus.borrador,
        productId: '812',
        authorization: AuthorizationStatus.pendiente,
      ));
      await controller.load();
      repository.order = scheduledOrder(
        type: ServiceType.instalacion,
        status: ServiceOrderStatus.noCumplida,
        productId: '812',
        authorization: AuthorizationStatus.rechazada,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.status, ServiceOrderStatus.noCumplida);
      expect(controller.isPolling, isFalse);
      controller.dispose();
    });

    test('una prueba solicitada se consulta hasta tener resultado', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
      ));
      await controller.load();
      repository.onAction = (action, repo) {
        if (action == 'test:transmision') {
          repo.order = scheduledOrder(
            status: ServiceOrderStatus.borrador,
            codeValidated: true,
            tests: const [
              ServiceOrderTest(
                  key: 'transmision', status: TestStatus.solicitada),
            ],
          );
        }
      };
      await controller.requestTest('transmision', observations: '10:42');
      expect(repository.requestedTests.single, ('transmision', '10:42'));
      expect(controller.isPolling, isTrue);

      repository.order = scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
        tests: const [
          ServiceOrderTest(key: 'transmision', status: TestStatus.correcta),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
          controller.order!.test('transmision')!.status, TestStatus.correcta);
      expect(controller.isPolling, isFalse);
      controller.dispose();
    });
  });

  group('guardar', () {
    test('checklist: respuestas y fotos sin reenviar las ya subidas', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
      ));
      await controller.load();
      final photo = Uint8List.fromList([9, 9, 9]);
      for (var i = 0; i < 2; i++) {
        await controller.saveChecklist(
          answers: const [
            ServiceOrderAnswer('vehiculo_cuenta_con', 'inmovilizador', true),
          ],
          photos: {'tablero_inicio': ('Tablero al iniciar', photo)},
        );
      }
      expect(repository.updates, hasLength(2));
      expect(repository.uploads, hasLength(1));
    });

    test('pruebas y firmas: monitorista, observaciones y llegada pendiente',
        () async {
      final controller = controllerFor(const ServiceOrderRecord(
        id: '9',
        folio: 'OS-000009',
        typeKey: 'desinstalacion',
        scheduledTypeKey: 'desinstalacion',
        statusKey: 'borrador',
        origin: 'agenda',
        codeValidated: true,
      ));
      await controller.load();
      await controller.saveClosingData(
        monitorId: '15',
        observations: ' Cable sulfatado ',
        testAnswers: const [ServiceOrderAnswer('pruebas', 'transmision', true)],
        signatures: {
          'firma_cliente': ('Firma del cliente', Uint8List.fromList([1])),
        },
      );
      final sent = repository.updates.single;
      expect(sent['idMonitorista'], 15);
      expect(sent['observaciones'], 'Cable sulfatado');
      expect(sent['respuestas'], [
        {'seccion': 'pruebas', 'clave': 'transmision', 'valor': true},
      ]);
      expect(sent['fechaCaptura'], isNotNull,
          reason: 'la orden no tenía fecha de captura');
      expect(repository.uploads.single.$1, 'firma_cliente');
    });
  });

  group('cerrar y no cumplida', () {
    test('cerrar borra la claveApp guardada', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
      ));
      await controller.load();
      keys.keys['42'] = 'clave-x';
      repository.onAction = (action, repo) {
        if (action == 'close') {
          repo.order = scheduledOrder(status: ServiceOrderStatus.cerrada);
        }
      };
      final result = await controller.close();
      expect(result.folio, 'OS-000042');
      expect(keys.keys, isEmpty);
      expect(controller.status, ServiceOrderStatus.cerrada);
    });

    test('cerrar incompleta recarga la orden y avisa', () async {
      final controller = controllerFor(scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
      ));
      await controller.load();
      repository.failures['close'] =
          const IncompleteOrderFailure('Incompleta', ['Falta el monitorista']);
      repository.order = scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
        missing: const ['Falta el monitorista'],
      );
      await expectLater(
        controller.close(),
        throwsA(isA<IncompleteOrderFailure>()),
      );
      expect(controller.order!.missingToClose, ['Falta el monitorista']);
    });

    test('no cumplida sin iniciar: primero inicia', () async {
      final controller = controllerFor(scheduledOrder());
      await controller.load();
      await controller.markNotCompleted(reasonKey: 'cliente_ausente');
      expect(repository.calls,
          containsAllInOrder(['start', 'not_completed:cliente_ausente']));
    });
  });

  test('claveApp: una sola por orden, guardada en el teléfono', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = OrderKeyStorageImpl(
      LocalStorageImpl(await SharedPreferences.getInstance()),
    );
    final first = await storage.keyFor('42');
    expect(await storage.keyFor('42'), first);
    expect(await storage.keyFor('43'), isNot(first));
    await storage.remove('42');
    expect(await storage.keyFor('42'), isNot(first));
    await storage.clear();
  });
}

extension on ServiceOrderRecord {
  /// Borrador creado con `POST /ordenes-servicio` (sin origen ni programa).
  ServiceOrderRecord copyLegacy() => ServiceOrderRecord(
        id: id,
        folio: folio,
        typeKey: typeKey,
        statusKey: statusKey,
        clientId: clientId,
        installationId: installationId,
      );
}
