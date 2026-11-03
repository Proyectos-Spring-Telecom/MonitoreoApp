import 'package:flutter/material.dart';
import 'service_order_ui.dart';

enum _StepState { completed, current, pending }

class ServiceOrderStepper extends StatefulWidget {
  final List<String> steps;

  /// Paso que se resalta como actual; fuera de rango si no hay ninguno.
  final int currentStep;
  final Set<int> completedSteps;
  final ValueChanged<int>? onStepTapped;

  const ServiceOrderStepper({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.completedSteps,
    this.onStepTapped,
  });

  @override
  State<ServiceOrderStepper> createState() => _ServiceOrderStepperState();
}

class _ServiceOrderStepperState extends State<ServiceOrderStepper> {
  static const Color _completed = Color(0xFF34C38F);
  static const Color _pending = Color(0x80FFFFFF);

  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.steps.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent(false));
  }

  @override
  void didUpdateWidget(ServiceOrderStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.length != widget.steps.length) {
      _keys = List.generate(widget.steps.length, (_) => GlobalKey());
    }
    if (oldWidget.currentStep != widget.currentStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent(true));
    }
  }

  void _revealCurrent(bool animate) {
    if (widget.currentStep < 0 || widget.currentStep >= _keys.length) return;
    final context = _keys[widget.currentStep].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  _StepState _stateOf(int index) {
    if (widget.completedSteps.contains(index)) return _StepState.completed;
    if (index == widget.currentStep) return _StepState.current;
    return _StepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ServiceOrderColors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    for (var i = 0; i < widget.steps.length; i++) ...[
                      if (i > 0) Expanded(child: _buildConnector(i - 1)),
                      _buildStep(i),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnector(int fromIndex) {
    final isDone = widget.completedSteps.contains(fromIndex);
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDone ? _completed : const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildStep(int index) {
    final state = _stateOf(index);
    final canTap = widget.onStepTapped != null;

    final (Color? background, Color? border, Color foreground, IconData icon) =
        switch (state) {
      _StepState.completed => (
          const Color(0x2934C38F),
          const Color(0xB334C38F),
          Colors.white,
          Icons.check_circle_outline,
        ),
      _StepState.current => (
          ServiceOrderColors.accentBackground,
          ServiceOrderColors.accent,
          Colors.white,
          Icons.radio_button_unchecked,
        ),
      _StepState.pending => (
          null,
          null,
          _pending,
          Icons.radio_button_unchecked
        ),
    };

    return GestureDetector(
      key: _keys[index],
      onTap: canTap ? () => widget.onStepTapped!(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border ?? Colors.transparent),
          boxShadow: border == null
              ? null
              : [
                  BoxShadow(
                    color: border.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: state == _StepState.current
                  ? ServiceOrderColors.accent
                  : foreground,
            ),
            const SizedBox(width: 6),
            Text(
              widget.steps[index],
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: state == _StepState.pending
                    ? FontWeight.w500
                    : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
