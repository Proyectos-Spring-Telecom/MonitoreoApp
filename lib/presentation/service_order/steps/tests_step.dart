import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/catalog_item.dart';
import '../../../domain/entities/service_order.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../controllers/auth_controller.dart';
import '../../orders/widgets/order_record_sections.dart';
import '../service_order_flow_controller.dart';
import '../widgets/remote_image.dart';
import '../widgets/service_order_fields.dart';
import '../widgets/service_order_icons.dart';
import '../widgets/service_order_summary.dart';
import '../widgets/service_order_ui.dart';
import 'flow_action.dart';

/// Pruebas, monitorista, observaciones y firmas. En órdenes programadas el
/// técnico pide cada prueba y el operador pone el resultado (§9); en una
/// desinstalación las contesta el técnico.
class TestsStep extends StatefulWidget {
  const TestsStep({super.key});

  @override
  State<TestsStep> createState() => _TestsStepState();
}

class _TestsStepState extends State<TestsStep> {
  final _infoKey = GlobalKey();
  final _signaturesKey = GlobalKey();
  final _observationsController = TextEditingController();
  final Map<String, bool> _testAnswers = {};
  final Map<String, SignatureController> _signatures = {
    ServiceOrderSection.signatureClient: _signatureController(),
    ServiceOrderSection.signatureTechnician: _signatureController(),
  };

  /// Firmas guardadas que el técnico decidió repetir.
  final Set<String> _resign = {};
  String? _monitorId;
  bool _showErrors = false;

  static SignatureController _signatureController() => SignatureController(
        penStrokeWidth: 2.5,
        penColor: Colors.white,
        exportPenColor: Colors.black,
        exportBackgroundColor: Colors.white,
      );

  @override
  void initState() {
    super.initState();
    final order = context.read<ServiceOrderFlowController>().order!;
    _monitorId = order.monitorId;
    _observationsController.text = order.observations ?? '';
    for (final answer in order.answersOf(ServiceOrderSection.tests)) {
      _testAnswers[answer.key] = answer.value;
    }
    _observationsController.addListener(_onChanged);
    for (final controller in _signatures.values) {
      controller.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _observationsController.dispose();
    for (final controller in _signatures.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _observationsRequired(ServiceOrderRecord order) =>
      order.answer(
        ServiceOrderSection.equipmentFailures,
        ServiceOrderSection.otherFailure,
      ) ??
      false;

  bool _hasSignature(ServiceOrderRecord order, String key) =>
      _signatures[key]!.isNotEmpty ||
      (order.file(key) != null && !_resign.contains(key));

  List<(String, GlobalKey)> _missing(
    ServiceOrderRecord order,
    ServiceOrderCatalog catalog,
  ) =>
      [
        if (_monitorId == null) ('Monitorista', _infoKey),
        if (_observationsRequired(order) &&
            _observationsController.text.trim().isEmpty)
          ('Observaciones (describe la falla "Otro")', _infoKey),
        for (final option in catalog.signatureOptions)
          if (option.required && !_hasSignature(order, option.key))
            (option.name, _signaturesKey),
      ];

  Future<void> _requestTest(ServiceOrderOption test) async {
    final controller = context.read<ServiceOrderFlowController>();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _TestNoteDialog(test: test),
    );
    if (note == null || !mounted) return;
    await runOrderAction(
      context,
      () => controller.requestTest(test.key, observations: note),
      success: 'Prueba solicitada. Espera el resultado del operador.',
    );
  }

  Future<void> _handleContinue() async {
    final controller = context.read<ServiceOrderFlowController>();
    final order = controller.order!;
    final catalog = controller.catalog!;
    final missing = _missing(order, catalog);
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      if (missing.first.$2.currentContext case final target?) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          alignment: 0.05,
        );
      }
      showServiceOrderMessage(
        context,
        'Completa: ${missing.map((field) => field.$1).join(', ')}.',
        isError: true,
      );
      return;
    }

    final names = {
      for (final option in catalog.signatureOptions) option.key: option.name,
    };
    final ok = await runOrderAction(context, () async {
      final signatures = <String, (String, Uint8List)>{};
      for (final MapEntry(:key, value: pad) in _signatures.entries) {
        if (pad.isEmpty) continue;
        final bytes = await pad.toPngBytes();
        if (bytes != null) signatures[key] = (names[key] ?? key, bytes);
      }
      await controller.saveClosingData(
        monitorId: _monitorId!,
        observations: _observationsController.text,
        testAnswers: order.technicianAnswersTests
            ? [
                for (final test in catalog.testsFor(order))
                  ServiceOrderAnswer(
                    ServiceOrderSection.tests,
                    test.key,
                    _testAnswers[test.key] ?? false,
                  ),
              ]
            : const [],
        signatures: signatures,
      );
    });
    if (ok && mounted) controller.next();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServiceOrderFlowController>();
    final order = controller.order!;
    final catalog = controller.catalog!;

    return ServiceOrderFormBody(
      action: ServiceOrderBottomButton(
        label: controller.isBusy ? 'Guardando...' : 'Continuar',
        isLoading: controller.isBusy,
        onPressed: _handleContinue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderStepNotice(
            icon: Icons.fact_check_outlined,
            title: 'Pruebas y firmas',
            message: order.technicianAnswersTests
                ? 'Registra el resultado de las pruebas, el monitorista y las '
                    'firmas.'
                : 'Pide cada prueba: el operador de monitoreo pone el '
                    'resultado. Al menos una debe resultar correcta.',
          ),
          const SizedBox(height: 14),
          const ServiceOrderRequiredLegend(),
          const SizedBox(height: 14),
          _buildTestsCard(controller, order, catalog),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _infoKey,
            child: _buildInfoCard(order, catalog.monitors),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _signaturesKey,
            child: _buildSignaturesCard(order, catalog),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsCard(
    ServiceOrderFlowController controller,
    ServiceOrderRecord order,
    ServiceOrderCatalog catalog,
  ) {
    final tests = catalog.testsFor(order);
    final byTechnician = order.technicianAnswersTests;

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderSectionHeader(
            icon: Icons.task_alt,
            title: 'Pruebas',
            trailing: byTechnician
                ? null
                : '${tests.where((t) => order.test(t.key)?.status == TestStatus.correcta).length}'
                    '/${tests.length}',
          ),
          if (!order.hasImmobilizer)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'El vehículo no tiene inmovilizador: no se pide el paro de '
                'motor.',
                style: TextStyle(
                  color: ServiceOrderColors.hintText,
                  fontSize: 13,
                ),
              ),
            ),
          if (controller.isPolling)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ServiceOrderColors.warning,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esperando al operador; se consulta automáticamente.',
                      style: TextStyle(
                        color: ServiceOrderColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < tests.length; i++)
            if (byTechnician)
              ServiceOrderSwitchTile(
                icon: ServiceOrderIcons.of(tests[i].key),
                label: tests[i].name,
                value: _testAnswers[tests[i].key] ?? false,
                onChanged: (value) =>
                    setState(() => _testAnswers[tests[i].key] = value),
                showDivider: i < tests.length - 1,
              )
            else
              _OperatorTestTile(
                option: tests[i],
                test: order.test(tests[i].key),
                enabled: !controller.isBusy,
                onRequest: () => _requestTest(tests[i]),
              ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ServiceOrderRecord order, List<CatalogItem> monitors) {
    final required = _observationsRequired(order);
    final user = context.watch<AuthController>().user;
    String? monitorName(String id) =>
        monitors.where((monitor) => monitor.id == id).firstOrNull?.name;

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.badge_outlined,
            title: 'Información adicional',
          ),
          const SizedBox(height: 16),
          ServiceOrderDropdown(
            label: 'Monitorista',
            hint: monitors.isEmpty
                ? 'Sin monitoristas disponibles'
                : 'Selecciona un monitorista',
            isRequired: true,
            value: _monitorId,
            items: monitors.map((monitor) => monitor.id).toList(),
            itemLabel: (id) => monitorName(id) ?? id,
            errorText: _showErrors && _monitorId == null
                ? 'El monitorista es obligatorio'
                : null,
            onChanged: monitors.isEmpty
                ? null
                : (value) => setState(() => _monitorId = value),
          ),
          ServiceOrderReadOnlyRow('Técnico', user?.name),
          const SizedBox(height: 14),
          ServiceOrderTextField(
            label: 'Observaciones',
            hint: required
                ? 'Describe la falla "Otro" que marcaste en el checklist'
                : 'Agrega observaciones de la orden (opcional)',
            controller: _observationsController,
            isRequired: required,
            errorText: _showErrors &&
                    required &&
                    _observationsController.text.trim().isEmpty
                ? 'Describe la falla "Otro"'
                : null,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturesCard(
    ServiceOrderRecord order,
    ServiceOrderCatalog catalog,
  ) {
    final options = catalog.signatureOptions;
    final signed = options.where((o) => _hasSignature(order, o.key)).length;

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceOrderSectionHeader(
            icon: Icons.draw_outlined,
            title: 'Firmas',
            isRequired: options.any((o) => o.required),
            trailing: '$signed/${options.length}',
          ),
          for (final option in options) ...[
            const SizedBox(height: 16),
            _buildSignatureField(order, option),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureField(
    ServiceOrderRecord order,
    ServiceOrderOption option,
  ) {
    final pad = _signatures[option.key];
    if (pad == null) return const SizedBox.shrink();
    final saved = _resign.contains(option.key) ? null : order.file(option.key);
    final showSaved = saved != null && pad.isEmpty;
    final isSigned = pad.isNotEmpty || showSaved;
    final showError = _showErrors && option.required && !isSigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: option.name,
                  children: [
                    if (option.required)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: AppColors.error),
                      ),
                  ],
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSigned)
              TextButton.icon(
                onPressed: showSaved
                    ? () => setState(() => _resign.add(option.key))
                    : pad.clear,
                style: TextButton.styleFrom(
                  foregroundColor: ServiceOrderColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  showSaved ? Icons.edit_outlined : Icons.refresh,
                  size: 18,
                ),
                label: Text(showSaved ? 'Firmar de nuevo' : 'Limpiar'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: showSaved ? Colors.white : ServiceOrderColors.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showError
                  ? AppColors.error
                  : isSigned
                      ? ServiceOrderColors.accent
                      : ServiceOrderColors.divider,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: showSaved
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: RemoteImage(saved.url, fit: BoxFit.contain),
                  )
                : Stack(
                    children: [
                      Signature(
                        controller: pad,
                        backgroundColor: Colors.transparent,
                        width: double.infinity,
                        height: 180,
                      ),
                      if (!isSigned)
                        const IgnorePointer(
                          child: Center(
                            child: Text(
                              'Firme aquí',
                              style: TextStyle(
                                color: ServiceOrderColors.hintText,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'La firma es obligatoria',
              style: TextStyle(color: AppColors.error, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

/// Una prueba validada por el operador: estatus, quién la validó y el botón
/// para pedirla (o volver a pedirla si falló). Una anulada se ve en gris.
class _OperatorTestTile extends StatelessWidget {
  final ServiceOrderOption option;
  final ServiceOrderTest? test;
  final bool enabled;
  final VoidCallback onRequest;

  const _OperatorTestTile({
    required this.option,
    required this.test,
    required this.enabled,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final status = test?.status;
    final canRequest = status == null || status == TestStatus.fallida;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryTestRow(
          option.name,
          status,
          detail: [
            if (test?.technicianNote case final note?) 'Tu nota: $note',
            if (testDetail(test) case final detail?) detail,
          ].join('\n'),
        ),
        if (canRequest)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled ? onRequest : null,
              style: TextButton.styleFrom(
                foregroundColor: ServiceOrderColors.accent,
              ),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(
                status == TestStatus.fallida
                    ? 'Volver a solicitar'
                    : 'Solicitar prueba',
              ),
            ),
          ),
      ],
    );
  }
}

/// Nota opcional para el operador ("presioné el pánico 10:42"). Devuelve el
/// texto (puede ser vacío) o `null` si se canceló.
class _TestNoteDialog extends StatefulWidget {
  final ServiceOrderOption test;

  const _TestNoteDialog({required this.test});

  @override
  State<_TestNoteDialog> createState() => _TestNoteDialogState();
}

class _TestNoteDialogState extends State<_TestNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEngineStop = widget.test.key == ServiceOrderSection.engineStopTest;
    return AlertDialog(
      backgroundColor: ServiceOrderColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Solicitar: ${widget.test.name}',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEngineStop
                ? 'Se pedirá al operador que ejecute el paro de motor.'
                : 'El operador de monitoreo verá la solicitud y pondrá el '
                    'resultado.',
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ServiceOrderTextField(
            label: 'Nota para el operador',
            hint: 'Ej: presioné el pánico 10:42 (opcional)',
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            isLast: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: TextButton.styleFrom(
            foregroundColor: ServiceOrderColors.accent,
          ),
          child: const Text('Solicitar'),
        ),
      ],
    );
  }
}
