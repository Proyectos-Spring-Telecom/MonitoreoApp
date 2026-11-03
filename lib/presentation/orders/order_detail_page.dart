import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/mexico_time.dart';
import '../../core/widgets/app_message.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../controllers/auth_controller.dart';
import '../service_order/widgets/service_order_ui.dart';
import 'order_models.dart';
import 'widgets/order_record_sections.dart';
import 'widgets/order_share_sheet.dart';

/// Recibe como argumento la [ServiceOrderRecord] del listado o su id.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  String? _orderId;
  String? _folio;
  ServiceOrderRecord? _order;
  DateTime? _loadedAt;
  OrderNames _names = const OrderNames();
  bool _isLoading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is ServiceOrderRecord) {
      _orderId = argument.id;
      _folio = argument.folio;
    } else if (argument is String) {
      _orderId = argument;
    }
    if (_orderId == null) {
      _isLoading = false;
      return;
    }
    _loadNames();
    _load();
  }

  Future<void> _loadNames() async {
    final names = await OrderNames.load(
      orders: context.read<ServiceOrderRepository>(),
      user: context.read<AuthController>().user,
    );
    if (mounted) setState(() => _names = names);
  }

  Future<void> _load() async {
    final id = _orderId;
    if (id == null) return;
    if (_error != null) {
      setState(() {
        _isLoading = _order == null;
        _error = null;
      });
    }
    try {
      final order = await context.read<ServiceOrderRepository>().getOrder(id);
      if (mounted) {
        setState(() {
          _order = order;
          _loadedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is Failure
          ? e.message
          : 'No se pudo cargar la orden. Intenta de nuevo.';
      // 404: ya no existe o se reasignó a otro técnico (§13).
      if (e is Failure && e.isNotFound) {
        setState(() => _order = null);
      }
      if (_order == null) {
        setState(() => _error = message);
      } else {
        AppMessage.error(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final canShare = order?.status?.canShare ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        leading: const ServiceOrderBackButton(
          fallbackRoute: AppConstants.completedOrdersRoute,
        ),
        title: Text(
          order?.folio ?? _folio ?? 'Detalle de la orden',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          if (order != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Ver PDF',
              onPressed: () => openOrderPdf(context, order),
            ),
          if (order != null && canShare)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir PDF',
              onPressed: () => showOrderShareSheet(context, order),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(order),
    );
  }

  Widget _buildBody(ServiceOrderRecord? order) {
    if (_isLoading && order == null) {
      return const Center(
        child: CircularProgressIndicator(color: ServiceOrderColors.accent),
      );
    }
    if (order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: ServiceOrderColors.hintText,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'No se encontró la orden',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ServiceOrderColors.mutedText,
                  fontSize: 16,
                ),
              ),
              if (_orderId != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _load,
                  style: TextButton.styleFrom(
                    foregroundColor: ServiceOrderColors.accent,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final isActive = order.status == ServiceOrderStatus.programada ||
        order.status == ServiceOrderStatus.borrador;

    return RefreshIndicator(
      color: ServiceOrderColors.accent,
      backgroundColor: ServiceOrderColors.card,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          OrderStatusBanner(order),
          if (isActive) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(
                AppConstants.serviceOrderRoute,
                arguments: order,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                order.status == ServiceOrderStatus.programada
                    ? 'Abrir orden'
                    : 'Continuar orden',
              ),
            ),
          ],
          if (order.missingToClose.isNotEmpty) ...[
            const SizedBox(height: 16),
            OrderMissingCard(order.missingToClose),
          ],
          const SizedBox(height: 16),
          OrderRecordSections(order: order, names: _names),
          _OrderFooter(
            folio: order.folio,
            loadedAt: _loadedAt ?? DateTime.now(),
          ),
        ],
      ),
    );
  }
}

class _OrderFooter extends StatelessWidget {
  final String folio;
  final DateTime loadedAt;

  const _OrderFooter({required this.folio, required this.loadedAt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Column(
        children: [
          const Divider(height: 1, color: ServiceOrderColors.divider),
          const SizedBox(height: 20),
          Opacity(
            opacity: 0.85,
            child: Image.asset(
              'assets/images/logos/logo_horizontal.webp',
              height: 26,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Spring Telecom',
                style: TextStyle(
                  color: ServiceOrderColors.mutedText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Orden de servicio $folio',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Consultada el ${orderDateTime(loadedAt)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ServiceOrderColors.hintText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© ${MexicoCityTime.from(loadedAt).year} Spring Telecom · '
            'Monitoreo',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ServiceOrderColors.hintText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
