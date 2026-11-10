import '../../core/utils/json_reader.dart';
import '../../core/utils/mexico_time.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/service_order_record.dart';
import 'installation_resource_model.dart';

/// Lectura de las respuestas de `/ordenes-servicio` (§2, §3).
class ServiceOrderModel {
  ServiceOrderModel._();

  /// `{ data: [ { secciones: {...}, monitoristas: [...] } ] }`; también acepta
  /// el objeto sin arreglo o sin `data`.
  static ServiceOrderCatalog catalog(dynamic response) {
    final layers = JsonReader.layers(_firstRow(response) ?? const {});

    final sections = <String, List<ServiceOrderOption>>{};
    final rawSections =
        JsonReader.pick(layers, const ['secciones', 'sections']);
    if (rawSections is Map) {
      rawSections.forEach((section, options) {
        if (options is! List) return;
        sections['$section'] = options
            .whereType<Map>()
            .map((option) => _option(Map<String, dynamic>.from(option)))
            .whereType<ServiceOrderOption>()
            .toList();
      });
    }

    final rawMonitors = JsonReader.pick(layers, const ['monitoristas']);
    final monitors = rawMonitors is List
        ? rawMonitors
            .whereType<Map>()
            .map((monitor) => _monitor(Map<String, dynamic>.from(monitor)))
            .whereType<CatalogItem>()
            .toList()
        : <CatalogItem>[];
    return ServiceOrderCatalog(sections: sections, monitors: monitors);
  }

  static ServiceOrderOption? _option(Map<String, dynamic> map) {
    final key = JsonReader.string([map], const ['clave', 'key']);
    if (key == null) return null;
    return ServiceOrderOption(
      key: key,
      name: JsonReader.string([map], const ['nombre', 'name']) ?? key,
      required: JsonReader.boolean([map], const ['obligatorio']) ?? false,
    );
  }

  static CatalogItem? _monitor(Map<String, dynamic> map) {
    final id = JsonReader.string([map], const ['id', 'idUsuario']);
    final name = JsonReader.string([map], const ['nombre', 'name']);
    if (id == null || name == null) return null;
    return CatalogItem(id: id, name: name);
  }

  /// `GET /ordenes-servicio/motivos`: todos los motivos, sin filtrar.
  static List<NotCompletedReason> reasons(dynamic response) {
    List<String> texts(Object? value) => value is List
        ? value
            .map((item) => '$item'.trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : value is String && value.trim().isNotEmpty
            ? [value.trim()]
            : const [];

    final result = <NotCompletedReason>[];
    for (final raw in JsonReader.list(response).whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      final top = [map];
      final key = JsonReader.string(top, const ['clave', 'key']);
      if (key == null) continue;
      result.add(NotCompletedReason(
        key: key,
        name: JsonReader.string(top, const ['nombre', 'name']) ?? key,
        results: texts(JsonReader.pick(top, const ['resultado'])),
        who: texts(JsonReader.pick(top, const ['quien'])),
        requiresObservations:
            JsonReader.boolean(top, const ['requiereObservaciones']) ?? false,
      ));
    }
    return result;
  }

  /// `{ data: [...], paginated: { total, page, limit } }`.
  static PagedServiceOrders page(
    dynamic response, {
    required int page,
    required int limit,
  }) {
    final items = JsonReader.list(response)
        .whereType<Map>()
        .map((row) => order(Map<String, dynamic>.from(row)))
        .whereType<ServiceOrderRecord>()
        .toList();
    final rawMeta = JsonReader.pick(
      JsonReader.layers(response),
      const ['paginated', 'pagination'],
    );
    final meta = rawMeta is Map
        ? [Map<String, dynamic>.from(rawMeta)]
        : const <Map<String, dynamic>>[];
    int? number(String key) =>
        int.tryParse(JsonReader.string(meta, [key]) ?? '');
    return PagedServiceOrders(
      items: items,
      total: number('total') ?? items.length,
      page: number('page') ?? page,
      limit: number('limit') ?? limit,
    );
  }

  /// `GET /:id` → `{ data: [ orden ] }`.
  static ServiceOrderRecord? detail(dynamic response) {
    final row = _firstRow(response);
    return row == null ? null : order(row);
  }

  static ServiceOrderRecord? order(Map<String, dynamic> row) {
    final top = [row];
    String? text(String key) => JsonReader.string(top, [key]);
    int? integer(String key) => int.tryParse(text(key) ?? '');
    double? decimal(String key) => double.tryParse(text(key) ?? '');
    DateTime? date(String key) => MexicoCityTime.parseApi(text(key));
    List<Map<String, dynamic>> maps(String key) {
      final raw = JsonReader.pick(top, [key]);
      return raw is List
          ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const [];
    }

    final id = JsonReader.string(top, const ['id', 'idOrdenServicio']);
    if (id == null) return null;

    final answers = <ServiceOrderAnswer>[];
    for (final answer in maps('respuestas')) {
      final section = JsonReader.string([answer], const ['seccion']);
      final key = JsonReader.string([answer], const ['clave']);
      if (section == null || key == null) continue;
      answers.add(ServiceOrderAnswer(
        section,
        key,
        JsonReader.boolean([answer], const ['valor']) ?? false,
      ));
    }

    final tests = <ServiceOrderTest>[];
    for (final test in maps('pruebas')) {
      final layer = [test];
      final key = JsonReader.string(layer, const ['clave']);
      if (key == null) continue;
      tests.add(ServiceOrderTest(
        key: key,
        status: TestStatus.fromKey(
          JsonReader.string(layer, const ['estatus'])?.toLowerCase(),
        ),
        requestedAt: MexicoCityTime.parseApi(
          JsonReader.string(layer, const ['fechaSolicitud']),
        ),
        technicianNote: JsonReader.string(layer, const ['notaTecnico']),
        validatedAt: MexicoCityTime.parseApi(
          JsonReader.string(layer, const ['fechaValidacion']),
        ),
        validatedBy: JsonReader.string(layer, const ['nombreValido']),
        operatorNote: JsonReader.string(layer, const ['notaOperador']),
      ));
    }

    final files = <ServiceOrderFile>[];
    for (final file in maps('archivos')) {
      final key = JsonReader.string([file], const ['clave']);
      final url = JsonReader.string([file], const ['url', 'ruta']);
      if (key == null || url == null) continue;
      files.add(ServiceOrderFile(
        key: key,
        url: url,
        createdAt: MexicoCityTime.parseApi(
          JsonReader.string([file], const ['fechaCreacion']),
        ),
      ));
    }

    final vehiclePhotos = <ServiceOrderFile>[];
    for (final photo in maps('fotosVehiculo')) {
      final layer = [photo];
      final key = JsonReader.string(layer, const ['clave']);
      final url = JsonReader.string(layer, const ['url', 'ruta']);
      if (key == null || url == null) continue;
      vehiclePhotos.add(ServiceOrderFile(
        key: key,
        url: url,
        name: JsonReader.string(layer, const ['nombre']),
      ));
    }

    InstallationSummary? summary(String key) {
      final raw = JsonReader.pick(top, [key]);
      if (raw is! Map) return null;
      final layer = [Map<String, dynamic>.from(raw)];
      final result = InstallationSummary(
        equipmentType: JsonReader.string(layer, const ['tipoEquipo']),
        device: JsonReader.string(layer, const ['dispositivo']),
        sim: JsonReader.string(layer, const ['sim']),
      );
      return result.isEmpty ? null : result;
    }

    final rawMissing = JsonReader.pick(top, const ['faltantesParaCerrar']);
    return ServiceOrderRecord(
      id: id,
      folio: text('folio') ?? text('nombre') ?? id,
      typeKey: text('tipoServicio') ?? '',
      scheduledTypeKey: text('tipoProgramado'),
      statusKey: text('estatus')?.toLowerCase(),
      origin: text('origen'),
      appointment: date('cita'),
      appointmentEnd: date('citaFin'),
      scheduledBy: text('nombreProgramo'),
      clientId: text('idCliente'),
      clientName: text('nombreCliente'),
      plate: text('placa'),
      economicNumber: text('numeroEconomico'),
      productName: text('nombreProducto'),
      scheduledInstallationId: text('idInstalacionProgramada'),
      installationId: text('idInstalacion'),
      productId: text('idProducto'),
      resultingInstallationId: text('idInstalacionResultado'),
      installation: summary('instalacion'),
      resultingInstallation: summary('instalacionResultado'),
      crmReference: text('referenciaCrm'),
      unit: integer('unidad'),
      unitsTotal: integer('unidadesTotal'),
      codeValidated: JsonReader.boolean(top, const ['codigoValidado']) ?? false,
      authorization:
          AuthorizationStatus.fromKey(text('autorizacion')?.toLowerCase()),
      newDeviceId: text('idDispositivoNuevo'),
      newSimId: text('idSimNuevo'),
      outgoingStatus: integer('estatusSalienteAnterior'),
      removalStatus: integer('estatusInstalacionBaja'),
      technicianId: text('idTecnico'),
      monitorId: text('idMonitorista'),
      capturedAt: date('fechaCaptura'),
      lat: decimal('lat'),
      lng: decimal('lng'),
      observations: text('observaciones'),
      reasonKey: text('claveMotivo'),
      createdAt: date('fechaCreacion'),
      startedAt: date('fechaInicio'),
      closedAt: date('fechaCierre'),
      tests: tests,
      answers: answers,
      files: files,
      vehiclePhotos: vehiclePhotos,
      missingToClose: rawMissing is List
          ? rawMissing
              .map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
    );
  }

  /// `{ data: { id, nombre } }` de iniciar y guardar.
  static ServiceOrderRef? ref(dynamic response) {
    final layers = JsonReader.layers(response);
    final id = JsonReader.string(layers, const ['id', 'idOrdenServicio']);
    if (id == null) return null;
    return ServiceOrderRef(
      id: id,
      folio: JsonReader.string(layers, const ['nombre', 'folio']) ?? id,
    );
  }

  /// `faltantes` del 400 al cerrar.
  static List<String> missingFields(Object? data) {
    final raw = JsonReader.pick(
      JsonReader.layers(data),
      const ['faltantes', 'faltantesParaCerrar'],
    );
    return raw is List
        ? raw.map((item) => '$item'.trim()).where((t) => t.isNotEmpty).toList()
        : const [];
  }

  /// `{ data: [ { id, folio, url, vigenciaHoras, whatsapp } ] }`.
  static ServiceOrderShareLink? shareLink(dynamic response) {
    final layers = JsonReader.layers(_firstRow(response) ?? const {});
    final url = JsonReader.string(layers, const ['url']);
    if (url == null) return null;
    return ServiceOrderShareLink(
      url: url,
      whatsappUrl: JsonReader.string(layers, const ['whatsapp']),
      validHours: int.tryParse(
          JsonReader.string(layers, const ['vigenciaHoras']) ?? ''),
    );
  }

  /// Fila de `/instalaciones`; producto, dispositivo y SIM pueden venir
  /// anidados o en la raíz.
  static CurrentInstallation? installation(Map<String, dynamic> row) {
    final top = [row];
    final id = JsonReader.string(top, const ['idInstalacion', 'id']);
    if (id == null) return null;

    List<Map<String, dynamic>> part(String key) {
      final nested = JsonReader.pick(top, [key]);
      return nested is Map ? [row, Map<String, dynamic>.from(nested)] : top;
    }

    String? nestedId(String key, List<String> flatKeys) {
      final direct = JsonReader.string(top, flatKeys);
      if (direct != null) return direct;
      final nested = JsonReader.pick(top, [key]);
      return nested is Map
          ? JsonReader.string([Map<String, dynamic>.from(nested)], const ['id'])
          : null;
    }

    final productLayers = part('producto');
    return CurrentInstallation(
      id: id,
      productId: nestedId('producto', const ['idProducto']),
      productLabel: JsonReader.string(productLayers, const ['placa']) ??
          JsonReader.string(productLayers, const ['nombre', 'descripcion']),
      deviceId: nestedId('dispositivo', const ['idDispositivo']),
      deviceLabel: InstallationResourceModel.deviceLabel(part('dispositivo')),
      simId: nestedId('sim', const ['idSim']),
      simLabel: InstallationResourceModel.simLabel(part('sim')),
    );
  }

  static Map<String, dynamic>? _firstRow(dynamic response) {
    final list = JsonReader.list(response);
    if (list.isNotEmpty && list.first is Map) {
      return Map<String, dynamic>.from(list.first as Map);
    }
    return JsonReader.layers(response).lastOrNull;
  }
}
