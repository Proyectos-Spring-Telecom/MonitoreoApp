import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../orders/widgets/order_record_sections.dart';
import '../../orders/widgets/order_share_sheet.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_ui.dart';

/// Orden cerrada, no cumplida o cancelada: ya no se edita. Desde aquí se ve
/// el PDF, se comparte o se regresa a la agenda.
class OrderFinishedView extends StatelessWidget {
  const OrderFinishedView({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.watch<ServiceOrderFlowController>().order!;
    final canShare = order.status?.canShare ?? false;
    final rejected = order.authorization == AuthorizationStatus.rechazada;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        OrderStatusBanner(order),
        if (rejected) ...[
          const SizedBox(height: 12),
          const Text(
            'Operación rechazó la desinstalación del equipo encontrado, así '
            'que la orden quedó como no cumplida.',
            style: TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (canShare) ...[
          ElevatedButton.icon(
            onPressed: () => showOrderShareSheet(context, order),
            style: _primary,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartir PDF'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () => openOrderPdf(context, order),
          style: _secondary,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Ver PDF'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushReplacementNamed(
            AppConstants.orderDetailRoute,
            arguments: order,
          ),
          style: _secondary,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Ver detalle'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ServiceOrderColors.accent,
            minimumSize: const Size.fromHeight(46),
          ),
          child: const Text('Volver a la agenda'),
        ),
      ],
    );
  }

  static final ButtonStyle _primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  static final ButtonStyle _secondary = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: const BorderSide(color: ServiceOrderColors.divider),
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
