import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/network/api_client.dart';
import 'package:monitoreo/data/datasources/remote/catalog_remote_datasource.dart';
import 'package:monitoreo/data/datasources/remote/vehicle_remote_datasource.dart';
import 'package:monitoreo/data/models/catalog_item_model.dart';
import 'package:monitoreo/data/models/vehicle_request.dart';
import 'package:monitoreo/data/repositories/catalog_repository_impl.dart';

final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class Part {
  final String name;
  final String? filename;
  final String? contentType;
  final String value;

  Part(this.name, this.filename, this.contentType, this.value);
}

/// Separa el cuerpo `multipart/form-data` en sus partes.
Map<String, Part> parseMultipart(http.Request request) {
  final contentType = request.headers['content-type']!;
  expect(contentType, startsWith('multipart/form-data'));
  final boundary = contentType.split('boundary=').last;
  final body = latin1.decode(request.bodyBytes);
  final parts = <String, Part>{};
  for (final chunk in body.split('--$boundary')) {
    final separator = chunk.indexOf('\r\n\r\n');
    if (separator < 0) continue;
    final headers = chunk.substring(0, separator);
    final value =
        chunk.substring(separator + 4).replaceFirst(RegExp(r'\r\n$'), '');
    final name = RegExp(r'name="([^"]+)"').firstMatch(headers)!.group(1)!;
    parts[name] = Part(
      name,
      RegExp(r'filename="([^"]+)"').firstMatch(headers)?.group(1),
      RegExp(r'content-type: ([^\r\n]+)', caseSensitive: false)
          .firstMatch(headers)
          ?.group(1),
      value,
    );
  }
  return parts;
}

class FakeAuth implements ApiAuthHandler {
  String token = 'access-1';
  int refreshes = 0;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<bool> refreshAccessToken() async {
    refreshes++;
    token = 'access-2';
    return true;
  }

  @override
  Future<void> onSessionExpired() async {}
}

void main() {
  group('Catálogos', () {
    test('lista en la raíz con claves PascalCase', () {
      final items = CatalogItemModel.listFromResponse(
        [
          {'Id': 2, 'Nombre': 'Toyota'},
          {'Id': 1, 'Nombre': 'Nissan'},
          {'Nombre': 'Sin id'},
        ],
        nameKeys: CatalogItemModel.brandNameKeys,
      );
      expect(items.map((i) => '${i.id}:${i.name}'), ['1:Nissan', '2:Toyota']);
    });

    test('lista dentro de data; clientes por razón social o nombre completo',
        () {
      final items = CatalogItemModel.listFromResponse(
        {
          'message': 'ok',
          'data': [
            {'id': 12, 'razonSocial': 'Transportes del Norte SA de CV'},
            {
              'id': 7,
              'nombre': 'Juan',
              'apellidoPaterno': 'Pérez',
              'apellidoMaterno': 'López',
            },
          ],
        },
        nameKeys: CatalogItemModel.clientNameKeys,
      );
      expect(items.map((i) => i.name),
          ['Juan Pérez López', 'Transportes del Norte SA de CV']);
    });

    test('modelos ligados a su marca por idCatMarcas o marca.id', () {
      final items = CatalogItemModel.listFromResponse(
        {
          'data': [
            {'id': 15, 'nombre': 'Hilux', 'idCatMarcas': 3},
            {
              'id': 16,
              'nombre': 'Hiace',
              'marca': {'id': 3, 'nombre': 'Toyota'},
            },
            {'id': 20, 'nombre': 'NP300', 'idMarca': '1'},
          ],
        },
        nameKeys: CatalogItemModel.modelNameKeys,
        parentKeys: CatalogItemModel.modelParentKeys,
      );
      expect({for (final i in items) i.name: i.parentId},
          {'Hiace': '3', 'Hilux': '3', 'NP300': '1'});
    });

    test('el repositorio pide los 4 catálogos una sola vez y los guarda',
        () async {
      final paths = <String>[];
      final api = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          switch (request.url.path) {
            case '/clientes/list':
              return jsonResponse([
                {'id': 1, 'razonSocial': 'Next'},
              ]);
            case '/cat-marcas/list':
              return jsonResponse({
                'data': [
                  {'id': 3, 'nombre': 'Toyota'},
                ],
              });
            case '/cat-modelos/list':
              return jsonResponse([
                {'id': 15, 'nombre': 'Hilux', 'idCatMarcas': 3},
                {'id': 20, 'nombre': 'NP300', 'idCatMarcas': 1},
              ]);
            default:
              return jsonResponse([
                {'id': 1, 'nombre': 'Diésel'},
              ]);
          }
        }),
      );
      final repo = CatalogRepositoryImpl(CatalogRemoteDataSourceImpl(api));

      final results = await Future.wait([
        repo.getVehicleCatalogs(),
        repo.getVehicleCatalogs(),
      ]);
      final catalogs = results.first;
      expect(paths.toSet(), {
        '/clientes/list',
        '/cat-marcas/list',
        '/cat-modelos/list',
        '/cat-tipo-combustible/list',
      });
      expect(paths.length, 4);
      expect(catalogs.clients.single.name, 'Next');
      expect(catalogs.modelsFor('3').map((m) => m.name), ['Hilux']);
      expect(catalogs.fuelTypes.single.name, 'Diésel');

      await repo.getVehicleCatalogs();
      expect(paths.length, 4, reason: 'usa la caché');
      await repo.getVehicleCatalogs(forceRefresh: true);
      expect(paths.length, 8);
    });
  });

  group('VehicleRequest', () {
    test('omite vacíos, placa en mayúsculas y coma decimal a punto', () {
      const request = VehicleRequest(
        clientId: '12',
        plate: 'nv4126b',
        economicNumber: ' 32 ',
        brandId: '3',
        modelId: '15',
        year: '2024',
        color: '',
        serialNumber: 'jtdbt923x0l123456',
        km: '18500,5',
        capacityLiters: '60',
      );
      expect(request.toFields(), {
        'idCliente': '12',
        'placa': 'NV4126B',
        'numeroEconomico': '32',
        'idMarcaVehiculo': '3',
        'idModeloVehiculo': '15',
        'anio': '2024',
        'numeroSerie': 'JTDBT923X0L123456',
        'km': '18500.5',
        'capacidadLitros': '60',
      });
    });

    test('archivos con el nombre de campo del API y su tipo', () {
      final files = VehicleRequest(
        plate: 'A',
        files: {'principal': jpeg, 'tarjeta_circulacion': png},
      ).toFiles();
      expect(
        files.map((f) => '${f.field}|${f.filename}|${f.contentType}'),
        [
          'foto|foto.jpg|image/jpeg',
          'tarjetaCirculacion|tarjetaCirculacion.png|image/png',
        ],
      );
    });

    test('rechaza formatos no permitidos y archivos mayores a 3 MB', () {
      expect(
        () => VehicleRequest(
          plate: 'A',
          files: {
            'frontal': Uint8List.fromList([1, 2, 3, 4])
          },
        ).toFiles(labels: const {'frontal': 'Fotografía frontal'}),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          'Fotografía frontal: formato no permitido. Usa PNG, JPG, WEBP o PDF.',
        )),
      );
      final big = Uint8List(VehicleRequest.maxFileBytes + 1)
        ..setAll(0, [0xFF, 0xD8, 0xFF]);
      expect(
        () => VehicleRequest(plate: 'A', files: {'trasera': big}).toFiles(),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('Servicio de vehículos', () {
    late List<http.Request> requests;
    late FakeAuth auth;
    late VehicleRemoteDataSourceImpl dataSource;

    void setUpWith(Future<http.Response> Function(http.Request) handler) {
      requests = [];
      auth = FakeAuth();
      final api = ApiClient(
        baseUrl: 'https://api.test',
        authHandler: auth,
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      );
      dataSource = VehicleRemoteDataSourceImpl(api);
    }

    test('alta: POST multipart con Bearer, campos y archivos; devuelve el id',
        () async {
      setUpWith((_) async => jsonResponse({
            'message': 'Vehículo creado',
            'data': {'idVehiculo': 45},
          }));

      final id = await dataSource.createVehicle(VehicleRequest(
        clientId: '12',
        plate: 'nv4126b',
        km: '18500',
        files: {'principal': jpeg, 'frontal': jpeg},
      ));

      expect(id, '45');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/productos/vehiculos');
      expect(request.headers['Authorization'], 'Bearer access-1');
      final parts = parseMultipart(request);
      expect(parts.keys.toSet(),
          {'idCliente', 'placa', 'km', 'foto', 'fotoFrente'});
      expect(parts['idCliente']!.value, '12');
      expect(parts['placa']!.value, 'NV4126B');
      expect(parts['foto']!.filename, 'foto.jpg');
      expect(parts['foto']!.contentType, 'image/jpeg');
      expect(parts['fotoFrente']!.value.codeUnits, jpeg);
    });

    test('un archivo inválido no llega a enviarse', () async {
      setUpWith((_) async => jsonResponse({}));
      await expectLater(
        dataSource.createVehicle(VehicleRequest(
          clientId: '1',
          plate: 'A',
          files: {
            'extra': Uint8List.fromList([0, 0, 0, 0])
          },
        )),
        throwsA(isA<ValidationFailure>()),
      );
      expect(requests, isEmpty);
    });

    test('401 en la subida: renueva el token y reenvía el multipart completo',
        () async {
      setUpWith((request) async =>
          request.headers['Authorization'] == 'Bearer access-2'
              ? jsonResponse({'id': 9})
              : jsonResponse(null, 401));

      final id = await dataSource.createVehicle(VehicleRequest(
        clientId: '1',
        plate: 'ABC',
        files: {'principal': jpeg},
      ));

      expect(id, '9');
      expect(auth.refreshes, 1);
      expect(requests.length, 2);
      final retried = parseMultipart(requests.last);
      expect(retried['placa']!.value, 'ABC');
      expect(retried['foto']!.value.codeUnits, jpeg);
    });

    test('el mensaje de error del backend llega a la app', () async {
      setUpWith((_) async =>
          jsonResponse({'message': 'La placa ya está registrada'}, 409));
      await expectLater(
        dataSource.createVehicle(
          const VehicleRequest(clientId: '1', plate: 'ABC'),
        ),
        throwsA(isA<ServerFailure>().having(
          (e) => e.message,
          'message',
          'La placa ya está registrada',
        )),
      );
    });
  });
}
