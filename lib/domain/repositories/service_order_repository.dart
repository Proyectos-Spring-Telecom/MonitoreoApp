import 'dart:typed_data';

import '../entities/service_order.dart';
import '../entities/service_order_record.dart';

/// Contrato con `/ordenes-servicio` para el técnico (rol 8). El API ya filtra
/// las órdenes del técnico del token.
abstract class ServiceOrderRepository {
  /// Opciones por sección y monitoristas. Se guarda en memoria.
  Future<ServiceOrderCatalog> getCatalog({bool forceRefresh = false});

  /// Motivos de no cumplida que puede usar el técnico. Se guarda en memoria.
  Future<List<NotCompletedReason>> getReasons({bool forceRefresh = false});

  /// Agenda (`programada`, por cita ascendente), en curso (`borrador`) o
  /// historial (`cerrada`, `no_cumplida`, más recientes primero).
  Future<PagedServiceOrders> listOrders({
    ServiceOrderStatus? status,
    int page = 1,
    int limit = 50,
  });

  /// Detalle con respuestas, pruebas, archivos y lo que falta para cerrar.
  Future<ServiceOrderRecord> getOrder(String orderId);

  /// `POST /:id/iniciar`. Con la misma [appKey] el servidor responde que ya
  /// estaba iniciada.
  Future<ServiceOrderRef> startOrder(
    String orderId, {
    required String appKey,
    ServiceType? type,
    String? installationId,
  });

  Future<void> updateOrder(String orderId, ServiceOrderUpdate update);

  /// Sube una foto o firma con su clave del catálogo; reemplaza la anterior.
  Future<void> uploadFile(
    String orderId,
    String key,
    Uint8List bytes, {
    required String label,
  });

  /// [thirdParty]: el técnico reportó un equipo que Next no tiene registrado
  /// (otro proveedor); se envía `equipoTercero: true`.
  Future<void> requestAuthorization(
    String orderId, {
    required String observations,
    bool thirdParty = false,
  });

  Future<VerificationCodeRequest> requestCode(String orderId);

  Future<void> validateCode(String orderId, String code);

  Future<void> requestTest(String orderId, String key, {String? observations});

  /// Lanza `IncompleteOrderFailure` con la lista del servidor si falta algo.
  Future<ServiceOrderCloseResult> closeOrder(String orderId);

  Future<void> markNotCompleted(
    String orderId, {
    required String reasonKey,
    String? observations,
  });

  Future<Uint8List> downloadPdf(String orderId);

  Future<ServiceOrderShareLink> shareOrder(String orderId, {String? phone});

  /// Devuelve el mensaje del servidor.
  Future<String?> sendByEmail(String orderId, List<String> emails);

  /// Equipo y SIM actuales de una instalación (solo para mostrarlos).
  Future<CurrentInstallation?> getInstallation(String installationId);

  /// Instalación vigente de un vehículo, para atender otro distinto al
  /// programado.
  Future<CurrentInstallation?> findCurrentInstallation({
    required String productId,
  });

  /// Olvida los catálogos guardados (al cerrar sesión).
  void clearCache();
}
