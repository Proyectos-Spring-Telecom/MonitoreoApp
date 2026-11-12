import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/widgets/app_message.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../orders/order_models.dart';
import '../service_order/widgets/service_order_summary.dart';
import '../service_order/widgets/service_order_ui.dart';
import 'agenda_calendar.dart';

/// Agenda del técnico: órdenes en curso (`borrador`) y programadas
/// (`programada`, por cita) en un calendario. El API ya filtra por el
/// técnico del token.
class AgendaPage extends StatefulWidget {
  /// Hoy, para el calendario; las pruebas lo fijan.
  final DateTime Function() now;

  const AgendaPage({super.key, this.now = DateTime.now});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  static const int _pageSize = 50;

  /// Páginas de programadas que se cargan de una vez para llenar el
  /// calendario; si hay más, aparece "Ver más".
  static const int _maxInitialPages = 10;

  late final ServiceOrderRepository _repository;
  List<ServiceOrderRecord> _inProgress = const [];
  List<ServiceOrderRecord> _scheduled = const [];
  int _scheduledPage = 1;
  bool _hasMoreScheduled = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ServiceOrderRepository>();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        _repository.listOrders(
          status: ServiceOrderStatus.borrador,
          limit: _pageSize,
        ),
        _repository.listOrders(
          status: ServiceOrderStatus.programada,
          limit: _pageSize,
        ),
      ]);
      // El calendario necesita todas las programadas, no solo la primera
      // página.
      var scheduled = results[1];
      final items = [...scheduled.items];
      final known = items.map((order) => order.id).toSet();
      while (scheduled.hasMore &&
          scheduled.items.isNotEmpty &&
          scheduled.page < _maxInitialPages) {
        scheduled = await _repository.listOrders(
          status: ServiceOrderStatus.programada,
          page: scheduled.page + 1,
          limit: _pageSize,
        );
        items.addAll(scheduled.items.where((order) => known.add(order.id)));
      }
      if (!mounted) return;
      setState(() {
        _inProgress = results[0].items;
        _scheduled = items;
        _scheduledPage = scheduled.page;
        _hasMoreScheduled = scheduled.hasMore && scheduled.items.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMoreScheduled) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _repository.listOrders(
        status: ServiceOrderStatus.programada,
        page: _scheduledPage + 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _scheduled.map((order) => order.id).toSet();
      setState(() {
        _scheduled = [
          ..._scheduled,
          ...result.items.where((order) => !known.contains(order.id)),
        ];
        _scheduledPage = result.page;
        _hasMoreScheduled = result.hasMore && result.items.isNotEmpty;
      });
    } catch (e) {
      if (mounted) AppMessage.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  static String _message(Object error) => error is Failure
      ? error.message
      : 'No se pudo cargar la agenda. Intenta de nuevo.';

  Future<void> _open(ServiceOrderRecord order) async {
    await Navigator.of(context).pushNamed(
      AppConstants.serviceOrderRoute,
      arguments: order,
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: RefreshIndicator(
        color: ServiceOrderColors.accent,
        backgroundColor: ServiceOrderColors.card,
        onRefresh: _refresh,
        child: _buildList(),
      ),
    );
  }

  /// "En curso" con sus tarjetas, separada de lo programado.
  List<Widget> _inProgressSection() => [
        if (_inProgress.isNotEmpty) ...[
          const _SectionTitle('En curso'),
          for (final order in _inProgress)
            _AgendaCard(order: order, onTap: () => _open(order)),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 16),
            child: Divider(height: 1, color: ServiceOrderColors.divider),
          ),
        ],
      ];

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: ServiceOrderColors.accent),
      );
    }
    final error = _error;
    final isEmpty = _inProgress.isEmpty && _scheduled.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (error != null)
          _Message(
            icon: Icons.cloud_off_outlined,
            text: error,
            action: TextButton.icon(
              onPressed: _refresh,
              style: TextButton.styleFrom(
                foregroundColor: ServiceOrderColors.accent,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          )
        else if (isEmpty)
          const _Message(
            icon: Icons.event_available_outlined,
            text: 'No tienes órdenes programadas. Desliza hacia abajo para '
                'actualizar.',
          ),
        // Sin programadas no hay calendario: las en curso van solas.
        if (_scheduled.isEmpty) ..._inProgressSection(),
        if (_scheduled.isNotEmpty) ...[
          // Selector Agenda | Mes arriba; debajo, las en curso (en las dos
          // vistas) y después el calendario.
          AgendaCalendar(
            orders: _scheduled,
            onOpen: _open,
            now: widget.now,
            header: _inProgressSection(),
          ),
          if (_hasMoreScheduled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _isLoadingMore ? null : _loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: ServiceOrderColors.accent,
                ),
                child: Text(_isLoadingMore ? 'Cargando...' : 'Ver más'),
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: ServiceOrderColors.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final ServiceOrderRecord order;
  final VoidCallback onTap;

  const _AgendaCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final unit = order.unitLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ServiceOrderColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      orderTypeIcon(order),
                      color: ServiceOrderColors.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        orderTypeLabel(order),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (status != null)
                      ServiceOrderTag(
                        label: status.label,
                        icon: status.icon,
                        color: status.color,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _line(Icons.event_outlined, orderAppointment(order)),
                _line(Icons.business_outlined, summaryOr(order.clientName)),
                _line(
                  Icons.directions_car_outlined,
                  summaryOr(order.vehicleLabel),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [order.folio, if (unit != null) unit].join(' · '),
                    style: const TextStyle(
                      color: ServiceOrderColors.hintText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ServiceOrderColors.mutedText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: ServiceOrderColors.mutedText,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, color: ServiceOrderColors.hintText, size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 15,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      ),
    );
  }
}
