import '../../domain/entities/catalog_item.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/remote/catalog_remote_datasource.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final CatalogRemoteDataSource remoteDataSource;

  VehicleCatalogs? _vehicleCatalogs;
  Future<VehicleCatalogs>? _loading;

  CatalogRepositoryImpl(this.remoteDataSource);

  @override
  Future<VehicleCatalogs> getVehicleCatalogs({bool forceRefresh = false}) {
    final cached = _vehicleCatalogs;
    if (cached != null && !forceRefresh) return Future.value(cached);
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  Future<VehicleCatalogs> _fetch() async {
    final results = await Future.wait([
      remoteDataSource.getClients(),
      remoteDataSource.getBrands(),
      remoteDataSource.getModels(),
      remoteDataSource.getFuelTypes(),
    ]);
    return _vehicleCatalogs = VehicleCatalogs(
      clients: results[0],
      brands: results[1],
      models: results[2],
      fuelTypes: results[3],
    );
  }

  @override
  void clearCache() => _vehicleCatalogs = null;
}
