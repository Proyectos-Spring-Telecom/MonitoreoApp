import 'package:flutter/material.dart';

import '../../domain/entities/service_order.dart';
import '../../domain/entities/service_order_record.dart';
import '../orders/order_models.dart';
import '../service_order/widgets/service_order_summary.dart';
import '../service_order/widgets/service_order_ui.dart';

/// Vista de la agenda: una lista por día o el mes completo.
enum AgendaView { agenda, month }

/// Calendario de las órdenes programadas. Al tocar una orden se llama a
/// [onOpen], que abre el mismo flujo de inicio que antes.
///
/// Los días son de la Ciudad de México ([orderDay]), como el resto de la app.
class AgendaCalendar extends StatefulWidget {
  final List<ServiceOrderRecord> orders;
  final ValueChanged<ServiceOrderRecord> onOpen;

  /// Hoy; las pruebas lo fijan.
  final DateTime Function() now;

  /// Lo que va entre el selector Agenda | Mes y el calendario (las órdenes
  /// en curso), visible en las dos vistas.
  final List<Widget> header;

  const AgendaCalendar({
    super.key,
    required this.orders,
    required this.onOpen,
    this.now = DateTime.now,
    this.header = const [],
  });

  @override
  State<AgendaCalendar> createState() => _AgendaCalendarState();
}

class _AgendaCalendarState extends State<AgendaCalendar> {
  static const List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  static const List<String> _weekdays = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];
  static const List<String> _weekdayInitials = [
    'L',
    'M',
    'X',
    'J',
    'V',
    'S',
    'D',
  ];
  static const List<String> _weekdayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  AgendaView _view = AgendaView.agenda;
  late DateTime _today;
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _today = orderDay(widget.now());
    _month = DateTime(_today.year, _today.month);
    _selectedDay = _today;
  }

  /// Órdenes por día, de la más temprana a la más tarde. Las que no tienen
  /// cita quedan aparte en [_undated].
  Map<DateTime, List<ServiceOrderRecord>> get _byDay {
    final result = <DateTime, List<ServiceOrderRecord>>{};
    for (final order in widget.orders) {
      final start = order.appointment;
      if (start == null) continue;
      result.putIfAbsent(orderDay(start), () => []).add(order);
    }
    for (final list in result.values) {
      list.sort((a, b) => a.appointment!.compareTo(b.appointment!));
    }
    return result;
  }

  List<ServiceOrderRecord> get _undated =>
      widget.orders.where((order) => order.appointment == null).toList();

  String _monthLabel(DateTime month) =>
      '${_months[month.month - 1]} ${month.year}';

  void _showMonth(DateTime month) => setState(() {
        _month = DateTime(month.year, month.month);
      });

  void _goToday() => setState(() {
        _month = DateTime(_today.year, _today.month);
        _selectedDay = _today;
      });

  void _selectDay(DateTime day) => setState(() {
        _selectedDay = day;
        if (day.month != _month.month || day.year != _month.year) {
          _month = DateTime(day.year, day.month);
        }
      });

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewSwitch(
          value: _view,
          onChanged: (view) => setState(() => _view = view),
        ),
        const SizedBox(height: 16),
        ...widget.header,
        if (_view == AgendaView.agenda)
          ..._buildAgenda(byDay)
        else
          ..._buildMonth(byDay),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Agenda: un renglón por día con sus órdenes

  List<Widget> _buildAgenda(Map<DateTime, List<ServiceOrderRecord>> byDay) {
    final days = byDay.keys.toList()..sort();
    final undated = _undated;
    final children = <Widget>[];
    DateTime? lastMonth;
    for (final day in days) {
      final month = DateTime(day.year, day.month);
      if (month != lastMonth) {
        children.add(_MonthHeader(_monthLabel(month)));
        lastMonth = month;
      }
      children.add(_AgendaDayRow(
        weekday: _weekdays[day.weekday - 1],
        day: day.day,
        isToday: day == _today,
        isPast: day.isBefore(_today),
        orders: byDay[day]!,
        onOpen: widget.onOpen,
      ));
    }
    if (undated.isNotEmpty) {
      children
        ..add(const _MonthHeader('Sin fecha'))
        ..addAll([
          for (final order in undated)
            AgendaEventTile(order: order, onTap: () => widget.onOpen(order)),
        ]);
    }
    return children;
  }

  // ---------------------------------------------------------------------------
  // Mes: cuadrícula con las órdenes de cada día y la lista del día elegido

  List<Widget> _buildMonth(Map<DateTime, List<ServiceOrderRecord>> byDay) {
    final first = DateTime(_month.year, _month.month);
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final weeks = ((leading + daysInMonth) / 7).ceil();
    final selected = byDay[_selectedDay] ?? const <ServiceOrderRecord>[];
    final monthCount = byDay.entries
        .where((entry) =>
            entry.key.year == _month.year && entry.key.month == _month.month)
        .fold<int>(0, (sum, entry) => sum + entry.value.length);

    return [
      Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: () =>
                _showMonth(DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          Expanded(
            child: Text(
              _monthLabel(_month),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: () =>
                _showMonth(DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              monthCount == 1
                  ? '1 orden este mes'
                  : '$monthCount órdenes este mes',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 13,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _goToday,
            style: TextButton.styleFrom(
              foregroundColor: ServiceOrderColors.accent,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.today_outlined, size: 18),
            label: const Text('Hoy'),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: ServiceOrderColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ServiceOrderColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  for (final initial in _weekdayInitials)
                    Expanded(
                      child: Text(
                        initial,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ServiceOrderColors.hintText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var week = 0; week < weeks; week++)
              Row(
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: Builder(builder: (context) {
                        final day = DateTime(
                          _month.year,
                          _month.month,
                          1 - leading + week * 7 + weekday,
                        );
                        return _MonthCell(
                          day: day,
                          label: '${day.day} de '
                              '${_months[day.month - 1].toLowerCase()}',
                          inMonth: day.month == _month.month,
                          isToday: day == _today,
                          isSelected: day == _selectedDay,
                          orders: byDay[day] ?? const [],
                          onTap: () => _selectDay(day),
                        );
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text(
        '${_weekdayNames[_selectedDay.weekday - 1]} ${_selectedDay.day} de '
        '${_months[_selectedDay.month - 1].toLowerCase()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      if (selected.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Sin órdenes programadas este día.',
            style: TextStyle(color: ServiceOrderColors.mutedText, fontSize: 14),
          ),
        )
      else
        for (final order in selected)
          AgendaEventTile(order: order, onTap: () => widget.onOpen(order)),
      if (_undated.isNotEmpty) ...[
        const _MonthHeader('Sin fecha'),
        for (final order in _undated)
          AgendaEventTile(order: order, onTap: () => widget.onOpen(order)),
      ],
    ];
  }
}

/// Color de cada tipo de servicio, con los colores de la app.
Color agendaTypeColor(ServiceOrderRecord order) =>
    switch (order.scheduledType ?? order.type) {
      ServiceType.instalacion => ServiceOrderColors.accent,
      ServiceType.revision => ServiceOrderColors.success,
      ServiceType.cSim || ServiceType.cEquipo => ServiceOrderColors.warning,
      ServiceType.desinstalacion => const Color(0xFFF26D6D),
      null => ServiceOrderColors.hintText,
    };

class _ViewSwitch extends StatelessWidget {
  final AgendaView value;
  final ValueChanged<AgendaView> onChanged;

  const _ViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(AgendaView view, IconData icon, String label) {
      final selected = view == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(view),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? ServiceOrderColors.accentBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? ServiceOrderColors.accent
                        : ServiceOrderColors.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : ServiceOrderColors.mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ServiceOrderColors.divider),
      ),
      child: Row(
        children: [
          option(AgendaView.agenda, Icons.view_agenda_outlined, 'Agenda'),
          const SizedBox(width: 4),
          option(AgendaView.month, Icons.calendar_month_outlined, 'Mes'),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String title;

  const _MonthHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AgendaDayRow extends StatelessWidget {
  final String weekday;
  final int day;
  final bool isToday;
  final bool isPast;
  final List<ServiceOrderRecord> orders;
  final ValueChanged<ServiceOrderRecord> onOpen;

  const _AgendaDayRow({
    required this.weekday,
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.orders,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isToday
        ? ServiceOrderColors.accent
        : isPast
            ? ServiceOrderColors.hintText
            : ServiceOrderColors.mutedText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  weekday.toUpperCase(),
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? ServiceOrderColors.accent : null,
                    shape: BoxShape.circle,
                  ),
                  child: _Digits(
                    '$day',
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF09081C)
                          : isPast
                              ? ServiceOrderColors.hintText
                              : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final order in orders)
                  AgendaEventTile(order: order, onTap: () => onOpen(order)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque de una orden en el calendario: tipo, horario, cliente, vehículo y
/// folio, con el color de su tipo de servicio.
class AgendaEventTile extends StatelessWidget {
  final ServiceOrderRecord order;
  final VoidCallback onTap;

  const AgendaEventTile({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = agendaTypeColor(order);
    final start = order.appointment;
    final end = order.appointmentEnd;
    final time = start == null
        ? null
        : end == null
            ? orderTime(start)
            : '${orderTime(start)} – ${orderTime(end)}';
    final unit = order.unitLabel;
    final vehicle = order.vehicleLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.18),
          ServiceOrderColors.card,
        ),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(orderTypeIcon(order), color: color, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                orderTypeLabel(order),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // El horario va en su propio renglón para que en
                        // pantallas angostas no le quite espacio al tipo.
                        if (time != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    time,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          summaryOr(order.clientName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ServiceOrderColors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                        if (vehicle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              vehicle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ServiceOrderColors.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [order.folio, if (unit != null) unit].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ServiceOrderColors.hintText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
}

class _MonthCell extends StatelessWidget {
  static const int _maxChips = 2;

  final DateTime day;

  /// "28 de octubre", para lectores de pantalla.
  final String label;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<ServiceOrderRecord> orders;
  final VoidCallback onTap;

  const _MonthCell({
    required this.day,
    required this.label,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.orders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extra = orders.length - _maxChips;
    final count = orders.length;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, '
          '${count == 0 ? 'sin órdenes' : count == 1 ? '1 orden' : '$count órdenes'}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 80,
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
          decoration: BoxDecoration(
            color: isSelected
                ? ServiceOrderColors.accentBackground.withValues(alpha: 0.6)
                : null,
            border: const Border(
              top: BorderSide(color: ServiceOrderColors.divider),
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? ServiceOrderColors.accent : null,
                    shape: BoxShape.circle,
                  ),
                  child: _Digits(
                    '${day.day}',
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF09081C)
                          : inMonth
                              ? Colors.white
                              : ServiceOrderColors.hintText.withValues(
                                  alpha: 0.35,
                                ),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                for (final order in orders.take(_maxChips))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: agendaTypeColor(order),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.appointment == null
                          ? orderTypeLabel(order)
                          : orderTime(order.appointment!),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        color: Color(0xFF09081C),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (extra > 0)
                  Text(
                    '+$extra',
                    style: const TextStyle(
                      color: ServiceOrderColors.mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Número corto (día) que nunca se parte en dos renglones: si no cabe, se
/// reduce.
class _Digits extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _Digits(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}
