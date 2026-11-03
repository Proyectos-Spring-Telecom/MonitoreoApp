import '../../core/utils/json_reader.dart';
import '../../domain/entities/catalog_item.dart';

class CatalogItemModel extends CatalogItem {
  const CatalogItemModel({
    required super.id,
    required super.name,
    super.parentId,
  });

  static const List<String> clientNameKeys = [
    'razonSocial',
    'nombreComercial',
    'nombreCliente',
  ];
  static const List<String> brandNameKeys = ['nombreMarca', 'marca'];
  static const List<String> modelNameKeys = ['nombreModelo', 'modelo'];
  static const List<String> modelParentKeys = [
    'idCatMarcas',
    'idCatMarca',
    'idMarca',
    'idMarcaVehiculo',
    'marcaId',
  ];
  static const List<String> fuelNameKeys = [
    'tipoCombustible',
    'nombreCombustible',
    'combustible',
  ];

  /// Lee la lista (en la raíz o en `data`), descarta elementos sin id o sin
  /// nombre y la ordena alfabéticamente.
  static List<CatalogItemModel> listFromResponse(
    dynamic json, {
    List<String> nameKeys = const [],
    List<String> parentKeys = const [],
  }) {
    final items = <CatalogItemModel>[];
    for (final raw in JsonReader.list(json)) {
      if (raw is! Map) continue;
      final item = _fromMap(
        Map<String, dynamic>.from(raw),
        nameKeys: nameKeys,
        parentKeys: parentKeys,
      );
      if (item != null) items.add(item);
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  static CatalogItemModel? _fromMap(
    Map<String, dynamic> map, {
    required List<String> nameKeys,
    required List<String> parentKeys,
  }) {
    final layers = [map];
    final id = JsonReader.string(layers, const ['id']);
    final name = JsonReader.string(layers, nameKeys) ?? _personName(layers);
    if (id == null || name == null) return null;
    return CatalogItemModel(
      id: id,
      name: name,
      parentId: _parentId(map, parentKeys),
    );
  }

  static String? _personName(List<Map<String, dynamic>> layers) {
    final name = [
      JsonReader.string(layers, const ['nombre', 'name', 'descripcion']),
      JsonReader.string(layers, const ['apellidoPaterno']),
      JsonReader.string(layers, const ['apellidoMaterno']),
    ].whereType<String>().join(' ');
    return name.isEmpty ? null : name;
  }

  static String? _parentId(Map<String, dynamic> map, List<String> keys) {
    if (keys.isEmpty) return null;
    final direct = JsonReader.string([map], keys);
    if (direct != null) return direct;
    final parent = JsonReader.pick([map], const ['marca', 'catMarca']);
    if (parent is Map) {
      return JsonReader.string(
          [Map<String, dynamic>.from(parent)], const ['id']);
    }
    return null;
  }
}
