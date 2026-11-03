import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/service_order.dart';
import 'service_order_fields.dart';
import 'service_order_ui.dart';

typedef NotCompletedChoice = ({String reasonKey, String? observations});

/// Pide el motivo de no cumplida (solo los del técnico) y, si el motivo lo
/// requiere, las observaciones (§11).
Future<NotCompletedChoice?> showNotCompletedSheet(
  BuildContext context,
  List<NotCompletedReason> reasons,
) {
  return showModalBottomSheet<NotCompletedChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ServiceOrderColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NotCompletedSheet(reasons: reasons),
  );
}

class _NotCompletedSheet extends StatefulWidget {
  final List<NotCompletedReason> reasons;

  const _NotCompletedSheet({required this.reasons});

  @override
  State<_NotCompletedSheet> createState() => _NotCompletedSheetState();
}

class _NotCompletedSheetState extends State<_NotCompletedSheet> {
  final _observationsController = TextEditingController();
  NotCompletedReason? _selected;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _observationsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  bool get _needsObservations => _selected?.requiresObservations ?? false;

  void _confirm() {
    final reason = _selected;
    final observations = _observationsController.text.trim();
    if (reason == null || (_needsObservations && observations.isEmpty)) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop((
      reasonKey: reason.key,
      observations: observations.isEmpty ? null : observations,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'No se pudo realizar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'La orden quedará como no cumplida y ya no se podrá editar.',
                style: TextStyle(
                  color: ServiceOrderColors.mutedText,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.reasons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No hay motivos disponibles. Comunícate con operación.',
                    style: TextStyle(color: ServiceOrderColors.mutedText),
                  ),
                ),
              RadioGroup<NotCompletedReason>(
                groupValue: _selected,
                onChanged: (value) => setState(() => _selected = value),
                child: Column(
                  children: [
                    for (final reason in widget.reasons)
                      RadioListTile<NotCompletedReason>(
                        value: reason,
                        activeColor: ServiceOrderColors.accent,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_showErrors && _selected == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Elige un motivo',
                    style: TextStyle(color: AppColors.error, fontSize: 12.5),
                  ),
                ),
              const SizedBox(height: 8),
              ServiceOrderTextField(
                label: 'Observaciones',
                hint: _needsObservations
                    ? 'Describe qué pasó'
                    : 'Agrega observaciones (opcional)',
                controller: _observationsController,
                isRequired: _needsObservations,
                errorText: _showErrors &&
                        _needsObservations &&
                        _observationsController.text.trim().isEmpty
                    ? 'Este motivo requiere observaciones'
                    : null,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                isLast: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.reasons.isEmpty ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Marcar como no cumplida',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
