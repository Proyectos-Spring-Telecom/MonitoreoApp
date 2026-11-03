import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/json_reader.dart';
import '../../models/catalog_item_model.dart';

abstract class CatalogRemoteDataSource {
  Future<List<CatalogItemModel>> getClients();
  Future<List<CatalogItemModel>> getBrands();
  Future<List<CatalogItemModel>> getModels();
  Future<List<CatalogItemModel>> getFuelTypes();
}

class CatalogRemoteDataSourceImpl implements CatalogRemoteDataSource {
  final ApiClient apiClient;

  CatalogRemoteDataSourceImpl(this.apiClient);

  @override
  Future<List<CatalogItemModel>> getClients() => _load(
        ApiEndpoints.clients,
        nameKeys: CatalogItemModel.clientNameKeys,
      );

  @override
  Future<List<CatalogItemModel>> getBrands() => _load(
        ApiEndpoints.brands,
        nameKeys: CatalogItemModel.brandNameKeys,
      );

  @override
  Future<List<CatalogItemModel>> getModels() => _load(
        ApiEndpoints.models,
        nameKeys: CatalogItemModel.modelNameKeys,
        parentKeys: CatalogItemModel.modelParentKeys,
      );

  @override
  Future<List<CatalogItemModel>> getFuelTypes() => _load(
        ApiEndpoints.fuelTypes,
        nameKeys: CatalogItemModel.fuelNameKeys,
      );

  Future<List<CatalogItemModel>> _load(
    String endpoint, {
    List<String> nameKeys = const [],
    List<String> parentKeys = const [],
  }) async {
    final response = await apiClient.get(endpoint);
    final items = CatalogItemModel.listFromResponse(
      response,
      nameKeys: nameKeys,
      parentKeys: parentKeys,
    );
    if (kDebugMode) {
      final raw = JsonReader.list(response);
      final keys = raw.isNotEmpty && raw.first is Map
          ? (raw.first as Map).keys.join(', ')
          : '—';
      debugPrint(
        '[API] $endpoint: ${raw.length} recibidos, ${items.length} válidos. '
        'Claves: $keys',
      );
    }
    return items;
  }
}
