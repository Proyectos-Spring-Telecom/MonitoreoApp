import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_message.dart';
import '../../data/datasources/local/order_key_storage.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/service_order_record.dart';
import '../../domain/repositories/service_order_repository.dart';
import 'service_order_flow_controller.dart';
import 'steps/checklist_step.dart';
import 'steps/finished_view.dart';
import 'steps/flow_action.dart';
import 'steps/installation_step.dart';
import 'steps/start_view.dart';
import 'steps/summary_step.dart';
import 'steps/tests_step.dart';
import 'steps/vehicle_step.dart';
import 'steps/verification_step.dart';
import 'widgets/not_completed_sheet.dart';
import 'widgets/service_order_stepper.dart';
import 'widgets/service_order_ui.dart';

/// Una orden de la agenda, de principio a fin. Recibe como argumento la
/// [ServiceOrderRecord] de la agenda o su id.
class ServiceOrderFlowPage extends StatelessWidget {
  /// Ubicación del teléfono; las pruebas la reemplazan.
  final LocationReader? readLocation;

  const ServiceOrderFlowPage({super.key, this.readLocation});

  @override
  Widget build(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    final initial = argument is ServiceOrderRecord ? argument : null;
    final orderId = initial?.id ?? (argument is String ? argument : null);
    if (orderId == null) {
      return const _MissingOrder();
    }
    return ChangeNotifierProvider(
      create: (context) => ServiceOrderFlowController(
        repository: context.read<ServiceOrderRepository>(),
        keyStorage: context.read<OrderKeyStorage>(),
        orderId: orderId,
        initial: initial,
        readLocation: readLocation,
      )..load(),
      child: const _ServiceOrderFlowView(),
    );
  }
}

class _ServiceOrderFlowView extends StatefulWidget {
  const _ServiceOrderFlowView();

  @override
  State<_ServiceOrderFlowView> createState() => _ServiceOrderFlowViewState();
}

class _ServiceOrderFlowViewState extends State<_ServiceOrderFlowView> {
  late final ServiceOrderFlowController _controller;
  late final AppLifecycleListener _lifecycle;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ServiceOrderFlowController>();
    _controller.addListener(_onControllerChanged);
    // Al volver del portal, de WhatsApp o de otra pestaña la orden se
    // actualiza sin esperar a la siguiente consulta.
    _lifecycle = AppLifecycleListener(
      onHide: _controller.pause,
      onShow: _controller.resume,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// 404: la orden ya no existe o se reasignó; se quita de la vista (§13).
  void _onControllerChanged() {
    if (!_controller.isGone || _leaving || !mounted) return;
    _leaving = true;
    AppMessage.error(
      context,
      'Esta orden ya no está asignada a ti. Se actualizará tu agenda.',
    );
    // `pop` no consulta el PopScope de los pasos.
    Navigator.of(context).pop(true);
  }

  bool get _inSteps => _controller.status == ServiceOrderStatus.borrador;

  void _handleBack() {
    if (_inSteps && _controller.back()) return;
    Navigator.of(context).maybePop(true);
  }

  Future<void> _markNotCompleted() async {
    final repository = context.read<ServiceOrderRepository>();
    List<NotCompletedReason> reasons;
    try {
      reasons = await repository.getReasons();
    } catch (_) {
      if (mounted) {
        AppMessage.error(context, 'No se pudieron cargar los motivos.');
      }
      return;
    }
    if (!mounted) return;
    final choice = await showNotCompletedSheet(context, reasons);
    if (choice == null || !mounted) return;
    await runOrderAction(
      context,
      () => _controller.markNotCompleted(
        reasonKey: choice.reasonKey,
        observations: choice.observations,
      ),
      success: 'La orden quedó como no cumplida.',
    );
  }

  Future<void> _refresh() => runOrderAction(context, _controller.refresh);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order;
    final status = order?.status;
    final step = _inSteps ? controller.currentStep : null;
    final canMarkNotCompleted = status == ServiceOrderStatus.programada ||
        status == ServiceOrderStatus.borrador;

    return PopScope(
      canPop: !(_inSteps && controller.stepIndex > 0),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Regresar',
            onPressed: _handleBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(step, order),
                style: const TextStyle(color: Colors.white, fontSize: 19),
              ),
              if (order != null)
                Text(
                  order.folio,
                  style: const TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: ServiceOrderColors.card,
              enabled: !controller.isBusy,
              onSelected: (value) {
                if (value == 'refresh') _refresh();
                if (value == 'not_completed') _markNotCompleted();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Text(
                    'Actualizar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (canMarkNotCompleted)
                  const PopupMenuItem(
                    value: 'not_completed',
                    child: Text(
                      'No se pudo realizar',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: _buildBody(controller),
      ),
    );
  }

  String _title(ServiceOrderStep? step, ServiceOrderRecord? order) {
    if (step == ServiceOrderStep.installation &&
        (order?.type?.isMaintenance ?? false)) {
      return 'Edición de la instalación';
    }
    if (step != null) return step.title;
    return order?.status == ServiceOrderStatus.programada
        ? 'Iniciar servicio'
        : 'Orden de servicio';
  }

  Widget _buildBody(ServiceOrderFlowController controller) {
    final order = controller.order;
    if (order == null || (controller.isLoading && order.status == null)) {
      if (controller.loadError != null && !controller.isLoading) {
        return _LoadError(
          message: controller.loadError!,
          onRetry: controller.load,
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: ServiceOrderColors.accent),
      );
    }
    if (controller.catalog == null) {
      if (controller.loadError != null && !controller.isLoading) {
        return _LoadError(
          message: controller.loadError!,
          onRetry: controller.load,
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: ServiceOrderColors.accent),
      );
    }

    return switch (order.status) {
      ServiceOrderStatus.programada => OrderStartView(
          onNotCompleted: _markNotCompleted,
        ),
      ServiceOrderStatus.borrador => _buildSteps(controller),
      _ => const OrderFinishedView(),
    };
  }

  Widget _buildSteps(ServiceOrderFlowController controller) {
    final steps = controller.steps;
    final current = controller.currentStep;
    if (current == null) {
      return const _LoadError(
        message: 'La orden no indica el tipo de servicio.',
      );
    }
    final index = controller.stepIndex;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ServiceOrderStepper(
            steps: [for (final step in steps) step.label],
            currentStep: index,
            completedSteps: {for (var i = 0; i < index; i++) i},
            onStepTapped: (i) => controller.goTo(steps[i]),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(current),
            child: switch (current) {
              ServiceOrderStep.vehicle => const VehicleStep(),
              ServiceOrderStep.verification => const VerificationStep(),
              ServiceOrderStep.installation => const InstallationStep(),
              ServiceOrderStep.checklist => const ChecklistStep(),
              ServiceOrderStep.tests => const TestsStep(),
              ServiceOrderStep.summary => const SummaryStep(),
            },
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _LoadError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 16,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
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
}

class _MissingOrder extends StatelessWidget {
  const _MissingOrder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        leading: const ServiceOrderBackButton(
          fallbackRoute: AppConstants.homeRoute,
          fallbackArguments: 1,
        ),
      ),
      body: const _LoadError(message: 'No se indicó la orden de servicio.'),
    );
  }
}
