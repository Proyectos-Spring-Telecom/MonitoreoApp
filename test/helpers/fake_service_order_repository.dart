import 'dart:typed_data';

import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/data/datasources/local/order_key_storage.dart';
import 'package:monitoreo/domain/entities/catalog_item.dart';
import 'package:monitoreo/domain/entities/service_order.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';

ServiceOrderOption _o(String key, String name, {bool required = false}) =>
    ServiceOrderOption(key: key, name: name, required: required);

/// Catálogo de la guía: pruebas validadas por el operador, fotos y firmas.
final testCatalog = ServiceOrderCatalog(
  sections: {
    ServiceOrderSection.vehicleFeatures: [
      _o('boton_panico', 'Botón de pánico'),
      _o('inmovilizador', 'Inmovilizador'),
      _o('estereo', 'Estéreo'),
    ],
    ServiceOrderSection.vehicleOperation: [
      _o('tablero_iniciar', 'Tablero correcto al iniciar'),
      _o('tablero_final', 'Tablero correcto al final'),
    ],
    ServiceOrderSection.equipmentFailures: [
      _o('mojado', 'Mojado'),
      _o('otro', 'Otro (Especificar en observaciones)'),
    ],
    ServiceOrderSection.tests: [
      _o('transmision', 'Transmisión'),
      _o('boton_panico', 'Botón de pánico'),
      _o('paro_motor', 'Paro de motor'),
    ],
    ServiceOrderSection.photos: [
      _o('tablero_inicio', 'Tablero al iniciar', required: true),
      _o('tablero_final', 'Tablero al finalizar', required: true),
      _o('falla_extra_1', 'Imagen extra 1'),
      _o('equipo_existente', 'Equipo existente'),
    ],
    ServiceOrderSection.signatures: [
      _o('firma_cliente', 'Firma del cliente', required: true),
      _o('firma_tecnico', 'Firma del técnico', required: true),
    ],
  },
  monitors: const [
    CatalogItem(id: '15', name: 'Ana López Ruiz'),
  ],
);

ServiceOrderRecord scheduledOrder({
  String id = '42',
  ServiceType type = ServiceType.revision,
  ServiceOrderStatus status = ServiceOrderStatus.programada,
  bool codeValidated = false,
  String? productId,
  AuthorizationStatus? authorization,
  List<String> missing = const [],
  List<ServiceOrderTest> tests = const [],
  List<ServiceOrderAnswer> answers = const [],
  String? origin = 'agenda',
}) =>
    ServiceOrderRecord(
      id: id,
      folio: 'OS-0000$id',
      typeKey: status == ServiceOrderStatus.programada ? '' : type.key,
      scheduledTypeKey: type.key,
      statusKey: status.key,
      origin: origin,
      appointment: DateTime.utc(2026, 10, 30, 16),
      clientId: '12',
      clientName: 'Transportes del Sur',
      plate: 'ABC1234',
      scheduledInstallationId: type.isMaintenance ? '340' : null,
      installationId: type.isMaintenance ? '340' : null,
      productId: productId,
      codeValidated: codeValidated,
      authorization: authorization,
      missingToClose: missing,
      tests: tests,
      answers: answers,
    );

/// Repositorio en memoria: [order] es lo que devuelve `GET /:id`; cada
/// acción la registra y puede cambiar la orden con [onAction].
class FakeServiceOrderRepository implements ServiceOrderRepository {
  ServiceOrderRecord order;
  ServiceOrderCatalog catalog = testCatalog;
  List<NotCompletedReason> reasons = const [
    NotCompletedReason(
      key: 'cliente_ausente',
      name: 'Cliente ausente',
      results: ['no_cumplida'],
      who: ['tecnico'],
    ),
  ];
  List<ServiceOrderRecord> agenda = const [];

  /// Error que lanzará la siguiente acción con ese nombre.
  final Map<String, Failure> failures = {};

  /// Permite que una acción cambie la orden (p. ej. iniciar → borrador).
  void Function(String action, FakeServiceOrderRepository repo)? onAction;

  final calls = <String>[];
  final started = <(String, String, ServiceType?, String?)>[];
  final updates = <Map<String, dynamic>>[];
  final uploads = <(String, Uint8List)>[];
  final requestedTests = <(String, String?)>[];
  int getOrderCalls = 0;

  FakeServiceOrderRepository(this.order);

  Future<void> _act(String action) async {
    calls.add(action);
    final failure = failures.remove(action);
    if (failure != null) throw failure;
    onAction?.call(action, this);
  }

  @override
  Future<ServiceOrderCatalog> getCatalog({bool forceRefresh = false}) async =>
      catalog;

  @override
  Future<List<NotCompletedReason>> getReasons({
    bool forceRefresh = false,
  }) async =>
      reasons;

  @override
  Future<PagedServiceOrders> listOrders({
    ServiceOrderStatus? status,
    int page = 1,
    int limit = 50,
  }) async {
    final items = agenda.where((o) => status == null || o.status == status);
    return PagedServiceOrders(
      items: items.toList(),
      total: items.length,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<ServiceOrderRecord> getOrder(String orderId) async {
    getOrderCalls++;
    await _act('getOrder');
    return order;
  }

  @override
  Future<ServiceOrderRef> startOrder(
    String orderId, {
    required String appKey,
    ServiceType? type,
    String? installationId,
  }) async {
    started.add((orderId, appKey, type, installationId));
    await _act('start');
    return ServiceOrderRef(id: orderId, folio: order.folio);
  }

  @override
  Future<void> updateOrder(String orderId, ServiceOrderUpdate update) async {
    updates.add(update.toJson());
    await _act('update');
  }

  @override
  Future<void> uploadFile(
    String orderId,
    String key,
    Uint8List bytes, {
    required String label,
  }) async {
    uploads.add((key, bytes));
    await _act('upload');
  }

  @override
  Future<void> requestAuthorization(
    String orderId, {
    required String observations,
  }) =>
      _act('authorization');

  @override
  Future<VerificationCodeRequest> requestCode(String orderId) async {
    await _act('code');
    return VerificationCodeRequest(expiresAt: DateTime.utc(2026, 10, 30, 17));
  }

  @override
  Future<void> validateCode(String orderId, String code) =>
      _act('validate:$code');

  @override
  Future<void> requestTest(
    String orderId,
    String key, {
    String? observations,
  }) async {
    requestedTests.add((key, observations));
    await _act('test:$key');
  }

  @override
  Future<ServiceOrderCloseResult> closeOrder(String orderId) async {
    await _act('close');
    return ServiceOrderCloseResult(id: orderId, folio: order.folio);
  }

  @override
  Future<void> markNotCompleted(
    String orderId, {
    required String reasonKey,
    String? observations,
  }) =>
      _act('not_completed:$reasonKey');

  @override
  Future<Uint8List> downloadPdf(String orderId) async {
    await _act('pdf');
    return Uint8List(0);
  }

  @override
  Future<ServiceOrderShareLink> shareOrder(
    String orderId, {
    String? phone,
  }) async {
    await _act('share');
    return const ServiceOrderShareLink(url: 'https://next.test/pdf');
  }

  @override
  Future<String?> sendByEmail(String orderId, List<String> emails) async {
    await _act('email');
    return 'Correo enviado';
  }

  @override
  Future<CurrentInstallation?> getInstallation(String installationId) async =>
      CurrentInstallation(
        id: installationId,
        deviceId: '500',
        deviceLabel: 'Imei: 111',
        simId: '60',
        simLabel: 'Telefono: 777',
      );

  @override
  Future<CurrentInstallation?> findCurrentInstallation({
    required String productId,
  }) async =>
      null;

  @override
  void clearCache() {}
}

class MemoryOrderKeyStorage implements OrderKeyStorage {
  final Map<String, String> keys = {};
  int _next = 1;

  @override
  Future<String> keyFor(String orderId) async =>
      keys[orderId] ??= 'clave-${_next++}';

  @override
  Future<void> remove(String orderId) async => keys.remove(orderId);

  @override
  Future<void> clear() async => keys.clear();
}
