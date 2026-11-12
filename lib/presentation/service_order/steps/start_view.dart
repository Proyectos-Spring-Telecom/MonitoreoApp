import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../../data/datasources/remote/vehicle_remote_datasource.dart';
import '../../../data/models/vehicle_request.dart';
import '../../../domain/entities/service_order.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../../domain/repositories/service_order_repository.dart';
import '../../orders/order_models.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_fields.dart';
import '../widgets/service_order_icons.dart';
import '../widgets/service_order_summary.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// Orden programada: datos de la visita y "Iniciar servicio" (§4). En un
/// mantenimiento se confirma qué servicio se hará y en qué vehículo; un alta
/// no cambia de tipo.
class OrderStartView extends StatefulWidget {
  final VoidCallback onNotCompleted;

  const OrderStartView({super.key, required this.onNotCompleted});

  @override
  State<OrderStartView> createState() => _OrderStartViewState();
}

class _OrderStartViewState extends State<OrderStartView> {
  ServiceType? _type;

  /// Otra instalación vigente del cliente, si el técnico atiende un vehículo
  /// distinto al programado.
  String? _installationId;
  String? _installationLabel;

  @override
  void initState() {
    super.initState();
    _type = context.read<ServiceOrderFlowController>().order?.type;
  }

  Future<void> _start() async {
    final controller = context.read<ServiceOrderFlowController>();
    await runOrderAction(
      context,
      () => controller.start(type: _type, installationId: _installationId),
    );
  }

  Future<void> _pickOtherVehicle(ServiceOrderRecord order) async {
    final picked = await showDialog<CurrentInstallation>(
      context: context,
      builder: (_) => _OtherVehicleDialog(
        vehicles: context.read<VehicleRemoteDataSource>(),
        orders: context.read<ServiceOrderRepository>(),
        clientId: order.clientId,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _installationId = picked.id;
      _installationLabel = picked.productLabel ?? 'Instalación #${picked.id}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;
    final isMaintenance = order.type?.isMaintenance ?? false;

    return ServiceOrderFormBody(
      action: ServiceOrderBottomButton(
        label: controller.isBusy ? 'Iniciando...' : 'Iniciar servicio',
        icon: Icons.play_arrow_rounded,
        isLoading: controller.isBusy,
        onPressed: _start,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderStepNotice(
            icon: Icons.event_available_outlined,
            title: 'Inicia en campo',
            message: 'Al llegar con el cliente inicia el servicio. Se '
                'registran la hora y tu ubicación.',
          ),
          const SizedBox(height: 16),
          _buildVisitCard(order),
          if (isMaintenance) ...[
            const SizedBox(height: 16),
            _buildServiceCard(order),
            const SizedBox(height: 16),
            _buildVehicleCard(order),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: controller.isBusy ? null : widget.onNotCompleted,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('No se pudo realizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(ServiceOrderRecord order) {
    final unit = order.unitLabel;
    return SummaryCard(
      icon: Icons.assignment_outlined,
      title: 'Datos de la visita',
      children: [
        SummaryHeroRow(
          icon: orderTypeIcon(order),
          caption: 'Servicio programado',
          title: order.scheduledType?.label ?? orderTypeLabel(order),
          subtitle: unit,
        ),
        SummaryHeroRow(
          icon: Icons.business_outlined,
          caption: 'Cliente',
          title: summaryOr(order.clientName),
        ),
        SummaryInfoRow('Cita', orderAppointment(order)),
        SummaryInfoRow('Vehículo', summaryOr(order.vehicleLabel)),
        if (order.scheduledBy != null)
          SummaryInfoRow('Programó', order.scheduledBy!),
        if (order.crmReference != null)
          SummaryInfoRow('Referencia CRM', order.crmReference!),
        SummaryTextBlock(
            'Observaciones de operación', order.observations ?? ''),
      ],
    );
  }

  /// Solo se cambia entre mantenimientos. Revisión y cambio de equipo se
  /// deciden con "¿El dispositivo funciona?".
  Widget _buildServiceCard(ServiceOrderRecord order) {
    final selected = _type;
    final deviceQuestion =
        selected == ServiceType.revision || selected == ServiceType.cEquipo;

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.build_circle_outlined,
            title: 'Servicio a realizar',
            isRequired: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirma el servicio. Solo puedes cambiarlo entre mantenimientos; '
            'un alta la programa operación.',
            style: TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final type in ServiceType.maintenances)
                _TypeChip(
                  type: type,
                  selected: type == selected,
                  scheduled: type == order.scheduledType,
                  onTap: () => setState(() => _type = type),
                ),
            ],
          ),
          if (deviceQuestion) ...[
            const SizedBox(height: 18),
            const Text(
              '¿El dispositivo funciona?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AnswerButton(
                    label: 'Sí, revisión',
                    selected: selected == ServiceType.revision,
                    onTap: () => setState(() => _type = ServiceType.revision),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnswerButton(
                    label: 'No, cambiar equipo',
                    selected: selected == ServiceType.cEquipo,
                    onTap: () => setState(() => _type = ServiceType.cEquipo),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleCard(ServiceOrderRecord order) {
    final other = _installationLabel;
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.directions_car_outlined,
            title: 'Vehículo a atender',
          ),
          const SizedBox(height: 8),
          ServiceOrderReadOnlyRow(
            other == null ? 'Programado' : 'Elegido',
            other ?? order.vehicleLabel ?? 'Instalación programada',
            isLast: true,
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: () => _pickOtherVehicle(order),
                style: TextButton.styleFrom(
                  foregroundColor: ServiceOrderColors.accent,
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Atender otro vehículo'),
              ),
              if (other != null)
                TextButton(
                  onPressed: () => setState(() {
                    _installationId = null;
                    _installationLabel = null;
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: ServiceOrderColors.mutedText,
                  ),
                  child: const Text('Usar el programado'),
                ),
            ],
          ),
          const Text(
            'Después operación te dictará un código para confirmar que estás '
            'en el vehículo correcto.',
            style: TextStyle(color: ServiceOrderColors.hintText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final ServiceType type;
  final bool selected;
  final bool scheduled;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.selected,
    required this.scheduled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? ServiceOrderColors.accentBackground
                : ServiceOrderColors.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? ServiceOrderColors.accent : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : ServiceOrderIcons.serviceType(type),
                size: 20,
                color: selected
                    ? ServiceOrderColors.accent
                    : ServiceOrderColors.mutedText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  scheduled ? '${type.label} · programado' : type.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        selected ? Colors.white : ServiceOrderColors.mutedText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : ServiceOrderColors.mutedText,
        backgroundColor:
            selected ? ServiceOrderColors.accentBackground : Colors.transparent,
        side: BorderSide(
          color:
              selected ? ServiceOrderColors.accent : ServiceOrderColors.divider,
        ),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

/// Busca por placa la instalación vigente de otro vehículo. El API valida al
/// iniciar que sea vigente y del cliente de la orden.
class _OtherVehicleDialog extends StatefulWidget {
  final VehicleRemoteDataSource vehicles;
  final ServiceOrderRepository orders;
  final String? clientId;

  const _OtherVehicleDialog({
    required this.vehicles,
    required this.orders,
    required this.clientId,
  });

  @override
  State<_OtherVehicleDialog> createState() => _OtherVehicleDialogState();
}

class _OtherVehicleDialogState extends State<_OtherVehicleDialog> {
  final _plateController = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      setState(() => _error = 'Escribe la placa');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final vehicle = await widget.vehicles.findByPlate(plate);
      if (!mounted) return;
      if (vehicle == null) {
        setState(() => _error = 'No hay un vehículo con la placa $plate.');
        return;
      }
      if (vehicle.clientId != null && vehicle.clientId != widget.clientId) {
        setState(() => _error = 'La placa $plate es de otro cliente.');
        return;
      }
      final installation =
          await widget.orders.findCurrentInstallation(productId: vehicle.id);
      if (!mounted) return;
      if (installation == null) {
        setState(() => _error = 'El vehículo $plate no tiene una '
            'instalación vigente.');
        return;
      }
      Navigator.of(context).pop(CurrentInstallation(
        id: installation.id,
        productId: vehicle.id,
        productLabel: plate,
        deviceLabel: installation.deviceLabel,
        simLabel: installation.simLabel,
      ));
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo buscar el vehículo.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ServiceOrderColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Atender otro vehículo',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderTextField(
            label: 'Placa',
            hint: 'Ej: NV4126B',
            controller: _plateController,
            enabled: !_searching,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
              LengthLimitingTextInputFormatter(VehicleRequest.maxPlateLength),
            ],
            errorText: _error,
            isLast: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _searching ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _searching ? null : _search,
          style: TextButton.styleFrom(
            foregroundColor: ServiceOrderColors.accent,
          ),
          child: Text(_searching ? 'Buscando...' : 'Buscar'),
        ),
      ],
    );
  }
}
