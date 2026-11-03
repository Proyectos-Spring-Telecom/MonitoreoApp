import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/widgets/app_message.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../controllers/auth_controller.dart';
import '../home/drawer/app_drawer.dart';
import '../service_order/widgets/service_order_ui.dart';
import 'order_models.dart';

class CompletedOrdersPage extends StatefulWidget {
  /// Dentro de las pestañas de inicio la barra superior la pone [HomePage].
  final bool showAppBar;

  const CompletedOrdersPage({super.key, this.showAppBar = true});

  @override
  State<CompletedOrdersPage> createState() => _CompletedOrdersPageState();
}

class _CompletedOrdersPageState extends State<CompletedOrdersPage> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ServiceOrderRepository _repository;

  List<ServiceOrderRecord> _orders = const [];
  OrderNames _names = const OrderNames();
  int _page = 0;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  DateTime? _selectedDate;

  /// Historial: órdenes cerradas o no cumplidas, más recientes primero.
  ServiceOrderStatus _status = ServiceOrderStatus.cerrada;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ServiceOrderRepository>();
    _searchController.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    _loadNames();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNames() async {
    final names = await OrderNames.load(
      orders: _repository,
      user: context.read<AuthController>().user,
    );
    if (mounted) setState(() => _names = names);
  }

  Future<void> _refresh() async {
    if (_error != null) {
      setState(() {
        _isLoading = _orders.isEmpty;
        _error = null;
      });
    }
    try {
      final result =
          await _repository.listOrders(status: _status, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _orders = result.items;
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _repository.listOrders(
        status: _status,
        page: _page + 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _orders.map((order) => order.id).toSet();
      setState(() {
        _orders = [
          ..._orders,
          ...result.items.where((order) => !known.contains(order.id)),
        ];
        _page = result.page;
        _hasMore = result.hasMore && result.items.isNotEmpty;
      });
    } catch (e) {
      if (mounted) AppMessage.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();
  }

  static String _message(Object error) => error is Failure
      ? error.message
      : 'No se pudieron cargar las órdenes. Intenta de nuevo.';

  List<ServiceOrderRecord> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders.where((order) {
      final matchesQuery = query.isEmpty ||
          [
            order.folio,
            _names.client(order),
            orderTypeLabel(order),
            order.status?.label ?? '',
            order.observations ?? '',
            order.resultingInstallationId ?? order.installationId ?? '',
          ].any((value) => value.toLowerCase().contains(query));
      final date = _historyDate(order);
      final matchesDate = _selectedDate == null ||
          (date != null && orderDay(date) == _selectedDate);
      return matchesQuery && matchesDate;
    }).toList();
  }

  static DateTime? _historyDate(ServiceOrderRecord order) =>
      order.closedAt ?? order.date;

  void _changeStatus(ServiceOrderStatus status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _orders = const [];
      _isLoading = true;
    });
    _refresh();
  }

  Widget _buildStatusFilter() {
    return Row(
      children: [
        for (final status in const [
          ServiceOrderStatus.cerrada,
          ServiceOrderStatus.noCumplida,
        ]) ...[
          ChoiceChip(
            label: Text(status == ServiceOrderStatus.cerrada
                ? 'Cerradas'
                : 'No cumplidas'),
            selected: _status == status,
            onSelected: (_) => _changeStatus(status),
            labelStyle: TextStyle(
              color: _status == status
                  ? Colors.white
                  : ServiceOrderColors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: ServiceOrderColors.accentBackground,
            backgroundColor: ServiceOrderColors.card,
            side: BorderSide(
              color: _status == status
                  ? ServiceOrderColors.accent
                  : ServiceOrderColors.divider,
            ),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  String _dayLabel(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final day = orderDay(date);
    final today = orderDay(DateTime.now());
    if (day == today) return 'Hoy';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
    return orderDate(date);
  }

  Future<void> _pickDate() async {
    final today = orderDay(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: 'Filtrar por fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: ServiceOrderColors.accent,
            surface: ServiceOrderColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
        () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      drawer: widget.showAppBar ? const AppDrawer() : null,
      appBar: !widget.showAppBar
          ? null
          : AppBar(
              backgroundColor: AppColors.backgroundDark,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              automaticallyImplyLeading: false,
              centerTitle: false,
              titleSpacing: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menú',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: const Text(
                'Servicios',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _buildSearchBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _buildStatusFilter(),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(orderCalendarDate(_selectedDate!)),
                  labelStyle:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  avatar: const Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: ServiceOrderColors.mutedText,
                  ),
                  backgroundColor: ServiceOrderColors.card,
                  side: const BorderSide(color: ServiceOrderColors.divider),
                  deleteIconColor: ServiceOrderColors.mutedText,
                  onDeleted: () => setState(() => _selectedDate = null),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: ServiceOrderColors.accent),
      );
    }
    if (_error != null && _orders.isEmpty) {
      return _buildMessage(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        action: 'Reintentar',
        onAction: _refresh,
      );
    }

    final orders = _filteredOrders;
    final items = <Widget>[];
    String? currentLabel;
    for (final order in orders) {
      final label = _dayLabel(_historyDate(order));
      if (label != currentLabel) {
        currentLabel = label;
        items.add(_buildDayHeader(label, isFirst: items.isEmpty));
      }
      items.add(_buildOrderCard(order));
    }

    if (orders.isEmpty) {
      items.add(_buildMessage(
        icon: Icons.search_off,
        message: _orders.isEmpty
            ? 'Aún no hay órdenes registradas'
            : 'No se encontraron órdenes',
      ));
    }
    if (_hasMore) items.add(_buildLoadMore());

    return RefreshIndicator(
      color: ServiceOrderColors.accent,
      backgroundColor: ServiceOrderColors.card,
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: items,
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ServiceOrderColors.accent,
                ),
              )
            : TextButton(
                onPressed: _loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: ServiceOrderColors.accent,
                ),
                child: const Text('Cargar más órdenes'),
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Buscar folio, cliente o servicio...',
          hintStyle: const TextStyle(
            color: ServiceOrderColors.hintText,
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: ServiceOrderColors.mutedText,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _selectedDate == null
                  ? Icons.calendar_today_outlined
                  : Icons.event,
              color: _selectedDate == null
                  ? ServiceOrderColors.mutedText
                  : ServiceOrderColors.accent,
            ),
            tooltip: 'Filtrar por fecha',
            onPressed: _pickDate,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDayHeader(String label, {required bool isFirst}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 12 : 20, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    String? action,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ServiceOrderColors.hintText, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 16,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: ServiceOrderColors.accent,
              ),
              icon: const Icon(Icons.refresh),
              label: Text(action),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(ServiceOrderRecord order) {
    final status = order.status;
    final date = _historyDate(order);
    final installationId =
        order.resultingInstallationId ?? order.installationId;
    final observations = order.observations ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed(
            AppConstants.orderDetailRoute,
            arguments: order,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ServiceOrderColors.tile,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            orderTypeIcon(order),
                            color: ServiceOrderColors.mutedText,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _names.client(order),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                observations.isEmpty
                                    ? 'Sin observaciones'
                                    : observations,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: observations.isEmpty
                                      ? ServiceOrderColors.hintText
                                      : ServiceOrderColors.mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: ServiceOrderColors.mutedText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (status != null)
                          ServiceOrderTag(
                            label: status.label,
                            icon: status.icon,
                            color: status.color,
                          ),
                        ServiceOrderTag(
                          label: orderTypeLabel(order),
                          icon: orderTypeIcon(order),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: ServiceOrderColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ServiceOrderColors.field,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        order.folio,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time,
                      size: 15,
                      color: ServiceOrderColors.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        date == null ? '—' : orderTime(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ServiceOrderColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (installationId != null)
                      Flexible(
                        child: Text(
                          'Instalación $installationId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
