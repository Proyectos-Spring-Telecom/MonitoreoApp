import '../entities/catalog_item.dart';

abstract class CatalogRepository {
  /// Clientes, marcas, modelos y combustibles. Se guardan en memoria; con
  /// [forceRefresh] se vuelven a pedir al servidor.
  Future<VehicleCatalogs> getVehicleCatalogs({bool forceRefresh = false});

  /// Olvida los catálogos guardados (al cerrar sesión).
  void clearCache();
}
