import 'package:flutter/material.dart';
import '../../../core/utils/password_rules.dart';

/// Medidor de seguridad y lista de requisitos de [PasswordRules], que se
/// actualizan mientras el usuario escribe.
class PasswordStrengthPanel extends StatelessWidget {
  static const Color _green = Color(0xFF34C38F);
  static const Color _amber = Color(0xFFF5A524);
  static const Color _red = Color(0xFFF26D6D);
  static const Color _mutedText = Color(0xB3FFFFFF);
  static const Color _hintText = Color(0x80FFFFFF);
  static const Color _track = Color(0xFF2A2940);

  final String password;
  final Color backgroundColor;

  const PasswordStrengthPanel({
    super.key,
    required this.password,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final rules = PasswordRules.all;
    final met = PasswordRules.metCount(password);
    final hasText = password.isNotEmpty;
    final (label, color) = !hasText
        ? ('Sin evaluar', _hintText)
        : met == rules.length
            ? ('Segura', _green)
            : met >= 3
                ? ('Media', _amber)
                : ('Débil', _red);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Seguridad de la contraseña',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < rules.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasText && i < met ? color : _track,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final rule in rules)
            _RequirementRow(
              label: rule.label,
              isMet: rule.isMet(password),
              metColor: _green,
              mutedColor: _mutedText,
              hintColor: _hintText,
            ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool isMet;
  final Color metColor;
  final Color mutedColor;
  final Color hintColor;

  const _RequirementRow({
    required this.label,
    required this.isMet,
    required this.metColor,
    required this.mutedColor,
    required this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              isMet ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(isMet),
              size: 18,
              color: isMet ? metColor : hintColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isMet ? Colors.white : mutedColor,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
