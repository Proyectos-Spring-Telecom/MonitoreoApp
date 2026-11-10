import 'package:equatable/equatable.dart';

import 'service_order.dart';

/// `programada` → `borrador` (iniciada) → `cerrada` / `no_cumplida`; o
/// `cancelada` (solo operación).
enum ServiceOrderStatus {
  programada('programada', 'Programada'),
  borrador('borrador', 'En curso'),
  cerrada('cerrada', 'Cerrada'),
  noCumplida('no_cumplida', 'No cumplida'),
  cancelada('cancelada', 'Cancelada');

  const ServiceOrderStatus(this.key, this.label);

  final String key;
  final String label;

  /// Compartir y enviar por correo solo con la orden terminada (§12).
  bool get canShare => this == cerrada || this == noCumplida;

  bool get isFinished => canShare || this == cancelada;

  static ServiceOrderStatus? fromKey(String? key) {
    for (final status in values) {
      if (status.key == key) return status;
    }
    return null;
  }
}

/// Autorización para desinstalar el equipo encontrado en un alta (§7).
enum AuthorizationStatus {
  pendiente('pendiente'),
  autorizada('autorizada'),
  rechazada('rechazada');

  const AuthorizationStatus(this.key);

  final String key;

  static AuthorizationStatus? fromKey(String? key) =>
      values.where((status) => status.key == key).firstOrNull;
}

enum TestStatus {
  solicitada('solicitada', 'Esperando al operador'),
  correcta('correcta', 'Correcta'),
  fallida('fallida', 'Fallida'),
  anulada('anulada', 'Anulada');

  const TestStatus(this.key, this.label);

  final String key;
  final String label;

  static TestStatus? fromKey(String? key) =>
      values.where((status) => status.key == key).firstOrNull;
}

/// Prueba pedida por el técnico y validada por el operador (§9).
class ServiceOrderTest extends Equatable {
  final String key;
  final TestStatus? status;
  final DateTime? requestedAt;
  final String? technicianNote;
  final DateTime? validatedAt;
  final String? validatedBy;
  final String? operatorNote;

  const ServiceOrderTest({
    required this.key,
    this.status,
    this.requestedAt,
    this.technicianNote,
    this.validatedAt,
    this.validatedBy,
    this.operatorNote,
  });

  @override
  List<Object?> get props => [
        key,
        status,
        requestedAt,
        technicianNote,
        validatedAt,
        validatedBy,
        operatorNote,
      ];
}

/// Foto o firma de la orden; la [url] firmada caduca a los 5 minutos y no se
/// guarda.
class ServiceOrderFile extends Equatable {
  final String key;
  final String url;
  final DateTime? createdAt;

  /// Nombre que manda el servidor (p. ej. en `fotosVehiculo`).
  final String? name;

  const ServiceOrderFile({
    required this.key,
    required this.url,
    this.createdAt,
    this.name,
  });

  @override
  List<Object?> get props => [key, url, createdAt, name];
}

/// Equipo de una instalación en textos listos para mostrar, como en el PDF:
/// "Suntech ST210 - IMEI 3333 - Serie: 0000009".
class InstallationSummary extends Equatable {
  final String? equipmentType;
  final String? device;
  final String? sim;

  const InstallationSummary({this.equipmentType, this.device, this.sim});

  bool get isEmpty => equipmentType == null && device == null && sim == null;

  bool get isComplete => equipmentType != null && device != null && sim != null;

  /// Completa los datos que faltan con los de [other].
  InstallationSummary withFallback(InstallationSummary? other) =>
      InstallationSummary(
        equipmentType: equipmentType ?? other?.equipmentType,
        device: device ?? other?.device,
        sim: sim ?? other?.sim,
      );

  @override
  List<Object?> get props => [equipmentType, device, sim];
}

/// Orden tal como la devuelve el API (§3).
class ServiceOrderRecord extends Equatable {
  /// Texto de `faltantesParaCerrar` que indica que falta la autorización.
  static const String _authorizationMissing = 'ya tiene un equipo instalado';

  final String id;
  final String folio;
  final String typeKey;
  final String? scheduledTypeKey;
  final String? statusKey;
  final String? origin;

  final DateTime? appointment;
  final DateTime? appointmentEnd;
  final String? scheduledBy;

  final String? clientId;
  final String? clientName;
  final String? plate;
  final String? economicNumber;
  final String? productName;

  final String? scheduledInstallationId;
  final String? installationId;
  final String? productId;
  final String? resultingInstallationId;

  /// `instalacion` e `instalacionResultado`.
  final InstallationSummary? installation;
  final InstallationSummary? resultingInstallation;

  /// `dispositivoNuevo` y `simNuevo`: lo que entra mientras la orden no se
  /// cierra.
  final InstallationSummary? newEquipment;

  final String? crmReference;
  final int? unit;
  final int? unitsTotal;

  final bool codeValidated;
  final AuthorizationStatus? authorization;

  final String? newDeviceId;
  final String? newSimId;
  final int? outgoingStatus;
  final int? removalStatus;
  final String? technicianId;
  final String? monitorId;
  final DateTime? capturedAt;
  final double? lat;
  final double? lng;
  final String? observations;
  final String? reasonKey;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? closedAt;

  final List<ServiceOrderTest> tests;
  final List<ServiceOrderAnswer> answers;
  final List<ServiceOrderFile> files;

  /// `fotosVehiculo`: fotos registradas en el vehículo, no en la orden.
  final List<ServiceOrderFile> vehiclePhotos;
  final List<String> missingToClose;

  const ServiceOrderRecord({
    required this.id,
    required this.folio,
    this.typeKey = '',
    this.scheduledTypeKey,
    this.statusKey,
    this.origin,
    this.appointment,
    this.appointmentEnd,
    this.scheduledBy,
    this.clientId,
    this.clientName,
    this.plate,
    this.economicNumber,
    this.productName,
    this.scheduledInstallationId,
    this.installationId,
    this.productId,
    this.resultingInstallationId,
    this.installation,
    this.resultingInstallation,
    this.newEquipment,
    this.crmReference,
    this.unit,
    this.unitsTotal,
    this.codeValidated = false,
    this.authorization,
    this.newDeviceId,
    this.newSimId,
    this.outgoingStatus,
    this.removalStatus,
    this.technicianId,
    this.monitorId,
    this.capturedAt,
    this.lat,
    this.lng,
    this.observations,
    this.reasonKey,
    this.createdAt,
    this.startedAt,
    this.closedAt,
    this.tests = const [],
    this.answers = const [],
    this.files = const [],
    this.vehiclePhotos = const [],
    this.missingToClose = const [],
  });

  /// Lo que quedó instalado. Antes de cerrar: en el alta, lo que se va a
  /// instalar; en los mantenimientos, lo que se atiende.
  InstallationSummary? get equipment =>
      resultingInstallation ??
      (type == ServiceType.instalacion ? newEquipment : installation);

  /// Solo la foto "Principal" (`clave: foto`); sin ella se muestra el ícono.
  ServiceOrderFile? get vehiclePhoto => vehiclePhotos
      .where((photo) =>
          photo.key == 'foto' ||
          photo.name?.trim().toLowerCase() == 'principal')
      .firstOrNull;

  /// Lo que se está haciendo o, mientras no se inicia, lo programado.
  ServiceType? get type =>
      ServiceType.fromKey(typeKey) ?? ServiceType.fromKey(scheduledTypeKey);

  ServiceType? get scheduledType => ServiceType.fromKey(scheduledTypeKey);

  ServiceOrderStatus? get status => ServiceOrderStatus.fromKey(statusKey);

  /// Borrador creado por el técnico con `POST /ordenes-servicio` antes de la
  /// agenda (§14): no pide código y el técnico marca las pruebas.
  bool get isLegacy => origin == null && scheduledTypeKey == null;

  bool get requiresCode =>
      (type?.isMaintenance ?? false) && !isLegacy && !codeValidated;

  /// En órdenes programadas las pruebas las valida el operador, salvo en
  /// desinstalación (§5, §9).
  bool get technicianAnswersTests =>
      isLegacy || (type?.technicianAnswersTests ?? false);

  /// El alta encontró un equipo instalado y aún no se pide la autorización.
  bool get needsAuthorization =>
      authorization == null &&
      missingToClose.any(
        (item) => item.toLowerCase().contains(_authorizationMissing),
      );

  /// Una vez pedida (o autorizada) el vehículo ya no se puede cambiar.
  bool get vehicleLocked => authorization != null;

  /// Fecha con la que se ordena y agrupa.
  DateTime? get date => appointment ?? capturedAt ?? startedAt ?? createdAt;

  bool get hasLocation => lat != null && lng != null;

  /// "ABC1234 · ECO-045", el nombre del producto o `null`.
  String? get vehicleLabel {
    final parts = [plate, economicNumber]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' · ');
    return productName;
  }

  /// "Unidad 2 de 5" en altas de varias unidades.
  String? get unitLabel {
    final total = unitsTotal;
    if (unit == null || total == null || total <= 1) return null;
    return 'Unidad $unit de $total';
  }

  List<ServiceOrderAnswer> answersOf(String section) =>
      answers.where((answer) => answer.section == section).toList();

  bool? answer(String section, String key) => answers
      .where((answer) => answer.section == section && answer.key == key)
      .firstOrNull
      ?.value;

  bool get hasImmobilizer =>
      answer(
        ServiceOrderSection.vehicleFeatures,
        ServiceOrderSection.immobilizer,
      ) ??
      false;

  ServiceOrderTest? test(String key) =>
      tests.where((test) => test.key == key).firstOrNull;

  bool get hasPendingTests =>
      tests.any((test) => test.status == TestStatus.solicitada);

  ServiceOrderFile? file(String key) =>
      files.where((file) => file.key == key).firstOrNull;

  @override
  List<Object?> get props => [
        id,
        folio,
        typeKey,
        scheduledTypeKey,
        statusKey,
        origin,
        appointment,
        appointmentEnd,
        scheduledBy,
        clientId,
        clientName,
        plate,
        economicNumber,
        productName,
        scheduledInstallationId,
        installationId,
        productId,
        resultingInstallationId,
        installation,
        resultingInstallation,
        newEquipment,
        crmReference,
        unit,
        unitsTotal,
        codeValidated,
        authorization,
        newDeviceId,
        newSimId,
        outgoingStatus,
        removalStatus,
        technicianId,
        monitorId,
        capturedAt,
        lat,
        lng,
        observations,
        reasonKey,
        createdAt,
        startedAt,
        closedAt,
        tests,
        answers,
        files,
        vehiclePhotos,
        missingToClose,
      ];
}

class PagedServiceOrders extends Equatable {
  final List<ServiceOrderRecord> items;
  final int total;
  final int page;
  final int limit;

  const PagedServiceOrders({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  bool get hasMore => page * limit < total;

  @override
  List<Object?> get props => [items, total, page, limit];
}

/// Reglas del catálogo que dependen de la orden.
extension ServiceOrderCatalogRules on ServiceOrderCatalog {
  /// `paro_motor` solo se pide si el vehículo tiene inmovilizador (§9).
  List<ServiceOrderOption> testsFor(ServiceOrderRecord order) => section(
        ServiceOrderSection.tests,
      )
          .where((test) =>
              test.key != ServiceOrderSection.engineStopTest ||
              order.hasImmobilizer)
          .toList();

  /// "Fallas encontradas del equipo" no aplica a un alta: sus opciones se
  /// responden en "no" y sus fotos no se piden.
  bool showsFailures(ServiceType? type) => type != ServiceType.instalacion;

  /// Fotos del checklist, sin la evidencia del equipo encontrado (§7).
  List<ServiceOrderOption> checklistPhotosFor(ServiceType? type) =>
      section(ServiceOrderSection.photos)
          .where((photo) =>
              photo.key != ServiceOrderSection.existingEquipmentPhoto &&
              (showsFailures(type) ||
                  !photo.key
                      .startsWith(ServiceOrderSection.failurePhotoPrefix)))
          .toList();

  /// Si el catálogo no trae la sección se exigen las dos firmas.
  List<ServiceOrderOption> get signatureOptions {
    final options = section(ServiceOrderSection.signatures);
    if (options.isNotEmpty) return options;
    return const [
      ServiceOrderOption(
        key: ServiceOrderSection.signatureClient,
        name: 'Firma del cliente',
        required: true,
      ),
      ServiceOrderOption(
        key: ServiceOrderSection.signatureTechnician,
        name: 'Firma del técnico',
        required: true,
      ),
    ];
  }
}
