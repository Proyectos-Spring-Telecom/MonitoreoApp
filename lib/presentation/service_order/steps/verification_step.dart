import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../orders/order_models.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_fields.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// Mantenimientos: el operador en turno dicta por teléfono un código de 6
/// dígitos que confirma que el técnico está en el vehículo correcto (§8).
class VerificationStep extends StatefulWidget {
  const VerificationStep({super.key});

  @override
  State<VerificationStep> createState() => _VerificationStepState();
}

class _VerificationStepState extends State<VerificationStep> {
  final _codeController = TextEditingController();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _code => _codeController.text.trim();

  Future<void> _requestCode() async {
    final controller = context.read<ServiceOrderFlowController>();
    await runOrderAction(
      context,
      controller.requestCode,
      success: 'Código solicitado. Operación te lo dictará por teléfono.',
    );
  }

  Future<void> _validate() async {
    if (_code.length != 6) {
      setState(() => _showErrors = true);
      return;
    }
    final controller = context.read<ServiceOrderFlowController>();
    try {
      await controller.validateCode(_code);
      if (mounted) {
        showServiceOrderMessage(context, 'Vehículo confirmado.');
      }
    } on Failure catch (e) {
      if (!mounted || controller.isGone) return;
      // 409: el operador dictó un código viejo; hay que capturar el nuevo.
      if (e.isConflict) _codeController.clear();
      showServiceOrderMessage(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;
    final validated = order.codeValidated;
    final request = controller.codeRequest;
    final exhausted = controller.codesExhausted;

    return ServiceOrderFormBody(
      action: ServiceOrderBottomButton(
        label: 'Siguiente',
        isLoading: controller.isBusy,
        onPressed: validated ? controller.next : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderStepNotice(
            icon: Icons.phonelink_lock_outlined,
            title: 'Confirma el vehículo',
            message: 'Vehículo: ${order.vehicleLabel ?? '—'}. Sin código '
                'validado la orden no se puede cerrar.',
          ),
          const SizedBox(height: 16),
          if (validated)
            const FlowNoticeCard(
              icon: Icons.verified_outlined,
              color: ServiceOrderColors.success,
              title: 'Vehículo confirmado',
              message: 'El código se validó. Continúa con la instalación.',
            )
          else ...[
            if (exhausted)
              const FlowNoticeCard(
                icon: Icons.block,
                color: AppColors.error,
                title: 'Se agotaron los códigos',
                message: ServiceOrderFlowController.codesExhaustedMessage,
              )
            else
              ServiceOrderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ServiceOrderSectionHeader(
                      icon: Icons.sms_outlined,
                      title: 'Solicitar código',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request == null
                          ? 'El código no llega a la App: lo ve el operador '
                              'en turno y te lo dicta por teléfono. Vence a '
                              'los 15 minutos.'
                          : request.expiresAt == null
                              ? 'Código solicitado. Pídelo al operador en '
                                  'turno.'
                              : 'Código solicitado. Vence a las '
                                  '${orderTime(request.expiresAt!)}.',
                      style: const TextStyle(
                        color: ServiceOrderColors.mutedText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: controller.isBusy ? null : _requestCode,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side:
                            const BorderSide(color: ServiceOrderColors.accent),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.send_to_mobile_outlined),
                      label: Text(
                        request == null
                            ? 'Solicitar código'
                            : 'Solicitar otro código',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ServiceOrderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ServiceOrderSectionHeader(
                    icon: Icons.pin_outlined,
                    title: 'Validar código',
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  ServiceOrderCodeField(
                    label: 'Código de 6 dígitos',
                    controller: _codeController,
                    isRequired: true,
                    enabled: !controller.isBusy,
                    errorText: _showErrors && _code.length != 6
                        ? 'El código tiene 6 dígitos'
                        : null,
                  ),
                  ElevatedButton(
                    onPressed: controller.isBusy ? null : _validate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Validar código'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
