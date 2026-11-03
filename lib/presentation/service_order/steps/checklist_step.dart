import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/service_order.dart';
import '../../../domain/entities/service_order_record.dart';
import '../service_order_flow_controller.dart';
import '../widgets/service_order_icons.dart';
import '../widgets/service_order_photos.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// "Vehículo cuenta con", "Funcionamiento del vehículo", "Fallas encontradas
/// del equipo" y las fotos del catálogo. Todas las opciones se envían (sí o
/// no) porque el servidor las exige para cerrar (§5).
class ChecklistStep extends StatefulWidget {
  const ChecklistStep({super.key});

  @override
  State<ChecklistStep> createState() => _ChecklistStepState();
}

class _ChecklistStepState extends State<ChecklistStep> {
  final _photosKey = GlobalKey();
  final Map<String, bool> _answers = {};
  final Map<String, Uint8List> _photos = {};
  bool _showErrors = false;

  static String _key(String section, String key) => '$section/$key';

  @override
  void initState() {
    super.initState();
    final order = context.read<ServiceOrderFlowController>().order!;
    for (final answer in order.answers) {
      _answers[_key(answer.section, answer.key)] = answer.value;
    }
  }

  ServiceOrderCatalog get _catalog =>
      context.read<ServiceOrderFlowController>().catalog!;

  bool _showsFailures(ServiceOrderRecord order) =>
      _catalog.showsFailures(order.type);

  bool _answer(ServiceOrderRecord order, String section, String key) =>
      (section != ServiceOrderSection.equipmentFailures ||
          _showsFailures(order)) &&
      (_answers[_key(section, key)] ?? false);

  List<ServiceOrderOption> _missingPhotos(ServiceOrderRecord order) => [
        for (final photo in _catalog.checklistPhotosFor(order.type))
          if (photo.required &&
              !_photos.containsKey(photo.key) &&
              order.file(photo.key) == null)
            photo,
      ];

  Future<void> _handleNext() async {
    final controller = context.read<ServiceOrderFlowController>();
    final order = controller.order!;
    final missing = _missingPhotos(order);
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
        'Faltan fotografías obligatorias: '
        '${missing.map((photo) => photo.name).join(', ')}.',
        isError: true,
      );
      return;
    }

    final answers = [
      for (final section in ServiceOrderSection.checklist)
        for (final option in _catalog.section(section))
          ServiceOrderAnswer(
            section,
            option.key,
            _answer(order, section, option.key),
          ),
    ];
    final names = {
      for (final photo in _catalog.section(ServiceOrderSection.photos))
        photo.key: photo.name,
    };
    final ok = await runOrderAction(
      context,
      () => controller.saveChecklist(
        answers: answers,
        photos: {
          for (final MapEntry(:key, value: bytes) in _photos.entries)
            key: (names[key] ?? key, bytes),
        },
      ),
    );
    if (ok && mounted) controller.next();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;
    final catalog = controller.catalog!;
    final photos = catalog.checklistPhotosFor(order.type);
    final dashboard = photos
        .where((photo) =>
            !photo.key.startsWith(ServiceOrderSection.failurePhotoPrefix))
        .toList();
    final failures = photos
        .where((photo) =>
            photo.key.startsWith(ServiceOrderSection.failurePhotoPrefix))
        .toList();

    return ServiceOrderFormBody(
      action: ServiceOrderBottomButton(
        label: controller.isBusy ? 'Guardando...' : 'Siguiente',
        isLoading: controller.isBusy,
        onPressed: _handleNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderStepNotice(
            icon: Icons.checklist_outlined,
            title: 'Revisa el vehículo',
            message: 'Verifica los accesorios, el funcionamiento y toma la '
                'evidencia del tablero.',
          ),
          const SizedBox(height: 16),
          _buildSwitchCard(
            order,
            section: ServiceOrderSection.vehicleFeatures,
            icon: Icons.directions_car_outlined,
            title: 'Vehículo cuenta con',
            description: 'Activa los accesorios con los que cuenta el '
                'vehículo (botón de pánico, inmovilizador, estéreo…).',
          ),
          const SizedBox(height: 16),
          _buildSwitchCard(
            order,
            section: ServiceOrderSection.vehicleOperation,
            icon: Icons.speed,
            title: 'Funcionamiento del vehículo',
            description: 'Activa las revisiones que resultaron correctas.',
            footer: KeyedSubtree(
              key: _photosKey,
              child: _buildPhotos(order, 'Tablero y evidencia', dashboard),
            ),
          ),
          if (_showsFailures(order)) ...[
            const SizedBox(height: 16),
            _buildSwitchCard(
              order,
              section: ServiceOrderSection.equipmentFailures,
              icon: Icons.report_problem_outlined,
              title: 'Fallas encontradas del equipo',
              description: 'Activa las fallas que presenta el equipo. Si '
                  'activas "Otro", descríbelo en Observaciones.',
              footer: _buildPhotos(order, 'Imágenes extras', failures),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchCard(
    ServiceOrderRecord order, {
    required String section,
    required IconData icon,
    required String title,
    required String description,
    Widget? footer,
  }) {
    final options = _catalog.section(section);
    final active = options.where((o) => _answer(order, section, o.key)).length;

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderSectionHeader(
            icon: icon,
            title: title,
            trailing: '$active/${options.length}',
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              description,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          for (var i = 0; i < options.length; i++)
            ServiceOrderSwitchTile(
              icon: ServiceOrderIcons.of(options[i].key),
              label: options[i].name,
              value: _answer(order, section, options[i].key),
              onChanged: (value) => setState(
                () => _answers[_key(section, options[i].key)] = value,
              ),
              showDivider: i < options.length - 1,
            ),
          if (footer != null) footer,
        ],
      ),
    );
  }

  Widget _buildPhotos(
    ServiceOrderRecord order,
    String title,
    List<ServiceOrderOption> options,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();
    final missing = options
        .where((o) =>
            o.required &&
            !_photos.containsKey(o.key) &&
            order.file(o.key) == null)
        .length;
    final taken = options
        .where((o) => _photos.containsKey(o.key) || order.file(o.key) != null)
        .length;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                color: ServiceOrderColors.mutedText,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  options.any((o) => o.required) ? title : '$title (opcional)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$taken/${options.length}',
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
              for (final option in options)
                ServiceOrderPhotoSlot(
                  option.key,
                  option.required ? '${option.name} *' : option.name,
                  ServiceOrderIcons.of(option.key),
                ),
            ],
            photos: _photos,
            remoteUrls: {
              for (final option in options)
                if (order.file(option.key) case final file?) file.key: file.url,
            },
            crossAxisCount: options.length == 1 ? 1 : 2,
            childAspectRatio: options.length == 1 ? 2.4 : 1.35,
            onChanged: (slot, bytes) => setState(() {
              bytes == null ? _photos.remove(slot) : _photos[slot] = bytes;
            }),
          ),
          if (_showErrors && missing > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                missing == 1
                    ? 'Falta 1 fotografía obligatoria.'
                    : 'Faltan $missing fotografías obligatorias.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
