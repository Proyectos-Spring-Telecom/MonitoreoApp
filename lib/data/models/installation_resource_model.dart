import '../../core/utils/json_reader.dart';
import '../../domain/entities/installation_resources.dart';

/// Lee dispositivos y SIMs de los catálogos de instalación y arma
/// el texto que se muestra en cada selector.
class InstallationResourceModel extends InstallationResource {
  const InstallationResourceModel({
    required super.id,
    required super.label,
    super.clientId,
    super.status,
  });

  static const Map<int, String> deviceTypeNames = {
    1: 'Rastreador GPS',
    2: 'Panel',
    3: 'AVL',
    4: 'Teléfono',
    5: 'Trackcam',
    6: 'TrackGas',
  };

  static const List<String> _nestedKeys = [
    'vehiculo',
    'activo',
    'inmueble',
    'persona',
    'producto',
    'detalle',
  ];

  static List<InstallationResourceModel> devices(
    dynamic json, {
    int? requestedTypeId,
  }) =>
      _parse(json, const ['id', 'idDispositivo'],
          (layers) => deviceLabel(layers, requestedTypeId: requestedTypeId));

  static List<InstallationResourceModel> sims(dynamic json) =>
      _parse(json, const ['id', 'idSim'], simLabel);

  /// "Tipo: … - Imei: … - N° Serie: …" (o "Eco: …" si no hay imei ni serie).
  static String? deviceLabel(
    List<Map<String, dynamic>> layers, {
    int? requestedTypeId,
  }) {
    final typeName = _deviceTypeName(layers, requestedTypeId);
    final imei = JsonReader.string(layers, const ['imei']);
    final serial =
        JsonReader.string(layers, const ['numeroSerie', 'serie', 'noSerie']);
    final parts = <String>[
      if (typeName != null) 'Tipo: $typeName',
      if (imei != null) 'Imei: $imei',
      if (serial != null) 'N° Serie: $serial',
    ];
    if (imei == null && serial == null) {
      final eco = JsonReader.string(
        layers,
        const ['eco', 'numeroEconomico', 'nombre'],
      );
      if (eco != null) parts.add('Eco: $eco');
    }
    return parts.isEmpty ? null : parts.join(' - ');
  }

  /// "Telefono: … - Sim ID: …".
  static String? simLabel(List<Map<String, dynamic>> layers) {
    final phone = JsonReader.string(
      layers,
      const ['telefono', 'numeroTelefono', 'numero', 'linea'],
    );
    final simId = JsonReader.string(
      layers,
      const ['simId', 'iccid', 'numeroSim', 'serie', 'imei'],
    );
    final parts = <String>[
      if (phone != null) 'Telefono: $phone',
      if (simId != null) 'Sim ID: $simId',
    ];
    return parts.isEmpty ? null : parts.join(' - ');
  }

  static List<InstallationResourceModel> _parse(
    dynamic json,
    List<String> idKeys,
    String? Function(List<Map<String, dynamic>> layers) labelOf,
  ) {
    final result = <InstallationResourceModel>[];
    for (final raw in JsonReader.list(json)) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final top = [item];
      final id = JsonReader.string(top, idKeys);
      final label = labelOf(JsonReader.layers(item, wrapperKeys: _nestedKeys));
      if (id == null || label == null) continue;
      result.add(InstallationResourceModel(
        id: id,
        label: label,
        clientId: _clientId(item),
        status: int.tryParse(
          JsonReader.string(
                top,
                const [
                  'estatus',
                  'estatusProducto',
                  'estatusDispositivo',
                  'estatusSim',
                  'idEstatus'
                ],
              ) ??
              '',
        ),
      ));
    }
    return result;
  }

  static String? _clientId(Map<String, dynamic> item) {
    final direct = JsonReader.string([item], const ['idCliente']);
    if (direct != null) return direct;
    final client = JsonReader.pick([item], const ['cliente']);
    return client is Map
        ? JsonReader.string([Map<String, dynamic>.from(client)], const ['id'])
        : null;
  }

  static String? _deviceTypeName(
    List<Map<String, dynamic>> layers,
    int? requestedTypeId,
  ) {
    final nested = JsonReader.pick(layers, const ['tipoDispositivo']);
    if (nested is Map) {
      final name = JsonReader.string(
        [Map<String, dynamic>.from(nested)],
        const ['nombre', 'descripcion'],
      );
      if (name != null) return name;
    }
    final name = JsonReader.string(
      layers,
      const ['nombreTipoDispositivo', 'tipoDispositivo', 'tipo'],
    );
    if (name != null && int.tryParse(name) == null) return name;
    final typeId = int.tryParse(
          JsonReader.string(layers, const ['idTipoDispositivo']) ?? '',
        ) ??
        requestedTypeId;
    return deviceTypeNames[typeId];
  }
}
