import 'package:flutter/material.dart';
import '../../core/utils/mexico_time.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../service_order/widgets/service_order_icons.dart';
import '../service_order/widgets/service_order_ui.dart';

const List<String> orderMonths = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Las fechas del API son hora de pared de la Ciudad de México y se muestran
/// tal cual.
String orderTime(DateTime date) {
  final local = MexicoCityTime.from(date);
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String orderDate(DateTime date) => orderCalendarDate(MexicoCityTime.from(date));

/// Formatea un día ya calendario (p. ej. el del selector de fecha).
String orderCalendarDate(DateTime day) =>
    '${day.day} ${orderMonths[day.month - 1]}, ${day.year}';

String orderDateTime(DateTime? date) =>
    date == null ? '—' : '${orderDate(date)} · ${orderTime(date)}';

/// "30 Oct, 2026 · 10:00 – 12:00".
String orderAppointment(ServiceOrderRecord order) {
  final start = order.appointment;
  if (start == null) return '—';
  final end = order.appointmentEnd;
  return end == null
      ? orderDateTime(start)
      : '${orderDateTime(start)} – ${orderTime(end)}';
}

/// Día calendario (Ciudad de México) de una fecha de la orden.
DateTime orderDay(DateTime date) {
  final local = MexicoCityTime.from(date);
  return DateTime(local.year, local.month, local.day);
}

/// Color de cada tipo de servicio. Es el mismo en la agenda, el calendario,
/// "En curso" y el historial.
Color serviceTypeColor(ServiceType? type) => switch (type) {
      ServiceType.instalacion => ServiceOrderColors.accent,
      ServiceType.revision => ServiceOrderColors.warning,
      ServiceType.cSim || ServiceType.cEquipo => ServiceOrderColors.violet,
      ServiceType.desinstalacion => const Color(0xFFF26D6D),
      null => ServiceOrderColors.hintText,
    };

/// Color del tipo que muestra [orderTypeLabel].
Color orderTypeColor(ServiceOrderRecord order) => serviceTypeColor(order.type);

IconData orderTypeIcon(ServiceOrderRecord order) {
  final type = order.type;
  return type == null
      ? Icons.assignment_outlined
      : ServiceOrderIcons.serviceType(type);
}

String orderTypeLabel(ServiceOrderRecord order) =>
    order.type?.label ??
    (order.typeKey.isEmpty ? '—' : humanizeKey(order.typeKey));

/// "Cambio de equipo (programada: Revisión)" cuando el técnico cambió el tipo.
String orderTypeWithScheduled(ServiceOrderRecord order) {
  final scheduled = order.scheduledType;
  final actual = ServiceType.fromKey(order.typeKey);
  if (scheduled == null || actual == null || scheduled == actual) {
    return orderTypeLabel(order);
  }
  return '${actual.label} (programada: ${scheduled.label})';
}

extension ServiceOrderStatusStyle on ServiceOrderStatus {
  Color get color => switch (this) {
        ServiceOrderStatus.programada => ServiceOrderColors.accent,
        ServiceOrderStatus.borrador => ServiceOrderColors.accent,
        ServiceOrderStatus.cerrada => ServiceOrderColors.success,
        ServiceOrderStatus.noCumplida => const Color(0xFFF26D6D),
        ServiceOrderStatus.cancelada => ServiceOrderColors.hintText,
      };

  IconData get icon => switch (this) {
        ServiceOrderStatus.programada => Icons.event_outlined,
        ServiceOrderStatus.borrador => Icons.edit_note,
        ServiceOrderStatus.cerrada => Icons.check_circle_outline,
        ServiceOrderStatus.noCumplida => Icons.event_busy_outlined,
        ServiceOrderStatus.cancelada => Icons.cancel_outlined,
      };
}

/// Respuesta de una opción con el nombre del catálogo.
class OrderAnswerView {
  final String key;
  final String name;
  final bool value;

  const OrderAnswerView(this.key, this.name, this.value);
}

/// Nombres para mostrar una orden: el API devuelve IDs de monitorista y
/// técnico, que se resuelven con el catálogo y el usuario de la sesión.
class OrderNames {
  final Map<String, String> monitors;
  final ServiceOrderCatalog? catalog;
  final User? user;

  const OrderNames({this.monitors = const {}, this.catalog, this.user});

  factory OrderNames.from(ServiceOrderCatalog? catalog, User? user) =>
      OrderNames(
        monitors: {
          for (final monitor in catalog?.monitors ?? const [])
            monitor.id: monitor.name,
        },
        catalog: catalog,
        user: user,
      );

  /// Si el catálogo falla se muestran los IDs.
  static Future<OrderNames> load({
    required ServiceOrderRepository orders,
    User? user,
  }) async {
    try {
      return OrderNames.from(await orders.getCatalog(), user);
    } catch (_) {
      return OrderNames(user: user);
    }
  }

  String client(ServiceOrderRecord order) =>
      order.clientName ??
      (order.clientId == null ? '—' : 'Cliente #${order.clientId}');

  String monitor(String? id) =>
      id == null ? '—' : monitors[id] ?? 'Monitorista #$id';

  bool _isCurrentUser(String? id) =>
      id != null && user != null && user!.id == id;

  /// El API solo devuelve órdenes del técnico del token.
  String technician(String? id) {
    final name = user?.name.trim() ?? '';
    if (id == null || _isCurrentUser(id)) return name.isEmpty ? '—' : name;
    return 'Técnico #$id';
  }

  String? technicianEmail(String? id) =>
      id == null || _isCurrentUser(id) ? user?.email : null;

  String option(String section, String key) =>
      catalog?.nameOf(section, key) ?? humanizeKey(key);

  /// Respuestas de [section] en el orden del catálogo; las claves que no
  /// están en el catálogo van al final.
  List<OrderAnswerView> answers(ServiceOrderRecord order, String section) {
    final byKey = {
      for (final answer in order.answersOf(section)) answer.key: answer.value,
    };
    final ordered = <OrderAnswerView>[];
    for (final option
        in catalog?.section(section) ?? const <ServiceOrderOption>[]) {
      final value = byKey.remove(option.key);
      if (value != null) {
        ordered.add(OrderAnswerView(option.key, option.name, value));
      }
    }
    byKey.forEach((key, value) {
      ordered.add(OrderAnswerView(key, humanizeKey(key), value));
    });
    return ordered;
  }
}
