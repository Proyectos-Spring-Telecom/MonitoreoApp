import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/json_reader.dart';
import '../../../domain/entities/installation_resources.dart';
import '../../models/installation_resource_model.dart';

/// Equipos y SIMs para la orden. La instalación la crea o modifica el
/// servidor al cerrar la orden de servicio.
abstract class InstallationRemoteDataSource {
  /// Lo reservado al cliente de la orden más el almacén.
  Future<InstallationStock> getStock({required String clientId});
}

class InstallationRemoteDataSourceImpl implements InstallationRemoteDataSource {
  final ApiClient apiClient;

  InstallationRemoteDataSourceImpl(this.apiClient);

  @override
  Future<InstallationStock> getStock({required String clientId}) async {
    final query = {'idCliente': clientId};
    final results = await Future.wait([
      apiClient.get(ApiEndpoints.devices, query: query),
      apiClient.get(ApiEndpoints.sims, query: query),
    ]);
    final devices = InstallationResourceModel.devices(results[0]);
    final sims = InstallationResourceModel.sims(results[1]);
    _logKeys('dispositivos', results[0], devices.length);
    _logKeys('sims', results[1], sims.length);
    return InstallationStock(devices: devices, sims: sims);
  }

  static void _logKeys(String name, dynamic response, int valid) {
    if (!kDebugMode) return;
    final raw = JsonReader.list(response);
    final keys = raw.isNotEmpty && raw.first is Map
        ? (raw.first as Map).keys.join(', ')
        : '—';
    debugPrint(
      '[API] $name: ${raw.length} recibidos, $valid válidos. Claves: $keys',
    );
  }
}
