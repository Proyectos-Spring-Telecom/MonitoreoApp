import 'package:equatable/equatable.dart';

/// Elemento de un catálogo del API: se muestra por [name] y se envía por [id].
class CatalogItem extends Equatable {
  final String id;
  final String name;

  /// Elemento del que depende (p. ej. la marca de un modelo).
  final String? parentId;

  const CatalogItem({required this.id, required this.name, this.parentId});

  @override
  List<Object?> get props => [id, name, parentId];
}

class VehicleCatalogs {
  final List<CatalogItem> clients;
  final List<CatalogItem> brands;
  final List<CatalogItem> models;
  final List<CatalogItem> fuelTypes;

  const VehicleCatalogs({
    required this.clients,
    required this.brands,
    required this.models,
    required this.fuelTypes,
  });

  List<CatalogItem> modelsFor(String? brandId) => brandId == null
      ? const []
      : models.where((model) => model.parentId == brandId).toList();
}
