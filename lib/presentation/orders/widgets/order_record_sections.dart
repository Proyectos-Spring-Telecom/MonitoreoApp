import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_message.dart';
import '../../../domain/entities/service_order.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../service_order/widgets/remote_image.dart';
import '../../service_order/widgets/service_order_icons.dart';
import '../../service_order/widgets/service_order_summary.dart';
import '../../service_order/widgets/service_order_ui.dart';
import '../order_models.dart';

/// Contenido de una orden tal como la devuelve el API. Lo usan el Resumen del
/// flujo (con "Editar" en cada sección) y el detalle del historial.
class OrderRecordSections extends StatelessWidget {
  final ServiceOrderRecord order;
  final OrderNames names;
  final VoidCallback? onEditVehicle;
  final VoidCallback? onEditInstallation;
  final VoidCallback? onEditChecklist;
  final VoidCallback? onEditTests;

  /// Completa el equipo cuando el API no manda los textos.
  final InstallationSummary? equipmentFallback;

  const OrderRecordSections({
    super.key,
    required this.order,
    required this.names,
    this.equipmentFallback,
    this.onEditVehicle,
    this.onEditInstallation,
    this.onEditChecklist,
    this.onEditTests,
  });

  ServiceType? get _type => order.type;

  bool get _isInstallation => _type == ServiceType.instalacion;

  List<String> _selected(String section) => names
      .answers(order, section)
      .where((answer) => answer.value)
      .map((answer) => answer.name)
      .toList();

  IconData _optionIcon(String section, String name) => ServiceOrderIcons.of(
        names
                .answers(order, section)
                .where((answer) => answer.name == name)
                .firstOrNull
                ?.key ??
            '',
      );

  List<ServiceOrderFile> _photos(bool Function(String key) test) => order.files
      .where((file) =>
          file.key != ServiceOrderSection.signatureClient &&
          file.key != ServiceOrderSection.signatureTechnician &&
          test(file.key))
      .toList();

  @override
  Widget build(BuildContext context) {
    final failures = _photos(
      (key) => key.startsWith(ServiceOrderSection.failurePhotoPrefix),
    );
    final existing = _photos(
      (key) => key == ServiceOrderSection.existingEquipmentPhoto,
    );
    final dashboard = _photos(
      (key) =>
          !key.startsWith(ServiceOrderSection.failurePhotoPrefix) &&
          key != ServiceOrderSection.existingEquipmentPhoto,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGeneralCard(context),
        const SizedBox(height: 16),
        _buildVehicleCard(existing),
        const SizedBox(height: 16),
        SummaryCard(
          icon: Icons.checklist_outlined,
          title: 'Checklist del vehículo',
          onEdit: onEditChecklist,
          children: [
            SummaryChipGroup(
              'Vehículo cuenta con',
              _selected(ServiceOrderSection.vehicleFeatures),
              color: SummaryTagColors.features,
              iconOf: (name) =>
                  _optionIcon(ServiceOrderSection.vehicleFeatures, name),
            ),
            SummaryChipGroup(
              'Funcionamiento del vehículo',
              _selected(ServiceOrderSection.vehicleOperation),
              color: SummaryTagColors.operation,
              iconOf: (name) =>
                  _optionIcon(ServiceOrderSection.vehicleOperation, name),
            ),
            if (!_isInstallation)
              SummaryChipGroup(
                'Fallas encontradas del equipo',
                _selected(ServiceOrderSection.equipmentFailures),
                color: SummaryTagColors.failures,
                iconOf: (name) =>
                    _optionIcon(ServiceOrderSection.equipmentFailures, name),
              ),
            OrderRemotePhotos(
              title: 'Fotografías del tablero',
              files: dashboard,
              names: names,
            ),
            if (!_isInstallation)
              OrderRemotePhotos(
                title: 'Imágenes extras de fallas',
                files: failures,
                names: names,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTestsCard(),
        const SizedBox(height: 16),
        SummaryCard(
          icon: Icons.draw_outlined,
          title: 'Firmas',
          onEdit: onEditTests,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OrderRemoteSignature(
                    'Cliente',
                    order.file(ServiceOrderSection.signatureClient),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OrderRemoteSignature(
                    'Técnico',
                    order.file(ServiceOrderSection.signatureTechnician),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralCard(BuildContext context) {
    final unit = order.unitLabel;
    return SummaryCard(
      icon: Icons.info_outline,
      title: 'Información general',
      children: [
        SummaryHeroRow(
          icon: Icons.business_outlined,
          caption: 'Cliente',
          title: names.client(order),
          subtitle: unit,
        ),
        SummaryHeroRow(
          icon: Icons.person_outline,
          caption: 'Técnico',
          title: names.technician(order.technicianId),
          subtitle: names.technicianEmail(order.technicianId),
        ),
        SummaryInfoRow('Folio', order.folio),
        SummaryInfoRow('Tipo de servicio', orderTypeWithScheduled(order)),
        SummaryInfoRow('Cita', orderAppointment(order)),
        if (order.scheduledBy != null)
          SummaryInfoRow('Programó', order.scheduledBy!),
        if (order.crmReference != null)
          SummaryInfoRow('Referencia CRM', order.crmReference!),
        SummaryInfoRow('Fecha de captura', orderDateTime(order.capturedAt)),
        if (order.closedAt != null)
          SummaryInfoRow('Cierre', orderDateTime(order.closedAt)),
        _buildLocation(context),
      ],
    );
  }

  Widget _buildLocation(BuildContext context) {
    final lat = order.lat;
    final lng = order.lng;
    if (lat == null || lng == null) {
      return const SummaryInfoRow('Lugar', 'Sin ubicación', isLast: true);
    }
    return Row(
      children: [
        Expanded(
          child: SummaryInfoRow(
            'Lugar',
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            isLast: true,
          ),
        ),
        TextButton.icon(
          onPressed: () => _openMap(context, lat, lng),
          style: TextButton.styleFrom(
            foregroundColor: ServiceOrderColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Mapa'),
        ),
      ],
    );
  }

  static Future<void> _openMap(
    BuildContext context,
    double lat,
    double lng,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppMessage.error(context, 'No se pudo abrir el mapa');
    }
  }

  Widget _buildVehicleCard(List<ServiceOrderFile> existing) {
    final type = _type;
    String value(String? text) => summaryOr(text);
    final outgoing = OutgoingStatus.fromId(order.outgoingStatus);
    final removal = RemovalStatus.fromId(order.removalStatus);

    final equipment = (order.equipment ?? const InstallationSummary())
        .withFallback(equipmentFallback);

    // En un cambio se muestran los dos: lo que entra y lo que sale.
    final changesDevice = type == ServiceType.cEquipo;
    final changesSim = type == ServiceType.cSim;
    final current = order.installation ?? const InstallationSummary();
    final incoming = (order.resultingInstallation ??
            order.newEquipment ??
            const InstallationSummary())
        .withFallback(equipmentFallback);
    final closed = order.status == ServiceOrderStatus.cerrada;

    final rows = <(String, String)>[
      if (type?.takesOutgoingStatus ?? false)
        ('Destino del que sale', value(outgoing?.label)),
      if (type == ServiceType.desinstalacion)
        ('Estatus de baja', value(removal?.label)),
      if (order.authorization != null)
        (
          'Autorización',
          switch (order.authorization!) {
            AuthorizationStatus.pendiente => 'Pendiente',
            AuthorizationStatus.autorizada => 'Autorizada',
            AuthorizationStatus.rechazada => 'Rechazada',
          }
        ),
    ];

    return SummaryCard(
      icon: Icons.memory_outlined,
      title: _isInstallation ? 'Vehículo e instalación' : 'Instalación',
      onEdit: onEditInstallation,
      children: [
        SummaryInfoRow('Vehículo', value(order.vehicleLabel)),
        SummaryInfoRow(
          'Tipo de equipo',
          value(changesDevice
              ? incoming.equipmentType ?? current.equipmentType
              : equipment.equipmentType),
        ),
        if (changesDevice) ...[
          _EquipmentDetail(
            icon: Icons.memory_outlined,
            label: 'Dispositivo nuevo',
            text: incoming.device,
            change: _Change.incoming,
          ),
          _EquipmentDetail(
            icon: Icons.memory_outlined,
            label: closed ? 'Dispositivo retirado' : 'Dispositivo a quitar',
            text: current.device,
            change: _Change.outgoing,
          ),
        ] else
          _EquipmentDetail(
            icon: Icons.memory_outlined,
            label: 'Dispositivo',
            text: changesSim
                ? current.device ?? equipment.device
                : equipment.device,
          ),
        if (changesSim) ...[
          _EquipmentDetail(
            icon: Icons.sim_card_outlined,
            label: 'SIM nueva',
            text: incoming.sim,
            change: _Change.incoming,
          ),
          _EquipmentDetail(
            icon: Icons.sim_card_outlined,
            label: closed ? 'SIM retirada' : 'SIM a quitar',
            text: current.sim,
            change: _Change.outgoing,
          ),
        ] else
          _EquipmentDetail(
            icon: Icons.sim_card_outlined,
            label: 'SIM',
            text: changesDevice ? current.sim ?? equipment.sim : equipment.sim,
          ),
        for (final (label, text) in rows) SummaryInfoRow(label, text),
        OrderRemotePhotos(
          title: 'Fotografías del vehículo',
          files: order.vehiclePhotos,
          names: names,
        ),
        if (onEditVehicle != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onEditVehicle,
              style: TextButton.styleFrom(
                foregroundColor: ServiceOrderColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const Icon(Icons.directions_car_outlined, size: 18),
              label: const Text('Editar vehículo'),
            ),
          ),
        if (existing.isNotEmpty)
          OrderRemotePhotos(
            title: 'Equipo encontrado',
            files: existing,
            names: names,
          ),
      ],
    );
  }

  Widget _buildTestsCard() {
    final catalog = names.catalog;
    final options = catalog?.testsFor(order) ??
        [
          for (final test in order.tests)
            ServiceOrderOption(key: test.key, name: humanizeKey(test.key)),
        ];

    return SummaryCard(
      icon: Icons.task_alt,
      title: 'Pruebas',
      onEdit: onEditTests,
      children: [
        for (final option in options)
          if (order.technicianAnswersTests)
            SummaryTestRow(
              option.name,
              switch (order.answer(ServiceOrderSection.tests, option.key)) {
                true => TestStatus.correcta,
                false => TestStatus.fallida,
                null => null,
              },
              emptyLabel: 'Sin responder',
            )
          else
            SummaryTestRow(
              option.name,
              order.test(option.key)?.status,
              detail: testDetail(order.test(option.key)),
            ),
        SummaryInfoRow('Monitorista', names.monitor(order.monitorId)),
        SummaryInfoRow(
          'Técnico',
          names.technician(order.technicianId),
          isLast: true,
        ),
        SummaryTextBlock('Observaciones', order.observations ?? ''),
      ],
    );
  }
}

/// En un cambio: lo que se instala o lo que se quita.
enum _Change {
  incoming(ServiceOrderColors.success, 'Se instala'),
  outgoing(CircleStatusIcon.removed, 'Se quita');

  const _Change(this.color, this.semanticLabel);

  final Color color;
  final String semanticLabel;

  Widget get badge => switch (this) {
        _Change.incoming =>
          CircleStatusIcon.check(semanticLabel: semanticLabel),
        _Change.outgoing =>
          CircleStatusIcon.cross(semanticLabel: semanticLabel),
      };
}

/// Dispositivo o SIM a todo lo ancho. El texto del API viene como
/// "Suntech ST210 - IMEI 3333 - Serie: 0009": la primera parte es el título
/// y cada dato va en su renglón.
class _EquipmentDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? text;

  /// En un cambio, marca con ✓ lo que entra y con ✕ lo que sale.
  final _Change? change;

  const _EquipmentDetail({
    required this.icon,
    required this.label,
    required this.text,
    this.change,
  });

  static final RegExp _keyed = RegExp(
    r'^(IMEI|ICCID|No\.? ?Serie|Serie|Tel[eé]fono|Tel)\b\s*:?\s*(.+)$',
    caseSensitive: false,
  );

  static String _keyLabel(String key) {
    final lower = key.toLowerCase();
    if (lower.startsWith('tel')) return 'Teléfono';
    if (lower.contains('serie')) return 'Serie';
    return key.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return SummaryInfoRow(label, summaryOr(null));

    String? title;
    final details = <(String, String)>[];
    for (final part in value.split(' - ')) {
      final piece = part.trim();
      if (piece.isEmpty) continue;
      final match = _keyed.firstMatch(piece);
      if (match != null) {
        details.add((_keyLabel(match.group(1)!), match.group(2)!.trim()));
      } else if (title == null) {
        title = piece;
      } else {
        title = '$title - $piece';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ServiceOrderColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ServiceOrderColors.field,
              borderRadius: BorderRadius.circular(12),
              border: change == null
                  ? null
                  : Border.all(color: change!.color.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _content(title, details)),
                if (change case final change?) ...[
                  const SizedBox(width: 8),
                  change.badge,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(String? title, List<(String, String)> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Row(
            children: [
              Icon(icon, size: 18, color: ServiceOrderColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        for (final (index, (key, detail)) in details.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: index == 0 && title == null ? 0 : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: ServiceOrderColors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    detail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Validó Ana López · 30 Oct, 2026 · 10:45 · Nota: …".
String? testDetail(ServiceOrderTest? test) {
  if (test == null) return null;
  final parts = <String>[
    if (test.validatedBy != null) 'Validó ${test.validatedBy}',
    if (test.validatedAt != null) orderDateTime(test.validatedAt),
    if (test.operatorNote != null) 'Nota: ${test.operatorNote}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class OrderRemotePhotos extends StatelessWidget {
  final String title;
  final List<ServiceOrderFile> files;
  final OrderNames names;

  const OrderRemotePhotos({
    super.key,
    required this.title,
    required this.files,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummarySubsectionTitle(title, trailing: '${files.length}'),
        if (files.isEmpty)
          const Text(
            'Sin fotografías',
            style: TextStyle(color: ServiceOrderColors.hintText, fontSize: 14),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final file in files)
                _buildTile(
                  context,
                  file,
                  file.name ??
                      names.option(ServiceOrderSection.photos, file.key),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTile(BuildContext context, ServiceOrderFile file, String label) {
    return GestureDetector(
      onTap: () => showRemoteImagePreview(context, label, file.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteImage(file.url),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                  colors: [Color(0x00000000), Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 5,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderRemoteSignature extends StatelessWidget {
  final String label;
  final ServiceOrderFile? file;

  const OrderRemoteSignature(this.label, this.file, {super.key});

  @override
  Widget build(BuildContext context) {
    final signature = file;
    final title = 'Firma del ${label.toLowerCase()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: signature == null
              ? null
              : () => showRemoteImagePreview(context, title, signature.url),
          child: Container(
            height: 110,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  signature == null ? ServiceOrderColors.field : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: signature == null
                ? const Center(
                    child: Text(
                      'Sin firma',
                      style: TextStyle(
                        color: ServiceOrderColors.hintText,
                        fontSize: 14,
                      ),
                    ),
                  )
                : RemoteImage(signature.url, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ServiceOrderColors.mutedText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Estado de la orden en una línea, con su color.
class OrderStatusBanner extends StatelessWidget {
  final ServiceOrderRecord order;

  const OrderStatusBanner(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final (title, message) = switch (status) {
      ServiceOrderStatus.programada => (
          'Orden programada',
          'Inicia el servicio cuando llegues con el cliente.',
        ),
      ServiceOrderStatus.borrador => (
          'Orden en curso',
          'Aún no se registra. Revisa lo pendiente para poder cerrarla.',
        ),
      ServiceOrderStatus.cerrada => (
          'Orden cerrada',
          order.closedAt == null
              ? 'La orden quedó registrada y ya no se puede modificar.'
              : 'Se registró el ${orderDateTime(order.closedAt)} y ya no '
                  'se puede modificar.',
        ),
      ServiceOrderStatus.noCumplida => (
          'Orden no cumplida',
          order.reasonKey == null
              ? 'El servicio no se pudo realizar.'
              : 'Motivo: ${humanizeKey(order.reasonKey!)}.',
        ),
      ServiceOrderStatus.cancelada => (
          'Orden cancelada',
          'Operación canceló la orden; no modificó la instalación.',
        ),
      null => ('Sin estatus', 'El servidor no indicó el estatus de la orden.'),
    };

    return ServiceOrderStepNotice(
      icon: status?.icon ?? Icons.help_outline,
      title: title,
      message: message,
      color: status?.color ?? ServiceOrderColors.mutedText,
    );
  }
}

/// `faltantesParaCerrar` tal cual los manda el servidor.
class OrderMissingCard extends StatelessWidget {
  final List<String> missing;

  const OrderMissingCard(this.missing, {super.key});

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      icon: Icons.pending_actions_outlined,
      title: 'Pendiente para cerrar',
      children: [
        for (final item in missing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: ServiceOrderColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: ServiceOrderColors.mutedText,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
