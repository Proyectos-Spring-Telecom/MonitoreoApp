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
    super.typeName,
    super.summary,
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

  static const List<String> _imeiKeys = ['imei'];
  static const List<String> _serialKeys = ['numeroSerie', 'serie', 'noSerie'];
  static const List<String> _phoneKeys = [
    'telefono',
    'numeroTelefono',
    'numero',
    'linea',
  ];
  static const List<String> _simIdKeys = [
    'simId',
    'iccid',
    'numeroSim',
    'serie',
    'imei',
  ];

  static List<InstallationResourceModel> devices(
    dynamic json, {
    int? requestedTypeId,
  }) =>
      _parse(
        json,
        const ['id', 'idDispositivo'],
        (layers) => deviceLabel(layers, requestedTypeId: requestedTypeId),
        typeNameOf: (layers) => _deviceTypeName(layers, requestedTypeId),
        summaryOf: deviceSummary,
      );

  static List<InstallationResourceModel> sims(dynamic json) => _parse(
        json,
        const ['id', 'idSim'],
        simLabel,
        summaryOf: simSummary,
      );

  /// "Tipo: … - Imei: … - N° Serie: …" (o "Eco: …" si no hay imei ni serie).
  static String? deviceLabel(
    List<Map<String, dynamic>> layers, {
    int? requestedTypeId,
  }) {
    final typeName = _deviceTypeName(layers, requestedTypeId);
    final imei = JsonReader.string(layers, _imeiKeys);
    final serial = JsonReader.string(layers, _serialKeys);
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
    final phone = JsonReader.string(layers, _phoneKeys);
    final simId = JsonReader.string(layers, _simIdKeys);
    final parts = <String>[
      if (phone != null) 'Telefono: $phone',
      if (simId != null) 'Sim ID: $simId',
    ];
    return parts.isEmpty ? null : parts.join(' - ');
  }

  /// "Suntech ST210 - IMEI 3333 - Serie: 0009", como en el PDF.
  static String? deviceSummary(List<Map<String, dynamic>> layers) {
    final model = [
      _name(layers, const ['marca', 'nombreMarca']),
      _name(layers, const ['modelo', 'nombreModelo']),
    ].whereType<String>().join(' ');
    final imei = JsonReader.string(layers, _imeiKeys);
    final serial = JsonReader.string(layers, _serialKeys);
    if (imei == null && serial == null) return null;
    return [
      if (model.isNotEmpty) model,
      if (imei != null) 'IMEI $imei',
      if (serial != null) 'Serie: $serial',
    ].join(' - ');
  }

  /// "Telcel - ICCID 0002 - Tel: 7775642667", como en el PDF.
  static String? simSummary(List<Map<String, dynamic>> layers) {
    final company = _name(
      layers,
      const ['compania', 'compañia', 'operador', 'carrier', 'proveedor'],
    );
    final iccid = JsonReader.string(layers, _simIdKeys);
    final phone = JsonReader.string(layers, _phoneKeys);
    if (iccid == null && phone == null) return null;
    return [
      if (company != null) company,
      if (iccid != null) 'ICCID $iccid',
      if (phone != null) 'Tel: $phone',
    ].join(' - ');
  }

  /// Texto directo o el `nombre` de un objeto anidado.
  static String? _name(List<Map<String, dynamic>> layers, List<String> keys) {
    final value = JsonReader.pick(layers, keys);
    if (value is Map) {
      return JsonReader.string(
        [Map<String, dynamic>.from(value)],
        const ['nombre', 'descripcion'],
      );
    }
    return JsonReader.string(layers, keys);
  }

  static List<InstallationResourceModel> _parse(
    dynamic json,
    List<String> idKeys,
    String? Function(List<Map<String, dynamic>> layers) labelOf, {
    String? Function(List<Map<String, dynamic>> layers)? typeNameOf,
    String? Function(List<Map<String, dynamic>> layers)? summaryOf,
  }) {
    final result = <InstallationResourceModel>[];
    for (final raw in JsonReader.list(json)) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final top = [item];
      final id = JsonReader.string(top, idKeys);
      final layers = JsonReader.layers(item, wrapperKeys: _nestedKeys);
      final label = labelOf(layers);
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
        typeName: typeNameOf?.call(layers),
        summary: summaryOf?.call(layers),
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
