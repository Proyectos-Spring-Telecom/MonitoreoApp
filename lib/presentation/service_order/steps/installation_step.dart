import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../../data/datasources/remote/installation_remote_datasource.dart';
import '../../../domain/entities/installation_resources.dart';
import '../../../domain/entities/service_order.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../../domain/repositories/service_order_repository.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_fields.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// Alta: equipo y SIM que entran. Mantenimientos: lo que cambia según el
/// tipo. El servidor aplica el movimiento en Instalaciones al cerrar.
class InstallationStep extends StatefulWidget {
  const InstallationStep({super.key});

  @override
  State<InstallationStep> createState() => _InstallationStepState();
}

class _InstallationStepState extends State<InstallationStep> {
  InstallationStock? _stock;
  bool _loadingStock = false;
  String? _stockError;
  CurrentInstallation? _current;

  String? _deviceId;
  String? _simId;
  OutgoingStatus? _outgoing;
  RemovalStatus? _removal;
  bool _showErrors = false;

  ServiceOrderRecord get _order =>
      context.read<ServiceOrderFlowController>().order!;

  ServiceType get _type => _order.type ?? ServiceType.revision;

  @override
  void initState() {
    super.initState();
    final order = _order;
    _deviceId = order.newDeviceId;
    _simId = order.newSimId;
    _outgoing = OutgoingStatus.fromId(order.outgoingStatus);
    _removal = RemovalStatus.fromId(order.removalStatus);
    if (_type.takesNewDevice || _type.takesNewSim) _loadStock();
    if (_type.isMaintenance) _loadCurrent();
  }

  Future<void> _loadStock() async {
    final clientId = _order.clientId;
    if (clientId == null) {
      setState(() => _stockError = 'La orden no tiene cliente.');
      return;
    }
    setState(() {
      _loadingStock = true;
      _stockError = null;
    });
    try {
      final stock = await context
          .read<InstallationRemoteDataSource>()
          .getStock(clientId: clientId);
      if (mounted) setState(() => _stock = stock);
    } on Failure catch (e) {
      if (mounted) setState(() => _stockError = e.message);
    } finally {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  /// Solo para mostrar el equipo y la SIM actuales; si falla no bloquea.
  Future<void> _loadCurrent() async {
    final id = _order.installationId ?? _order.scheduledInstallationId;
    if (id == null) return;
    try {
      final current =
          await context.read<ServiceOrderRepository>().getInstallation(id);
      if (mounted) setState(() => _current = current);
    } catch (_) {}
  }

  InstallationResource? _find(List<InstallationResource>? items, String? id) =>
      items?.where((item) => item.id == id).firstOrNull;

  List<String> _missing() => [
        if (_type.takesNewDevice && _deviceId == null)
          _type == ServiceType.cEquipo ? 'Dispositivo nuevo' : 'Dispositivo',
        if (_type == ServiceType.cSim && _simId == null) 'SIM nueva',
        if (_type.takesOutgoingStatus && _outgoing == null)
          'Destino del que sale',
        if (_type == ServiceType.desinstalacion && _removal == null)
          'Estatus de la instalación',
      ];

  /// El que entra sale del almacén o de lo reservado al cliente de la orden.
  String? _resourceError() {
    final clientId = _order.clientId;
    final checks = <(String, String?, List<InstallationResource>?)>[
      if (_type.takesNewDevice) ('El dispositivo', _deviceId, _stock?.devices),
      if (_type.takesNewSim) ('La SIM', _simId, _stock?.sims),
    ];
    for (final (label, id, items) in checks) {
      if (id == null) continue;
      final resource = _find(items, id);
      // Lo ya guardado puede no venir en la lista si cambió de estatus.
      if (resource == null) continue;
      if (!resource.canInstallFor(clientId)) {
        return '$label debe estar en el almacén o reservado al cliente.';
      }
    }
    if (_type == ServiceType.cEquipo && _deviceId == _current?.deviceId) {
      return 'Elige un dispositivo distinto al instalado.';
    }
    if (_type == ServiceType.cSim && _simId == _current?.simId) {
      return 'Elige una SIM distinta a la instalada.';
    }
    return null;
  }

  ServiceOrderUpdate _update() => switch (_type) {
        ServiceType.instalacion => ServiceOrderUpdate(
            newDeviceId: _deviceId,
            newSimId: _simId,
            clear: {if (_simId == null) 'idSimNuevo'},
          ),
        ServiceType.cEquipo => ServiceOrderUpdate(
            newDeviceId: _deviceId,
            outgoingStatus: _outgoing?.id,
          ),
        ServiceType.cSim => ServiceOrderUpdate(
            newSimId: _simId,
            outgoingStatus: _outgoing?.id,
          ),
        ServiceType.desinstalacion =>
          ServiceOrderUpdate(removalStatus: _removal?.id),
        ServiceType.revision => const ServiceOrderUpdate(),
      };

  Future<void> _handleNext() async {
    final controller = context.read<ServiceOrderFlowController>();
    final missing = _missing();
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      showServiceOrderMessage(
        context,
        'Completa: ${missing.join(', ')}.',
        isError: true,
      );
      return;
    }
    final error = _resourceError();
    if (error != null) {
      showServiceOrderMessage(context, error, isError: true);
      return;
    }
    final update = _update();
    if (update.isEmpty) {
      controller.next();
      return;
    }
    final ok = await runOrderAction(
        context, () => controller.saveInstallation(update));
    if (ok && mounted) controller.next();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;

    return ServiceOrderFormBody(
      action: ServiceOrderBottomButton(
        label: controller.isBusy ? 'Guardando...' : 'Siguiente',
        isLoading: controller.isBusy,
        onPressed: _handleNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderStepNotice(
            icon: Icons.memory_outlined,
            title: _type.label,
            message: switch (_type) {
              ServiceType.instalacion =>
                'Elige el equipo y la SIM que instalarás.',
              ServiceType.revision => 'La revisión no modifica la instalación.',
              ServiceType.cSim => 'Cambia únicamente la SIM; el dispositivo '
                  'y la configuración se conservan.',
              ServiceType.cEquipo =>
                'Desinstala el equipo anterior e instala el nuevo.',
              ServiceType.desinstalacion =>
                'Indica cómo queda la instalación al darla de baja.',
            },
          ),
          const SizedBox(height: 14),
          const ServiceOrderRequiredLegend(),
          const SizedBox(height: 14),
          if (_type.isMaintenance) ...[
            _buildCurrentCard(order),
            const SizedBox(height: 16),
          ],
          if (_stockError != null) ...[
            _buildStockError(),
            const SizedBox(height: 16),
          ],
          _buildChangeCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentCard(ServiceOrderRecord order) {
    final current = _current;
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.verified_outlined,
            title: 'Instalación vigente',
          ),
          const SizedBox(height: 4),
          ServiceOrderReadOnlyRow('Vehículo', order.vehicleLabel),
          ServiceOrderReadOnlyRow('Dispositivo', current?.deviceLabel),
          ServiceOrderReadOnlyRow('SIM', current?.simLabel, isLast: true),
        ],
      ),
    );
  }

  Widget _buildStockError() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: ServiceOrderColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _stockError!,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadStock,
            style: TextButton.styleFrom(
              foregroundColor: ServiceOrderColors.accent,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  String? _error(bool missing, String message) =>
      _showErrors && missing ? message : null;

  /// Primero lo que se puede instalar; lo demás se marca "No disponible".
  List<String> _ids(List<InstallationResource>? items, {String? exclude}) {
    final clientId = _order.clientId;
    final list = [...?items]
      ..removeWhere((item) => item.id == exclude)
      ..sort((a, b) {
        final aOk = a.canInstallFor(clientId);
        final bOk = b.canInstallFor(clientId);
        if (aOk == bOk) return 0;
        return aOk ? -1 : 1;
      });
    return list.map((item) => item.id).toList();
  }

  String Function(String) _label(List<InstallationResource>? items) => (id) {
        final resource = _find(items, id);
        if (resource == null) return id;
        if (!resource.canInstallFor(_order.clientId)) {
          return '${resource.label} · No disponible';
        }
        return resource.isInWarehouse
            ? '${resource.label} · Almacén'
            : '${resource.label} · Reservado';
      };

  String _hint(List<InstallationResource>? items, String empty, String hint) {
    if (_loadingStock) return 'Cargando...';
    if (items != null && items.isEmpty) return empty;
    return hint;
  }

  Widget _buildChangeCard() {
    final devices = _stock?.devices;
    final sims = _stock?.sims;

    final fields = <Widget>[
      if (_type.takesNewDevice)
        ServiceOrderDropdown(
          label: _type == ServiceType.cEquipo
              ? 'Dispositivo nuevo'
              : 'Dispositivo',
          hint: _hint(devices, 'Sin equipos para este cliente',
              'Selecciona el dispositivo'),
          isRequired: true,
          value: _deviceId,
          items: _ids(devices, exclude: _current?.deviceId),
          itemLabel: _label(devices),
          errorText: _error(_deviceId == null, 'El dispositivo es obligatorio'),
          onChanged: devices == null || devices.isEmpty
              ? null
              : (value) => setState(() => _deviceId = value),
          isLast: !_type.takesNewSim && !_type.takesOutgoingStatus,
        ),
      if (_type.takesNewSim)
        ServiceOrderDropdown(
          label: _type == ServiceType.cSim ? 'SIM nueva' : 'SIM (opcional)',
          hint: _hint(sims, 'Sin SIMs para este cliente', 'Selecciona la SIM'),
          isRequired: _type == ServiceType.cSim,
          value: _simId,
          items: _ids(sims, exclude: _current?.simId),
          itemLabel: _label(sims),
          clearLabel: _type == ServiceType.instalacion ? 'Sin SIM' : null,
          errorText: _error(
            _type == ServiceType.cSim && _simId == null,
            'La SIM nueva es obligatoria',
          ),
          onChanged: sims == null || sims.isEmpty
              ? null
              : (value) => setState(() => _simId = value),
          isLast: !_type.takesOutgoingStatus,
        ),
      if (_type.takesOutgoingStatus)
        ServiceOrderDropdown(
          label: _type == ServiceType.cSim
              ? 'Destino de la SIM que sale'
              : 'Destino del equipo que sale',
          hint: 'Selecciona el destino',
          isRequired: true,
          value: _outgoing?.id.toString(),
          items: [for (final status in OutgoingStatus.values) '${status.id}'],
          itemLabel: (id) =>
              OutgoingStatus.fromId(int.tryParse(id))?.label ?? id,
          errorText: _error(_outgoing == null, 'El destino es obligatorio'),
          onChanged: (id) => setState(
            () => _outgoing = OutgoingStatus.fromId(int.tryParse(id ?? '')),
          ),
          isLast: true,
        ),
      if (_type == ServiceType.desinstalacion) ..._buildRemovalOptions(),
    ];

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderSectionHeader(
            icon: _type == ServiceType.desinstalacion
                ? Icons.remove_circle_outline
                : Icons.swap_horiz,
            title: switch (_type) {
              ServiceType.instalacion => 'Equipo a instalar',
              ServiceType.cEquipo => 'Sustitución del equipo',
              ServiceType.cSim => 'Cambio de SIM',
              ServiceType.desinstalacion => 'Baja de la instalación',
              ServiceType.revision => 'Revisión',
            },
          ),
          const SizedBox(height: 16),
          if (fields.isEmpty)
            const Text(
              'Continúa la operación según el servicio: no hay cambios en el '
              'equipo ni en la SIM.',
              style: TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 14,
                height: 1.4,
              ),
            )
          else
            ...fields,
        ],
      ),
    );
  }

  List<Widget> _buildRemovalOptions() => [
        for (final status in RemovalStatus.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setState(() => _removal = status),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _removal == status
                      ? ServiceOrderColors.accentBackground
                      : ServiceOrderColors.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _removal == status
                        ? ServiceOrderColors.accent
                        : (_showErrors && _removal == null
                            ? AppColors.error.withValues(alpha: 0.6)
                            : Colors.transparent),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _removal == status
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _removal == status
                          ? ServiceOrderColors.accent
                          : ServiceOrderColors.mutedText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.description,
                            style: const TextStyle(
                              color: ServiceOrderColors.mutedText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ];
}
