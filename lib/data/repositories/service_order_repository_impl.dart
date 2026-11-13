import 'package:flutter/foundation.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_reader.dart';
import '../../core/utils/mexico_time.dart';
import '../../core/utils/upload_image.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../models/service_order_model.dart';

class ServiceOrderRepositoryImpl implements ServiceOrderRepository {
  final ApiClient apiClient;

  ServiceOrderCatalog? _catalog;
  Future<ServiceOrderCatalog>? _loadingCatalog;
  List<NotCompletedReason>? _reasons;
  Future<List<NotCompletedReason>>? _loadingReasons;

  ServiceOrderRepositoryImpl(this.apiClient);

  @override
  Future<ServiceOrderCatalog> getCatalog({bool forceRefresh = false}) {
    final cached = _catalog;
    if (cached != null && !forceRefresh) return Future.value(cached);
    return _loadingCatalog ??=
        _fetchCatalog().whenComplete(() => _loadingCatalog = null);
  }

  Future<ServiceOrderCatalog> _fetchCatalog() async {
    final response = await apiClient.get(ApiEndpoints.serviceOrderCatalog);
    final catalog = ServiceOrderModel.catalog(response);
    if (kDebugMode) {
      final counts = catalog.sections.entries
          .map((e) => '${e.key}: ${e.value.length}')
          .join(', ');
      debugPrint('[API] Catálogo de órdenes · $counts · '
          'monitoristas: ${catalog.monitors.length}');
    }
    return _catalog = catalog;
  }

  @override
  Future<List<NotCompletedReason>> getReasons({bool forceRefresh = false}) {
    final cached = _reasons;
    if (cached != null && !forceRefresh) return Future.value(cached);
    return _loadingReasons ??=
        _fetchReasons().whenComplete(() => _loadingReasons = null);
  }

  Future<List<NotCompletedReason>> _fetchReasons() async {
    final response = await apiClient.get(ApiEndpoints.serviceOrderReasons);
    return _reasons = ServiceOrderModel.reasons(response)
        .where((reason) => reason.isForTechnician)
        .toList();
  }

  @override
  Future<PagedServiceOrders> listOrders({
    ServiceOrderStatus? status,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.serviceOrdersPaged(page, limit),
      query: {if (status != null) 'estatus': status.key},
    );
    final result = ServiceOrderModel.page(response, page: page, limit: limit);
    if (kDebugMode) {
      debugPrint('[API] Órdenes ${status?.key ?? 'todas'} página '
          '${result.page}: ${result.items.length} de ${result.total}');
    }
    return result;
  }

  @override
  Future<ServiceOrderRecord> getOrder(String orderId) async {
    final response = await apiClient.get(ApiEndpoints.serviceOrder(orderId));
    final order = ServiceOrderModel.detail(response);
    if (order == null) {
      throw const ServerFailure(
        'No se encontró la orden de servicio.',
        statusCode: 404,
      );
    }
    return order;
  }

  @override
  Future<ServiceOrderRef> startOrder(
    String orderId, {
    required String appKey,
    ServiceType? type,
    String? installationId,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.serviceOrderStart(orderId),
      body: {
        'claveApp': appKey,
        if (type != null) 'tipoServicio': type.key,
        if (installationId != null)
          'idInstalacion': int.tryParse(installationId) ?? installationId,
      },
    );
    return ServiceOrderModel.ref(response) ??
        ServiceOrderRef(id: orderId, folio: orderId);
  }

  @override
  Future<void> updateOrder(String orderId, ServiceOrderUpdate update) async {
    final body = update.toJson();
    if (body.isEmpty) return;
    await apiClient.patch(ApiEndpoints.serviceOrder(orderId), body: body);
  }

  @override
  Future<void> uploadFile(
    String orderId,
    String key,
    Uint8List bytes, {
    required String label,
  }) async {
    final image = await prepareUploadImage(bytes, label: label);
    await apiClient.multipart(
      'POST',
      ApiEndpoints.serviceOrderFile(orderId, key),
      files: [
        ApiFile(
          field: 'file',
          bytes: image.bytes,
          filename: image.filename(key),
          contentType: image.type.mimeType,
        ),
      ],
    );
  }

  @override
  Future<void> requestAuthorization(
    String orderId, {
    required String observations,
    bool thirdParty = false,
  }) async {
    await apiClient.post(
      ApiEndpoints.serviceOrderAuthorization(orderId),
      body: {
        'observaciones': observations.trim(),
        // Solo en el reporte manual: la solicitud normal no cambia.
        if (thirdParty) 'equipoTercero': true,
      },
    );
  }

  @override
  Future<VerificationCodeRequest> requestCode(String orderId) async {
    final response =
        await apiClient.post(ApiEndpoints.serviceOrderCode(orderId));
    final layers = JsonReader.layers(response);
    return VerificationCodeRequest(
      message: JsonReader.string(layers, const ['message']),
      expiresAt: MexicoCityTime.parseApi(
        JsonReader.string(layers, const ['expira']),
      ),
    );
  }

  @override
  Future<void> validateCode(String orderId, String code) async {
    await apiClient.post(
      ApiEndpoints.serviceOrderCodeValidate(orderId),
      body: {'codigo': code.trim()},
    );
  }

  @override
  Future<void> requestTest(
    String orderId,
    String key, {
    String? observations,
  }) async {
    final note = observations?.trim() ?? '';
    await apiClient.post(
      ApiEndpoints.serviceOrderTestRequest(orderId, key),
      body: note.isEmpty ? null : {'observaciones': note},
    );
  }

  @override
  Future<ServiceOrderCloseResult> closeOrder(String orderId) async {
    try {
      final response =
          await apiClient.post(ApiEndpoints.serviceOrderClose(orderId));
      final layers = JsonReader.layers(response);
      return ServiceOrderCloseResult(
        id: JsonReader.string(layers, const ['id']) ?? orderId,
        folio: JsonReader.string(layers, const ['nombre', 'folio']) ?? orderId,
        resultingInstallationId:
            JsonReader.string(layers, const ['idInstalacionResultado']),
      );
    } on ServerFailure catch (e) {
      final missing = ServiceOrderModel.missingFields(e.data);
      if (e.statusCode == 400 && missing.isNotEmpty) {
        throw IncompleteOrderFailure(e.message, missing);
      }
      rethrow;
    }
  }

  @override
  Future<void> markNotCompleted(
    String orderId, {
    required String reasonKey,
    String? observations,
  }) async {
    final note = observations?.trim() ?? '';
    await apiClient.post(
      ApiEndpoints.serviceOrderNotCompleted(orderId),
      body: {
        'claveMotivo': reasonKey,
        if (note.isNotEmpty) 'observaciones': note,
      },
    );
  }

  @override
  Future<Uint8List> downloadPdf(String orderId) => apiClient.getBytes(
        ApiEndpoints.serviceOrderPdf(orderId),
        accept: 'application/pdf',
      );

  @override
  Future<ServiceOrderShareLink> shareOrder(
    String orderId, {
    String? phone,
  }) async {
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    final response = await apiClient.post(
      ApiEndpoints.serviceOrderShare(orderId),
      body: digits.isEmpty ? null : {'telefono': digits},
    );
    final link = ServiceOrderModel.shareLink(response);
    if (link == null) {
      throw const ServerFailure('El servidor no devolvió el enlace del PDF.');
    }
    return link;
  }

  @override
  Future<String?> sendByEmail(String orderId, List<String> emails) async {
    final response = await apiClient.post(
      ApiEndpoints.serviceOrderEmail(orderId),
      body: {'correos': emails.map((email) => email.trim()).toList()},
    );
    return JsonReader.string(JsonReader.layers(response), const ['message']);
  }

  @override
  Future<CurrentInstallation?> getInstallation(String installationId) async {
    final response =
        await apiClient.get(ApiEndpoints.installation(installationId));
    final list = JsonReader.list(response);
    final row = list.isNotEmpty && list.first is Map
        ? Map<String, dynamic>.from(list.first as Map)
        : JsonReader.layers(response).lastOrNull;
    return row == null ? null : ServiceOrderModel.installation(row);
  }

  /// Solo acepta una fila que sea del vehículo pedido y esté vigente.
  @override
  Future<CurrentInstallation?> findCurrentInstallation({
    required String productId,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.installationsPaged,
      body: {
        'page': 1,
        'limit': 50,
        'idProducto': int.tryParse(productId) ?? productId,
        'estatusInstalacion': 1,
      },
    );
    for (final raw in JsonReader.list(response).whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final installation = ServiceOrderModel.installation(row);
      final status = int.tryParse(
        JsonReader.string([row], const ['estatusInstalacion', 'estatus']) ?? '',
      );
      if (installation?.productId == productId && status == 1) {
        return installation;
      }
    }
    return null;
  }

  @override
  void clearCache() {
    _catalog = null;
    _reasons = null;
  }
}
