import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/service_order.dart';
import '../../controllers/auth_controller.dart';
import '../../orders/order_models.dart';
import '../../orders/widgets/order_record_sections.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// Resumen con lo que devuelve el servidor. "Registrar" solo se habilita con
/// `faltantesParaCerrar` vacío (§10).
class SummaryStep extends StatefulWidget {
  const SummaryStep({super.key});

  @override
  State<SummaryStep> createState() => _SummaryStepState();
}

class _SummaryStepState extends State<SummaryStep> {
  bool _refreshing = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await runOrderAction(
      context,
      context.read<ServiceOrderFlowController>().refresh,
    );
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _confirmClose() async {
    final controller = context.read<ServiceOrderFlowController>();
    final folio = controller.order?.folio ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ServiceOrderColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Registrar orden',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          '¿Registrar la orden $folio? Después ya no se podrá modificar.',
          style: const TextStyle(
            color: ServiceOrderColors.mutedText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Revisar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: ServiceOrderColors.accent,
            ),
            child: const Text('Sí, registrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _close(controller);
  }

  Future<void> _close(ServiceOrderFlowController controller) async {
    try {
      final result = await controller.close();
      if (!mounted) return;
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: '¡Orden registrada!',
        text: 'La orden ${result.folio} se cerró correctamente.',
        confirmBtnText: 'Aceptar',
        confirmBtnColor: AppColors.primaryBlue,
        backgroundColor: ServiceOrderColors.card,
        titleColor: Colors.white,
        textColor: Colors.white,
      );
    } on IncompleteOrderFailure catch (e) {
      if (mounted) await _showMissing(e.missing);
    } on Failure catch (e) {
      if (mounted && !controller.isGone) {
        showServiceOrderMessage(context, e.message, isError: true);
      }
    }
  }

  Future<void> _showMissing(List<String> missing) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ServiceOrderColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'La orden está incompleta',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: OrderMissingCard(missing),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: ServiceOrderColors.accent,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;
    final names = OrderNames.from(
      controller.catalog,
      context.watch<AuthController>().user,
    );
    final missing = order.missingToClose;
    final canClose = !_refreshing && missing.isEmpty;
    final isInstallation = order.type == ServiceType.instalacion;

    return RefreshIndicator(
      color: ServiceOrderColors.accent,
      backgroundColor: ServiceOrderColors.card,
      onRefresh: _refresh,
      child: ServiceOrderFormBody(
        action: ServiceOrderBottomButton(
          label: controller.isBusy ? 'Registrando...' : 'Registrar orden',
          icon: Icons.check_circle_outline,
          isLoading: controller.isBusy,
          onPressed: canClose ? _confirmClose : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  color: ServiceOrderColors.accent,
                  backgroundColor: ServiceOrderColors.field,
                ),
              ),
            if (missing.isEmpty)
              const FlowNoticeCard(
                icon: Icons.verified_outlined,
                color: ServiceOrderColors.success,
                title: 'Lista para registrar',
                message: 'Revisa la información. Al registrarla ya no podrás '
                    'modificarla; usa "Editar" en cada sección para corregir.',
              )
            else
              OrderMissingCard(missing),
            const SizedBox(height: 16),
            OrderRecordSections(
              order: order,
              names: names,
              onEditVehicle: isInstallation && !order.vehicleLocked
                  ? () => controller.goTo(ServiceOrderStep.vehicle)
                  : null,
              onEditInstallation: () =>
                  controller.goTo(ServiceOrderStep.installation),
              onEditChecklist: () =>
                  controller.goTo(ServiceOrderStep.checklist),
              onEditTests: () => controller.goTo(ServiceOrderStep.tests),
            ),
          ],
        ),
      ),
    );
  }
}
