import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitoreo/core/network/api_client.dart';
import 'package:monitoreo/data/datasources/remote/installation_remote_datasource.dart';
import 'package:monitoreo/data/models/installation_resource_model.dart';
import 'package:monitoreo/domain/entities/installation_resources.dart';

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('Equipos y SIMs', () {
    test('respuesta real de /sims/list: numeroTelefono e imei', () {
      final sims = InstallationResourceModel.sims([
        {
          'id': 3,
          'imei': '8952020012345678901',
          'numeroTelefono': '7771234567',
          'idCliente': 10,
          'estatus': 1,
        },
      ]);
      expect(sims.single.label,
          'Telefono: 7771234567 - Sim ID: 8952020012345678901');
      expect(sims.single.clientId, '10');
    });

    test('dispositivos: Tipo - Imei - N° Serie, o Eco si no hay', () {
      final devices = InstallationResourceModel.devices([
        {
          'id': 88,
          'imei': '861230001',
          'numeroSerie': 'S-1',
          'idTipoDispositivo': 3
        },
        {
          'id': 89,
          'tipoDispositivo': {'nombre': 'Trackcam'},
          'eco': 'ECO-7',
        },
      ]);
      expect(devices.map((d) => d.label), [
        'Tipo: AVL - Imei: 861230001 - N° Serie: S-1',
        'Tipo: Trackcam - Eco: ECO-7',
      ]);
    });

    test('entra lo del almacén (sin cliente) o lo reservado al cliente', () {
      const warehouse = InstallationResource(id: '1', label: 'A', status: 1);
      const reserved =
          InstallationResource(id: '2', label: 'B', clientId: '12', status: 1);
      const otherClient =
          InstallationResource(id: '3', label: 'C', clientId: '99', status: 1);
      const inReview = InstallationResource(id: '4', label: 'D', status: 3);

      expect(warehouse.isInWarehouse, isTrue);
      expect(warehouse.canInstallFor('12'), isTrue);
      expect(reserved.canInstallFor('12'), isTrue);
      expect(otherClient.canInstallFor('12'), isFalse);
      expect(inReview.canInstallFor('12'), isFalse);
    });
  });

  test('getStock: dispositivos y SIMs con idCliente de la orden', () async {
    final requests = <http.Request>[];
    final dataSource = InstallationRemoteDataSourceImpl(ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        requests.add(request);
        return request.url.path == '/dispositivos/list'
            ? jsonResponse([
                {'id': 88, 'imei': '111', 'idCliente': null},
                {'id': 90, 'imei': '333', 'idCliente': 10},
              ])
            : jsonResponse({
                'data': [
                  {'id': 12, 'telefono': '777'},
                ],
              });
      }),
    ));

    final stock = await dataSource.getStock(clientId: '10');

    expect(requests.map((r) => r.url.path).toSet(),
        {'/dispositivos/list', '/sims/list'});
    for (final request in requests) {
      expect(request.url.queryParameters, {'idCliente': '10'});
    }
    expect(stock.devices.map((d) => d.id), ['88', '90']);
    expect(stock.devices.first.isInWarehouse, isTrue);
    expect(stock.sims.single.label, 'Telefono: 777');
  });
}
