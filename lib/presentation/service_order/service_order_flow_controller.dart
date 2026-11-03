import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/services/location_service.dart';
import '../../data/datasources/local/order_key_storage.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/repositories/service_order_repository.dart';

/// Pasos de una orden iniciada. Cuáles aplican depende del tipo (§15).
enum ServiceOrderStep {
  vehicle('Vehículo', 'Datos del vehículo'),
  verification('Código', 'Código de verificación'),
  installation('Instalación', 'Instalación'),
  checklist('Checklist', 'Checklist del vehículo'),
  tests('Pruebas', 'Pruebas y firmas'),
  summary('Resumen', 'Resumen');

  const ServiceOrderStep(this.label, this.title);

  /// Texto corto del indicador de pasos.
  final String label;
  final String title;
}

typedef DeviceLocation = ({double lat, double lng});

/// Lee la ubicación del teléfono; `null` si se negó el permiso.
typedef LocationReader = Future<DeviceLocation?> Function();

Future<DeviceLocation?> readDeviceLocation() async {
  final position = await LocationService.getCurrentLocation();
  return position == null
      ? null
      : (lat: position.latitude, lng: position.longitude);
}

/// Estado de una orden de la agenda, de iniciarla a cerrarla. Es el único
/// que habla con el API; las pantallas solo muestran y capturan.
///
/// Reglas del contrato (§13): un 404 significa que la orden ya no es del
/// técnico ([isGone]); un 409, que otra acción se adelantó, así que se recarga
/// la orden antes de reportar el error.
class ServiceOrderFlowController extends ChangeNotifier {
  static const String codesExhaustedMessage =
      'Comunícate con operación para que reinicie los códigos.';

  final ServiceOrderRepository repository;
  final OrderKeyStorage keyStorage;
  final String orderId;
  final LocationReader readLocation;
  final DateTime Function() clock;

  /// Consulta mientras se espera la autorización o una prueba (10–15 s).
  final Duration pollInterval;

  ServiceOrderFlowController({
    required this.repository,
    required this.keyStorage,
    required this.orderId,
    ServiceOrderRecord? initial,
    LocationReader? readLocation,
    DateTime Function()? clock,
    this.pollInterval = const Duration(seconds: 12),
  })  : _order = initial,
        readLocation = readLocation ?? readDeviceLocation,
        clock = clock ?? DateTime.now;

  ServiceOrderRecord? _order;
  ServiceOrderCatalog? _catalog;
  bool _isLoading = false;
  String? _loadError;
  bool _isGone = false;
  String? _goneMessage;
  bool _isBusy = false;
  int _stepIndex = 0;
  bool _disposed = false;

  Timer? _pollTimer;
  bool _polling = false;

  VerificationCodeRequest? _codeRequest;
  bool _codesExhausted = false;

  /// Bytes de cada foto o firma subida en esta sesión, para no reenviarla.
  final Map<String, Uint8List> _uploaded = {};

  ServiceOrderRecord? get order => _order;
  ServiceOrderCatalog? get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isGone => _isGone;
  String? get goneMessage => _goneMessage;
  bool get isBusy => _isBusy;
  bool get isPolling => _pollTimer != null;
  VerificationCodeRequest? get codeRequest => _codeRequest;
  bool get codesExhausted => _codesExhausted;

  ServiceOrderStatus? get status => _order?.status;
  ServiceType? get type => _order?.type;

  // ---------------------------------------------------------------------------
  // Pasos

  List<ServiceOrderStep> get steps {
    final order = _order;
    final type = order?.type;
    if (order == null || type == null) return const [];
    return [
      if (type == ServiceType.instalacion) ServiceOrderStep.vehicle,
      if (type.isMaintenance && !order.isLegacy) ServiceOrderStep.verification,
      ServiceOrderStep.installation,
      ServiceOrderStep.checklist,
      ServiceOrderStep.tests,
      ServiceOrderStep.summary,
    ];
  }

  int get stepIndex => _stepIndex;

  ServiceOrderStep? get currentStep {
    final steps = this.steps;
    return steps.isEmpty ? null : steps[_stepIndex.clamp(0, steps.length - 1)];
  }

  /// Un paso que bloquea los siguientes: el vehículo del alta (fijado y, si
  /// tenía equipo, autorizado) y el código de un mantenimiento.
  bool isBlocking(ServiceOrderStep step) {
    final order = _order;
    if (order == null) return true;
    return switch (step) {
      ServiceOrderStep.vehicle => order.productId == null ||
          order.needsAuthorization ||
          (order.authorization != null &&
              order.authorization != AuthorizationStatus.autorizada),
      ServiceOrderStep.verification => order.requiresCode,
      _ => false,
    };
  }

  /// Índice del primer paso bloqueado, o `null` si ninguno bloquea.
  int? get _firstBlocked {
    final steps = this.steps;
    for (var i = 0; i < steps.length; i++) {
      if (isBlocking(steps[i])) return i;
    }
    return null;
  }

  bool canEnter(ServiceOrderStep step) {
    final index = steps.indexOf(step);
    final blocked = _firstBlocked;
    return index >= 0 && (blocked == null || index <= blocked);
  }

  void goTo(ServiceOrderStep step) {
    if (!canEnter(step)) return;
    _stepIndex = steps.indexOf(step);
    notifyListeners();
  }

  void next() {
    final current = currentStep;
    if (current == null || isBlocking(current)) return;
    if (_stepIndex < steps.length - 1) {
      _stepIndex++;
      notifyListeners();
    }
  }

  /// `false` si ya está en el primer paso.
  bool back() {
    if (_stepIndex == 0) return false;
    _stepIndex--;
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Carga

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      final results = await Future.wait([
        _guard(() => repository.getOrder(orderId)),
        repository.getCatalog(),
      ]);
      _catalog = results[1] as ServiceOrderCatalog;
      _setOrder(results[0] as ServiceOrderRecord, resume: true);
    } on Failure catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'No se pudo cargar la orden. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Vuelve a pedir la orden. Los errores se reportan a quien llama.
  Future<void> refresh() async {
    final order = await _guard(() => repository.getOrder(orderId));
    _setOrder(order);
  }

  void _setOrder(ServiceOrderRecord order, {bool resume = false}) {
    _order = order;
    final steps = this.steps;
    if (resume) {
      // Al retomar una orden se abre el primer paso que falta desbloquear.
      _stepIndex = _firstBlocked ?? 0;
    } else if (steps.isNotEmpty) {
      final blocked = _firstBlocked;
      _stepIndex = _stepIndex.clamp(0, blocked ?? steps.length - 1);
    }
    if (!(order.type?.isMaintenance ?? false) || order.codeValidated) {
      _codeRequest = null;
    }
    _updatePolling();
    _notify();
  }

  /// Sin push en el API: mientras se espera la autorización o el resultado de
  /// una prueba se consulta `GET /:id` cada [pollInterval].
  void _updatePolling() {
    final order = _order;
    final waiting = order != null &&
        order.status == ServiceOrderStatus.borrador &&
        (order.authorization == AuthorizationStatus.pendiente ||
            order.hasPendingTests);
    if (waiting && _pollTimer == null && !_disposed) {
      _pollTimer = Timer.periodic(pollInterval, (_) => _pollOnce());
    } else if (!waiting) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _pollOnce() async {
    if (_polling || _isBusy || _disposed) return;
    _polling = true;
    try {
      await refresh();
    } catch (_) {
      // Se reintenta en la siguiente consulta; un 404 ya marcó [isGone].
    } finally {
      _polling = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones

  /// `POST /:id/iniciar` con la `claveApp` guardada de esta orden. [type]
  /// solo se envía si difiere de lo programado. Luego registra la fecha y la
  /// ubicación de llegada.
  Future<void> start({ServiceType? type, String? installationId}) =>
      _busy(() async {
        await _startOnServer(type: type, installationId: installationId);
        await _saveArrival();
        _stepIndex = 0;
        await refresh();
      });

  Future<void> _startOnServer({
    ServiceType? type,
    String? installationId,
  }) async {
    final order = _order;
    final appKey = await keyStorage.keyFor(orderId);
    final scheduled = order?.scheduledType ?? order?.type;
    await _guard(() => repository.startOrder(
          orderId,
          appKey: appKey,
          type: type != null && type != scheduled ? type : null,
          installationId: installationId,
        ));
  }

  /// `fechaCaptura`, `lat` y `lng`; en `null` si se negó la ubicación. Si
  /// falla aquí se vuelve a intentar al guardar las pruebas.
  Future<void> _saveArrival() async {
    try {
      await _guard(() async => repository.updateOrder(
            orderId,
            await _arrivalUpdate(),
          ));
    } on Failure catch (e) {
      if (e.isNotFound) rethrow;
    }
  }

  Future<ServiceOrderUpdate> _arrivalUpdate() async {
    DeviceLocation? location;
    try {
      location = await readLocation();
    } catch (_) {
      location = null;
    }
    return ServiceOrderUpdate(
      capturedAt: clock(),
      lat: location?.lat,
      lng: location?.lng,
      clear: location == null ? const {'lat', 'lng'} : const {},
    );
  }

  /// Alta: fija el vehículo de la orden. El servidor indica después en
  /// `faltantesParaCerrar` si ya tiene equipo y hace falta autorización.
  Future<void> setVehicle(String productId) => _busy(() async {
        await _guard(() => repository.updateOrder(
              orderId,
              ServiceOrderUpdate(productId: productId),
            ));
        await refresh();
      });

  /// Sube la foto del equipo encontrado y pide la autorización (§7).
  Future<void> requestAuthorization({
    Uint8List? photo,
    required String photoLabel,
    required String observations,
  }) =>
      _busy(() async {
        if (photo != null) {
          await _upload(
            ServiceOrderSection.existingEquipmentPhoto,
            photo,
            photoLabel,
          );
        }
        await _guard(() => repository.requestAuthorization(
              orderId,
              observations: observations,
            ));
        await refresh();
      });

  /// El código lo dicta el operador en turno. Con el tope de 5 códigos el API
  /// responde 409 y ya no se reintenta (§8).
  Future<void> requestCode() => _busy(() async {
        try {
          _codeRequest = await _guard(() => repository.requestCode(orderId));
          _notify();
        } on Failure catch (e) {
          if (!e.isConflict) rethrow;
          _codesExhausted = true;
          _notify();
          throw const ServerFailure(codesExhaustedMessage, statusCode: 409);
        }
      });

  Future<void> validateCode(String code) => _busy(() async {
        await _guard(() => repository.validateCode(orderId, code));
        await refresh();
      });

  Future<void> saveInstallation(ServiceOrderUpdate update) => _busy(() async {
        await _guard(() => repository.updateOrder(orderId, update));
        await refresh();
      });

  /// Respuestas de las secciones sí/no y fotos nuevas (clave → etiqueta y
  /// bytes).
  Future<void> saveChecklist({
    required List<ServiceOrderAnswer> answers,
    Map<String, (String, Uint8List)> photos = const {},
  }) =>
      _busy(() async {
        await _guard(() => repository.updateOrder(
              orderId,
              ServiceOrderUpdate(answers: answers),
            ));
        for (final MapEntry(:key, value: (label, bytes)) in photos.entries) {
          await _upload(key, bytes, label);
        }
        await refresh();
      });

  Future<void> requestTest(String key, {String? observations}) =>
      _busy(() async {
        await _guard(() => repository.requestTest(
              orderId,
              key,
              observations: observations,
            ));
        await refresh();
      });

  /// Monitorista, observaciones, firmas y, cuando las contesta el técnico,
  /// las pruebas. Si la llegada no se registró, se registra aquí.
  Future<void> saveClosingData({
    required String monitorId,
    required String observations,
    List<ServiceOrderAnswer> testAnswers = const [],
    Map<String, (String, Uint8List)> signatures = const {},
  }) =>
      _busy(() async {
        final arrival =
            _order?.capturedAt == null ? await _arrivalUpdate() : null;
        await _guard(() => repository.updateOrder(
              orderId,
              ServiceOrderUpdate(
                monitorId: monitorId,
                observations: observations.trim(),
                answers: testAnswers,
                capturedAt: arrival?.capturedAt,
                lat: arrival?.lat,
                lng: arrival?.lng,
                clear: arrival?.clear ?? const {},
              ),
            ));
        for (final MapEntry(:key, value: (label, bytes))
            in signatures.entries) {
          await _upload(key, bytes, label);
        }
        await refresh();
      });

  /// Solo con `faltantesParaCerrar` vacío. Si el servidor responde que falta
  /// algo se recarga la orden y se lanza `IncompleteOrderFailure`.
  Future<ServiceOrderCloseResult> close() => _busy(() async {
        try {
          final result = await _guard(() => repository.closeOrder(orderId));
          await keyStorage.remove(orderId);
          await refresh();
          return result;
        } on IncompleteOrderFailure {
          await _refreshQuietly();
          rethrow;
        }
      });

  /// Si la orden aún no se iniciaba, primero se inicia (§15, "No se pudo").
  Future<void> markNotCompleted({
    required String reasonKey,
    String? observations,
  }) =>
      _busy(() async {
        if (_order?.status == ServiceOrderStatus.programada) {
          await _startOnServer();
        }
        await _guard(() => repository.markNotCompleted(
              orderId,
              reasonKey: reasonKey,
              observations: observations,
            ));
        await keyStorage.remove(orderId);
        await refresh();
      });

  // ---------------------------------------------------------------------------
  // Utilidades

  bool isUploaded(String key, Uint8List bytes) {
    final sent = _uploaded[key];
    return sent != null && (identical(sent, bytes) || listEquals(sent, bytes));
  }

  Future<void> _upload(String key, Uint8List bytes, String label) async {
    if (isUploaded(key, bytes)) return;
    await _guard(
      () => repository.uploadFile(orderId, key, bytes, label: label),
    );
    _uploaded[key] = bytes;
  }

  Future<void> _refreshQuietly() async {
    try {
      await refresh();
    } catch (_) {}
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure catch (e) {
      if (e.isNotFound) {
        _isGone = true;
        _goneMessage = e.message;
        _pollTimer?.cancel();
        _pollTimer = null;
        _notify();
      } else if (e.isConflict) {
        try {
          _setOrder(await repository.getOrder(orderId));
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<T> _busy<T>(Future<T> Function() action) async {
    _isBusy = true;
    _notify();
    try {
      return await action();
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }
}
