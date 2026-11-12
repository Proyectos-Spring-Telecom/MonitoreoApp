import 'package:flutter/foundation.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/json_reader.dart';
import '../../models/vehicle_request.dart';

/// Vehículo ya registrado con una placa.
class VehicleLookup {
  /// `idProducto`: con él la orden de servicio referencia al vehículo.
  final String id;
  final String? clientId;

  const VehicleLookup({required this.id, this.clientId});
}

abstract class VehicleRemoteDataSource {
  /// `GET /productos/vehiculos/placa/:placa`; `null` si no existe.
  Future<VehicleLookup?> findByPlate(String plate);

  /// Devuelve el `idProducto` del vehículo creado (`null` si no lo envía).
  Future<String?> createVehicle(
    VehicleRequest request, {
    Map<String, String> fileLabels,
  });
}

class VehicleRemoteDataSourceImpl implements VehicleRemoteDataSource {
  final ApiClient apiClient;

  VehicleRemoteDataSourceImpl(this.apiClient);

  @override
  Future<VehicleLookup?> findByPlate(String plate) async {
    final dynamic response;
    try {
      response = await apiClient.get(
        ApiEndpoints.vehicleByPlate(plate.trim().toUpperCase()),
      );
    } on ServerFailure catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    final matches = JsonReader.list(response);
    final layers = JsonReader.layers(
      matches.isNotEmpty ? matches.first : response,
      wrapperKeys: const ['data', 'vehiculo'],
    );
    final id = JsonReader.string(
      layers,
      const ['idProducto', 'id', 'idVehiculo'],
    );
    if (id == null) return null;
    var clientId = JsonReader.string(layers, const ['idCliente']);
    final client = JsonReader.pick(layers, const ['cliente']);
    if (clientId == null && client is Map) {
      clientId =
          JsonReader.string([Map<String, dynamic>.from(client)], const ['id']);
    }
    return VehicleLookup(id: id, clientId: clientId);
  }

  @override
  Future<String?> createVehicle(
    VehicleRequest request, {
    Map<String, String> fileLabels = const {},
  }) async {
    final files = request.toFiles(labels: fileLabels);
    final response = await apiClient.multipart(
      'POST',
      ApiEndpoints.vehicles,
      fields: request.toFields(),
      files: files,
    );
    final id = JsonReader.string(
      JsonReader.layers(response, wrapperKeys: const ['data', 'vehiculo']),
      const ['idProducto', 'id', 'idVehiculo', 'vehiculoId', 'insertId'],
    );
    if (kDebugMode) {
      final keys = JsonReader.layers(response).map((l) => l.keys.join(', '));
      debugPrint('[API] Vehículo creado: id=$id · claves: ${keys.join(' | ')}');
    }
    return id;
  }
}
