import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../../data/datasources/remote/vehicle_remote_datasource.dart';
import '../../../data/models/vehicle_request.dart';
import '../../../domain/entities/catalog_item.dart';
import '../../../domain/entities/service_order.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_fields.dart';
import '../widgets/service_order_photos.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// Alta: buscar el vehículo por placa o darlo de alta, fijarlo en la orden y,
/// si ya tiene un equipo instalado, pedir autorización para desinstalarlo.
class VehicleStep extends StatefulWidget {
  const VehicleStep({super.key});

  @override
  State<VehicleStep> createState() => _VehicleStepState();
}

enum _SearchState { idle, found, notFound }

class _VehicleStepState extends State<VehicleStep> {
  static const List<ServiceOrderPhotoSlot> _photoSlots = [
    ServiceOrderPhotoSlot(
        'principal', 'Imagen principal', Icons.image_outlined),
    ServiceOrderPhotoSlot(
        'frontal', 'Fotografía frontal', Icons.directions_car_outlined),
    ServiceOrderPhotoSlot(
        'trasera', 'Fotografía trasera', Icons.directions_car_filled_outlined),
    ServiceOrderPhotoSlot(
        'lateral_derecha', 'Lateral derecha', Icons.arrow_forward),
    ServiceOrderPhotoSlot(
        'lateral_izquierda', 'Lateral izquierda', Icons.arrow_back),
    ServiceOrderPhotoSlot(
        'tarjeta_circulacion', 'Tarjeta de circulación', Icons.badge_outlined),
  ];

  static final List<String> _years = [
    for (var year = DateTime.now().year + 1; year >= 1990; year--) '$year',
  ];

  static const List<String> _colors = [
    'Blanco',
    'Negro',
    'Gris',
    'Plata',
    'Rojo',
    'Azul',
    'Azul marino',
    'Beige',
    'Café',
    'Verde',
    'Amarillo',
    'Naranja',
    'Vino',
    'Dorado',
    'Otro',
  ];

  final _plateController = TextEditingController();
  final _economicController = TextEditingController();
  final _vinController = TextEditingController();
  final _observationsController = TextEditingController();
  final Map<String, Uint8List> _photos = {};
  final Map<String, Uint8List> _equipmentPhoto = {};
  final _photosKey = GlobalKey();

  _SearchState _search = _SearchState.idle;
  VehicleLookup? _found;
  bool _searching = false;

  /// `POST /productos/vehiculos` con las fotos: tarda y ocurre fuera del
  /// controlador, así que [ServiceOrderFlowController.isBusy] no lo cubre.
  bool _registering = false;
  bool _changing = false;
  bool _showErrors = false;

  VehicleCatalogs? _catalogs;
  String? _catalogError;
  String? _brandId;
  String? _modelId;
  String? _fuelId;
  String? _year;
  String? _color;

  @override
  void initState() {
    super.initState();
    for (final controller in [_plateController, _observationsController]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _economicController.dispose();
    _vinController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  String get _plate => _plateController.text.trim().toUpperCase();

  Future<void> _searchPlate() async {
    if (_plate.isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _searching = true;
      _search = _SearchState.idle;
      _found = null;
    });
    try {
      final found =
          await context.read<VehicleRemoteDataSource>().findByPlate(_plate);
      if (!mounted) return;
      setState(() {
        _found = found;
        _search = found == null ? _SearchState.notFound : _SearchState.found;
      });
      if (found == null) _loadCatalogs();
    } on Failure catch (e) {
      // 400 si hay más de un vehículo con esa placa.
      if (mounted) showServiceOrderMessage(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadCatalogs() async {
    if (_catalogs != null) return;
    try {
      final catalogs =
          await context.read<CatalogRepository>().getVehicleCatalogs();
      if (mounted) setState(() => _catalogs = catalogs);
    } on Failure catch (e) {
      if (mounted) setState(() => _catalogError = e.message);
    }
  }

  Future<void> _useFound() async {
    final controller = context.read<ServiceOrderFlowController>();
    final found = _found;
    if (found == null) return;
    final clientId = controller.order?.clientId;
    if (found.clientId != null && found.clientId != clientId) {
      showServiceOrderMessage(
        context,
        'La placa $_plate está registrada con otro cliente.',
        isError: true,
      );
      return;
    }
    final ok =
        await runOrderAction(context, () => controller.setVehicle(found.id));
    if (ok && mounted) setState(() => _changing = false);
  }

  /// `POST /productos/vehiculos` con el cliente de la orden; el id que
  /// devuelve se fija en la orden.
  /// Las 6 fotos del vehículo son obligatorias: se toman en la instalación.
  List<ServiceOrderPhotoSlot> get _missingPhotos => [
        for (final slot in _photoSlots)
          if (!_photos.containsKey(slot.id)) slot
      ];

  Future<void> _createVehicle() async {
    final controller = context.read<ServiceOrderFlowController>();
    final dataSource = context.read<VehicleRemoteDataSource>();
    final clientId = controller.order?.clientId;
    if (clientId == null) {
      showServiceOrderMessage(context, 'La orden no tiene cliente.',
          isError: true);
      return;
    }
    final missing = _missingPhotos;
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      if (_photosKey.currentContext case final target?) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          alignment: 0.05,
        );
      }
      showServiceOrderMessage(
        context,
        'Faltan fotografías del vehículo: '
        '${missing.map((slot) => slot.label).join(', ')}.',
        isError: true,
      );
      return;
    }
    if (_registering) return;
    FocusScope.of(context).unfocus();
    setState(() => _registering = true);
    final bool ok;
    try {
      ok = await _registerVehicle(controller, dataSource, clientId);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
    if (ok && mounted) setState(() => _changing = false);
  }

  Future<bool> _registerVehicle(
    ServiceOrderFlowController controller,
    VehicleRemoteDataSource dataSource,
    String clientId,
  ) {
    return runOrderAction(context, () async {
      final id = await dataSource.createVehicle(
        VehicleRequest(
          clientId: clientId,
          plate: _plate,
          economicNumber: _economicController.text,
          brandId: _brandId,
          modelId: _modelId,
          year: _year ?? '',
          color: _color ?? '',
          serialNumber: _vinController.text,
          fuelId: _fuelId,
          files: Map.of(_photos),
        ),
        fileLabels: {for (final slot in _photoSlots) slot.id: slot.label},
      );
      if (id == null) {
        throw const ServerFailure(
          'El servidor no devolvió el id del vehículo.',
        );
      }
      await controller.setVehicle(id);
    });
  }

  Future<void> _requestAuthorization() async {
    final controller = context.read<ServiceOrderFlowController>();
    final photo = _equipmentPhoto[ServiceOrderSection.existingEquipmentPhoto];
    // Ya enviada (se sube al tomarla), aunque la página se haya recargado.
    final hasPhoto = photo != null ||
        controller.order?.file(ServiceOrderSection.existingEquipmentPhoto) !=
            null;
    final observations = _observationsController.text.trim();
    if (!hasPhoto || observations.isEmpty) {
      setState(() => _showErrors = true);
      showServiceOrderMessage(
        context,
        'Toma la foto del equipo encontrado y describe lo que viste.',
        isError: true,
      );
      return;
    }
    await runOrderAction(
      context,
      () => controller.requestAuthorization(
        photo: photo,
        photoLabel: 'Equipo encontrado',
        observations: observations,
      ),
      success: 'Autorización solicitada a operación.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;
    final hasVehicle = order.productId != null;
    final showSearch = !hasVehicle || _changing;

    return ServiceOrderFormBody(
      action: ServiceOrderBottomButton(
        label: 'Siguiente',
        isLoading: controller.isBusy || _registering,
        onPressed: controller.isBlocking(ServiceOrderStep.vehicle)
            ? null
            : controller.next,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderStepNotice(
            icon: Icons.directions_car_outlined,
            title: 'Vehículo del alta',
            message: 'Cliente: ${order.clientName ?? '—'}. Busca el vehículo '
                'por placa; si no existe en Next, regístralo.',
          ),
          const SizedBox(height: 16),
          if (hasVehicle && !_changing) _buildCurrentVehicle(order),
          if (showSearch) _buildSearchCard(controller),
          if (showSearch && _search == _SearchState.found) ...[
            const SizedBox(height: 16),
            _buildFoundCard(controller),
          ],
          if (showSearch && _search == _SearchState.notFound) ...[
            const SizedBox(height: 16),
            _buildNewVehicleCard(controller),
          ],
          if (hasVehicle && !_changing) ...[
            const SizedBox(height: 16),
            ..._buildAuthorization(controller, order),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentVehicle(ServiceOrderRecord order) {
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.verified_outlined,
            title: 'Vehículo de la orden',
          ),
          const SizedBox(height: 8),
          ServiceOrderReadOnlyRow(
            'Vehículo',
            order.vehicleLabel ?? 'Vehículo #${order.productId}',
            isLast: true,
          ),
          if (order.vehicleLocked)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ya se pidió la autorización: el vehículo no se puede cambiar.',
                style: TextStyle(
                  color: ServiceOrderColors.hintText,
                  fontSize: 13,
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _changing = true;
                  _search = _SearchState.idle;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: ServiceOrderColors.accent,
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Cambiar vehículo'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(ServiceOrderFlowController controller) {
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.search,
            title: 'Buscar por placa',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          ServiceOrderTextField(
            label: 'Placa',
            hint: 'Ej: NV4126B',
            controller: _plateController,
            isRequired: true,
            enabled: !_searching && !controller.isBusy && !_registering,
            errorText: _showErrors && _plate.isEmpty
                ? 'La placa es obligatoria'
                : null,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
              LengthLimitingTextInputFormatter(VehicleRequest.maxPlateLength),
              _UpperCaseFormatter(),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _searching || controller.isBusy || _registering
                      ? null
                      : _searchPlate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: ServiceOrderColors.accent),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Buscar vehículo'),
                ),
              ),
              if (_changing) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _changing = false),
                  style: TextButton.styleFrom(
                    foregroundColor: ServiceOrderColors.mutedText,
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoundCard(ServiceOrderFlowController controller) {
    return FlowNoticeCard(
      icon: Icons.check_circle_outline,
      color: ServiceOrderColors.success,
      title: 'Vehículo registrado en Next',
      message: 'La placa $_plate ya existe. Se usará en esta orden sin '
          'modificar sus datos.',
      children: [
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: controller.isBusy ? null : _useFound,
          style: _primaryButtonStyle,
          child: _ButtonLabel(
            label: 'Usar este vehículo',
            busyLabel: 'Asignando vehículo…',
            isBusy: controller.isBusy,
          ),
        ),
      ],
    );
  }

  static final ButtonStyle _primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.primaryBlue.withValues(alpha: 0.6),
    disabledForegroundColor: Colors.white,
    minimumSize: const Size.fromHeight(46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _buildNewVehicleCard(ServiceOrderFlowController controller) {
    final catalogs = _catalogs;
    final ready = catalogs != null;
    final models = catalogs?.modelsFor(_brandId) ?? const <CatalogItem>[];
    String Function(String) labelFrom(List<CatalogItem>? items) =>
        (id) => items?.where((item) => item.id == id).firstOrNull?.name ?? id;
    List<String> ids(List<CatalogItem>? items) =>
        items?.map((item) => item.id).toList() ?? const [];

    // Mientras se registra no se pueden cambiar los datos ni las fotos.
    return ServiceOrderCard(
      child: AbsorbPointer(
        absorbing: _registering,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ServiceOrderSectionHeader(
              icon: Icons.add_circle_outline,
              title: 'Registrar vehículo nuevo',
            ),
            const SizedBox(height: 8),
            Text(
              'No hay un vehículo con la placa $_plate. Se dará de alta para '
              'el cliente de la orden. Las fotografías son obligatorias; los '
              'demás datos, opcionales.',
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_catalogError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '$_catalogError Puedes registrar el vehículo solo con la placa.',
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ServiceOrderTextField(
              label: 'Número económico',
              hint: 'Ej: ECO-045',
              controller: _economicController,
              textCapitalization: TextCapitalization.characters,
            ),
            ServiceOrderDropdown(
              key: ValueKey('marca_$ready'),
              label: 'Marca',
              hint: ready ? 'Selecciona una marca' : 'Cargando...',
              value: _brandId,
              items: ids(catalogs?.brands),
              itemLabel: labelFrom(catalogs?.brands),
              clearLabel: 'Sin especificar',
              onChanged: !ready
                  ? null
                  : (value) => setState(() {
                        _brandId = value;
                        _modelId = null;
                      }),
            ),
            ServiceOrderDropdown(
              key: ValueKey('modelo_${_brandId}_$ready'),
              label: 'Modelo',
              hint: _brandId == null
                  ? 'Selecciona primero una marca'
                  : 'Selecciona un modelo',
              value: _modelId,
              items: ids(models),
              itemLabel: labelFrom(models),
              clearLabel: 'Sin especificar',
              onChanged: models.isEmpty
                  ? null
                  : (value) => setState(() => _modelId = value),
            ),
            ServiceOrderDropdown(
              label: 'Año',
              hint: 'Selecciona el año',
              value: _year,
              items: _years,
              clearLabel: 'Sin especificar',
              onChanged: (value) => setState(() => _year = value),
            ),
            ServiceOrderDropdown(
              label: 'Color',
              hint: 'Selecciona el color',
              value: _color,
              items: _colors,
              clearLabel: 'Sin especificar',
              onChanged: (value) => setState(() => _color = value),
            ),
            ServiceOrderTextField(
              label: 'Número de serie (VIN)',
              hint: 'Ej: 3N1CN7AD5KL123456',
              controller: _vinController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(17),
              ],
            ),
            ServiceOrderDropdown(
              key: ValueKey('combustible_$ready'),
              label: 'Combustible',
              hint: ready ? 'Selecciona el combustible' : 'Cargando...',
              value: _fuelId,
              items: ids(catalogs?.fuelTypes),
              itemLabel: labelFrom(catalogs?.fuelTypes),
              clearLabel: 'Sin especificar',
              onChanged:
                  !ready ? null : (value) => setState(() => _fuelId = value),
              isLast: true,
            ),
            const SizedBox(height: 16),
            Row(
              key: _photosKey,
              children: [
                const Expanded(
                  child: Text(
                    'Fotografías del vehículo *',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_photos.length}/${_photoSlots.length}',
                  style: const TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ServiceOrderPhotoGrid(
              slots: [
                for (final slot in _photoSlots)
                  ServiceOrderPhotoSlot(slot.id, '${slot.label} *', slot.icon),
              ],
              photos: _photos,
              onChanged: (slot, bytes) => setState(() {
                bytes == null ? _photos.remove(slot) : _photos[slot] = bytes;
              }),
            ),
            if (_showErrors && _missingPhotos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _missingPhotos.length == 1
                      ? 'Falta 1 fotografía del vehículo.'
                      : 'Faltan ${_missingPhotos.length} fotografías del '
                          'vehículo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  controller.isBusy || _registering ? null : _createVehicle,
              style: _primaryButtonStyle,
              child: _ButtonLabel(
                label: 'Registrar vehículo',
                busyLabel: 'Registrando vehículo…',
                isBusy: controller.isBusy || _registering,
              ),
            ),
            if (_registering)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Subiendo los datos y las fotos. No cierres la app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// §7: pedir la autorización, esperar la decisión o continuar si se
  /// autorizó. Si se rechaza, la orden queda no cumplida y la página lo
  /// muestra.
  List<Widget> _buildAuthorization(
    ServiceOrderFlowController controller,
    ServiceOrderRecord order,
  ) {
    switch (order.authorization) {
      case AuthorizationStatus.pendiente:
        return [
          FlowNoticeCard(
            icon: Icons.hourglass_top,
            color: ServiceOrderColors.warning,
            title: 'Esperando la decisión de operación',
            message: 'No desinstales el equipo todavía. La App consulta la '
                'respuesta automáticamente.',
            trailing: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ServiceOrderColors.warning,
              ),
            ),
            children: [
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => runOrderAction(context, controller.refresh),
                  style: TextButton.styleFrom(
                    foregroundColor: ServiceOrderColors.accent,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Consultar ahora'),
                ),
              ),
            ],
          ),
        ];
      case AuthorizationStatus.autorizada:
        return const [
          FlowNoticeCard(
            icon: Icons.verified_outlined,
            color: ServiceOrderColors.success,
            title: 'Desinstalación autorizada',
            message: 'Desinstala el equipo encontrado y continúa con el alta. '
                'Al cerrar, Next da de baja la instalación anterior.',
          ),
        ];
      case AuthorizationStatus.rechazada:
        return const [];
      case null:
        if (!order.needsAuthorization) return const [];
        return [
          FlowNoticeCard(
            icon: Icons.warning_amber_outlined,
            color: ServiceOrderColors.warning,
            title: 'El vehículo ya tiene un equipo instalado',
            message: 'Pide autorización a operación para desinstalarlo. Toma '
                'una foto del equipo y describe lo que encontraste.',
            children: [
              const SizedBox(height: 16),
              ServiceOrderPhotoGrid(
                slots: const [
                  ServiceOrderPhotoSlot(
                    ServiceOrderSection.existingEquipmentPhoto,
                    'Equipo encontrado *',
                    Icons.gps_fixed,
                  ),
                ],
                photos: _equipmentPhoto,
                remoteUrls: {
                  if (order.file(ServiceOrderSection.existingEquipmentPhoto)
                      case final file?)
                    file.key: file.url,
                },
                crossAxisCount: 1,
                childAspectRatio: 2.4,
                uploading: controller.uploadingPhotos,
                failed: controller.failedPhotos.keys.toSet(),
                onRetry: controller.retryPhoto,
                onChanged: (slot, bytes) {
                  setState(() {
                    bytes == null
                        ? _equipmentPhoto.remove(slot)
                        : _equipmentPhoto[slot] = bytes;
                  });
                  // Se sube al tomarla; la solicitud reintenta si falló.
                  if (bytes == null) {
                    controller.discardPhoto(slot);
                  } else {
                    controller.uploadPhoto(slot, 'Equipo encontrado', bytes);
                  }
                },
              ),
              const SizedBox(height: 14),
              ServiceOrderTextField(
                label: 'Observaciones',
                hint: 'Ej: GPS de otra marca bajo el tablero',
                controller: _observationsController,
                isRequired: true,
                errorText:
                    _showErrors && _observationsController.text.trim().isEmpty
                        ? 'Describe el equipo encontrado'
                        : null,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                isLast: true,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : _requestAuthorization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ServiceOrderColors.warning,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Pedir autorización'),
              ),
            ],
          ),
        ];
    }
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Texto de un botón con indicador de carga mientras la acción está en curso.
class _ButtonLabel extends StatelessWidget {
  final String label;
  final String busyLabel;
  final bool isBusy;

  const _ButtonLabel({
    required this.label,
    required this.busyLabel,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    if (!isBusy) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(busyLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
