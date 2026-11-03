import 'package:equatable/equatable.dart';

import 'catalog_item.dart';

/// Tipo de servicio de la orden. Operación programa la orden con un tipo
/// (`tipoProgramado`); al iniciarla el técnico solo puede cambiarlo entre
/// mantenimientos (§4).
enum ServiceType {
  instalacion('instalacion', 'Instalación'),
  revision('revision', 'Revisión'),
  cSim('c_sim', 'Cambio de SIM'),
  cEquipo('c_equipo', 'Cambio de equipo'),
  desinstalacion('desinstalacion', 'Desinstalación');

  const ServiceType(this.key, this.label);

  final String key;
  final String label;

  static const List<ServiceType> maintenances = [
    revision,
    cSim,
    cEquipo,
    desinstalacion,
  ];

  /// Todos menos el alta atienden una instalación vigente y piden código.
  bool get isMaintenance => this != instalacion;

  /// `idDispositivoNuevo` solo aplica a estos tipos.
  bool get takesNewDevice => this == instalacion || this == cEquipo;

  /// `idSimNuevo` solo aplica a estos tipos.
  bool get takesNewSim => this == instalacion || this == cSim;

  /// `estatusSalienteAnterior` solo aplica a los cambios.
  bool get takesOutgoingStatus => this == cEquipo || this == cSim;

  /// En una desinstalación el técnico contesta las pruebas en el `PATCH`; en
  /// los demás tipos programados las valida el operador (§9).
  bool get technicianAnswersTests => this == desinstalacion;

  static ServiceType? fromKey(String? key) {
    for (final type in values) {
      if (type.key == key) return type;
    }
    return null;
  }
}

/// Secciones y claves del catálogo `GET /ordenes-servicio/catalogo`.
class ServiceOrderSection {
  ServiceOrderSection._();

  static const vehicleFeatures = 'vehiculo_cuenta_con';
  static const vehicleOperation = 'funcionamiento_vehiculo';
  static const equipmentFailures = 'fallas_equipo';
  static const tests = 'pruebas';
  static const photos = 'fotos';
  static const signatures = 'firmas';

  /// Secciones sí/no que hay que responder completas para cerrar.
  static const checklist = [
    vehicleFeatures,
    vehicleOperation,
    equipmentFailures
  ];

  /// Falla que obliga a escribir observaciones.
  static const otherFailure = 'otro';

  /// Con `vehiculo_cuenta_con.inmovilizador` = sí se exige `paro_motor`.
  static const immobilizer = 'inmovilizador';
  static const engineStopTest = 'paro_motor';

  /// Evidencia del equipo encontrado en un alta (§7).
  static const existingEquipmentPhoto = 'equipo_existente';

  /// `falla_extra_1..3`.
  static const failurePhotoPrefix = 'falla';

  static const signatureClient = 'firma_cliente';
  static const signatureTechnician = 'firma_tecnico';
}

class ServiceOrderOption extends Equatable {
  final String key;
  final String name;
  final bool required;

  const ServiceOrderOption({
    required this.key,
    required this.name,
    this.required = false,
  });

  @override
  List<Object?> get props => [key, name, required];
}

class ServiceOrderCatalog {
  final Map<String, List<ServiceOrderOption>> sections;
  final List<CatalogItem> monitors;

  const ServiceOrderCatalog({required this.sections, required this.monitors});

  List<ServiceOrderOption> section(String key) => sections[key] ?? const [];

  ServiceOrderOption? option(String section, String key) =>
      this.section(section).where((option) => option.key == key).firstOrNull;

  /// Nombre de la opción o la clave legible si el catálogo no la trae.
  String nameOf(String section, String key) =>
      option(section, key)?.name ?? humanizeKey(key);
}

/// "cables_cortados" → "Cables cortados".
String humanizeKey(String key) {
  final text = key.replaceAll('_', ' ').trim();
  return text.isEmpty ? key : text[0].toUpperCase() + text.substring(1);
}

/// Motivo de `GET /ordenes-servicio/motivos`.
class NotCompletedReason extends Equatable {
  final String key;
  final String name;
  final List<String> results;
  final List<String> who;
  final bool requiresObservations;

  const NotCompletedReason({
    required this.key,
    required this.name,
    this.results = const [],
    this.who = const [],
    this.requiresObservations = false,
  });

  /// Solo se muestran los que aplican a "no cumplida" y al técnico (§2).
  bool get isForTechnician =>
      results.contains('no_cumplida') && who.contains('tecnico');

  @override
  List<Object?> get props => [key, name, results, who, requiresObservations];
}

/// Destino del equipo o SIM que sale en un cambio (desde el 30/10/2026 el API
/// solo acepta 3, 4 y 5).
enum OutgoingStatus {
  porRevisar(3, 'Por revisar'),
  laboratorio(4, 'Laboratorio'),
  inservible(5, 'Inservible');

  const OutgoingStatus(this.id, this.label);

  final int id;
  final String label;

  static OutgoingStatus? fromId(int? id) =>
      values.where((status) => status.id == id).firstOrNull;
}

/// `estatusInstalacionBaja` de una desinstalación.
enum RemovalStatus {
  inactiva(0, 'Inactiva', 'El equipo y la SIM van a revisión.'),
  inservible(
    5,
    'Inservible',
    'El equipo queda inservible y la SIM va a revisión.',
  );

  const RemovalStatus(this.id, this.label, this.description);

  final int id;
  final String label;
  final String description;

  static RemovalStatus? fromId(int? id) =>
      values.where((status) => status.id == id).firstOrNull;
}

/// Orden iniciada: `id` y folio (`OS-000042`).
class ServiceOrderRef extends Equatable {
  final String id;
  final String folio;

  const ServiceOrderRef({required this.id, required this.folio});

  @override
  List<Object?> get props => [id, folio];
}

/// Instalación vigente de un vehículo (para mostrar el equipo y la SIM que
/// tiene antes de un mantenimiento).
class CurrentInstallation extends Equatable {
  final String id;
  final String? productId;
  final String? productLabel;
  final String? deviceId;
  final String? deviceLabel;
  final String? simId;
  final String? simLabel;

  const CurrentInstallation({
    required this.id,
    this.productId,
    this.productLabel,
    this.deviceId,
    this.deviceLabel,
    this.simId,
    this.simLabel,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        productLabel,
        deviceId,
        deviceLabel,
        simId,
        simLabel,
      ];
}

/// Respuesta sí/no de una opción del catálogo.
class ServiceOrderAnswer extends Equatable {
  final String section;
  final String key;
  final bool value;

  const ServiceOrderAnswer(this.section, this.key, this.value);

  Map<String, dynamic> toJson() =>
      {'seccion': section, 'clave': key, 'valor': value};

  @override
  List<Object?> get props => [section, key, value];
}

/// Guardado parcial (`PATCH /ordenes-servicio/:id`, §5). Solo se envían los
/// campos indicados; los de [clear] se envían en `null`.
class ServiceOrderUpdate {
  final String? productId;
  final String? newDeviceId;
  final String? newSimId;
  final int? outgoingStatus;
  final int? removalStatus;
  final String? monitorId;
  final DateTime? capturedAt;
  final double? lat;
  final double? lng;
  final String? observations;
  final List<ServiceOrderAnswer> answers;
  final Set<String> clear;

  const ServiceOrderUpdate({
    this.productId,
    this.newDeviceId,
    this.newSimId,
    this.outgoingStatus,
    this.removalStatus,
    this.monitorId,
    this.capturedAt,
    this.lat,
    this.lng,
    this.observations,
    this.answers = const [],
    this.clear = const {},
  });

  bool get isEmpty => toJson().isEmpty;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      for (final field in clear) field: null,
    };
    void put(String key, Object? value) {
      if (value != null) json[key] = value;
    }

    put('idProducto', _number(productId));
    put('idDispositivoNuevo', _number(newDeviceId));
    put('idSimNuevo', _number(newSimId));
    put('estatusSalienteAnterior', outgoingStatus);
    put('estatusInstalacionBaja', removalStatus);
    put('idMonitorista', _number(monitorId));
    put('fechaCaptura', capturedAt == null ? null : isoWithOffset(capturedAt!));
    put('lat', lat);
    put('lng', lng);
    put('observaciones', observations);
    if (answers.isNotEmpty) {
      json['respuestas'] = answers.map((answer) => answer.toJson()).toList();
    }
    return json;
  }

  static Object? _number(String? id) =>
      id == null ? null : int.tryParse(id) ?? id;

  /// `2026-10-30T10:42:00-06:00`: hora local del celular con su desfase.
  static String isoWithOffset(DateTime date) {
    String two(int n) => n.abs().toString().padLeft(2, '0');
    final local = date.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
        '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
        '${two(local.second)}$sign${two(offset.inHours)}:'
        '${two(offset.inMinutes.remainder(60))}';
  }
}

/// Resultado de `POST /:id/codigo`: el código no llega a la App.
class VerificationCodeRequest extends Equatable {
  final String? message;
  final DateTime? expiresAt;

  const VerificationCodeRequest({this.message, this.expiresAt});

  @override
  List<Object?> get props => [message, expiresAt];
}

class ServiceOrderCloseResult extends Equatable {
  final String id;
  final String folio;
  final String? resultingInstallationId;

  const ServiceOrderCloseResult({
    required this.id,
    required this.folio,
    this.resultingInstallationId,
  });

  @override
  List<Object?> get props => [id, folio, resultingInstallationId];
}

/// Enlace público del PDF (`POST /:id/compartir`).
class ServiceOrderShareLink extends Equatable {
  final String url;
  final String? whatsappUrl;
  final int? validHours;

  const ServiceOrderShareLink({
    required this.url,
    this.whatsappUrl,
    this.validHours,
  });

  @override
  List<Object?> get props => [url, whatsappUrl, validHours];
}
