import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failures.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_ui.dart';

/// Ejecuta una acción del flujo y muestra el error. Un 404 lo atiende la
/// página (regresa a la agenda); un 409 ya recargó la orden. Devuelve `true`
/// si terminó bien.
Future<bool> runOrderAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final controller = context.read<ServiceOrderFlowController>();
  try {
    await action();
    if (success != null && context.mounted) {
      showServiceOrderMessage(context, success);
    }
    return true;
  } on Failure catch (e) {
    if (context.mounted && !controller.isGone) {
      showServiceOrderMessage(context, e.message, isError: true);
    }
  } catch (_) {
    if (context.mounted) {
      showServiceOrderMessage(
        context,
        'No se pudo completar la acción. Intenta de nuevo.',
        isError: true,
      );
    }
  }
  return false;
}

/// Tarjeta de aviso con ícono y color (éxito, espera, advertencia o error).
class FlowNoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? trailing;
  final List<Widget> children;

  const FlowNoticeCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.trailing,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: ServiceOrderColors.mutedText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
