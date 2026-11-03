import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/service_order_record.dart';
import 'service_order_icons.dart';
import 'service_order_ui.dart';

const String summaryEmpty = '—';

String summaryOr(String? value) =>
    value == null || value.trim().isEmpty ? summaryEmpty : value;

String summaryJoin(List<String?> values, String separator) {
  final parts = values.whereType<String>().where((v) => v.isNotEmpty);
  return parts.isEmpty ? summaryEmpty : parts.join(separator);
}

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onEdit;
  final List<Widget> children;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ServiceOrderSectionHeader(icon: icon, title: title),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: ServiceOrderColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class SummaryHeroRow extends StatelessWidget {
  final IconData icon;
  final String caption;
  final String title;
  final String? subtitle;

  const SummaryHeroRow({
    super.key,
    required this.icon,
    required this.caption,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ServiceOrderColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ServiceOrderColors.accentBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ServiceOrderColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: const TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ServiceOrderColors.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const SummaryInfoRow(this.label, this.value,
      {super.key, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: ServiceOrderColors.divider),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto, color e ícono de cada estatus de prueba; `null` = no se ha pedido.
extension TestStatusStyle on TestStatus? {
  String labelOr(String empty) => this?.label ?? empty;

  Color get color => switch (this) {
        TestStatus.correcta => ServiceOrderColors.success,
        TestStatus.fallida => AppColors.error,
        TestStatus.solicitada => ServiceOrderColors.warning,
        TestStatus.anulada || null => ServiceOrderColors.hintText,
      };

  IconData get icon => switch (this) {
        TestStatus.correcta => Icons.check_circle,
        TestStatus.fallida => Icons.cancel_outlined,
        TestStatus.solicitada => Icons.hourglass_top,
        TestStatus.anulada => Icons.block,
        null => Icons.remove_circle_outline,
      };
}

class SummaryTestRow extends StatelessWidget {
  final String label;
  final TestStatus? status;

  /// Quién la validó y la nota del operador.
  final String? detail;

  /// Texto cuando no hay estatus.
  final String emptyLabel;

  const SummaryTestRow(
    this.label,
    this.status, {
    super.key,
    this.detail,
    this.emptyLabel = 'Sin solicitar',
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final muted = status == null || status == TestStatus.anulada;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ServiceOrderColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: muted
                        ? ServiceOrderColors.hintText
                        : ServiceOrderColors.mutedText,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(status.icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                status.labelOr(emptyLabel),
                style: TextStyle(
                  color: muted ? ServiceOrderColors.hintText : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (detail != null && detail!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                detail!,
                style: const TextStyle(
                  color: ServiceOrderColors.hintText,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SummarySubsectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const SummarySubsectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class SummaryTagColors {
  SummaryTagColors._();

  static const Color serviceType = Color(0xFF6FA8E8);
  static const Color features = Color(0xFFA78BFA);
  static const Color operation = ServiceOrderColors.success;
  static const Color failures = Color(0xFFF26D6D);
}

class SummaryChipGroup extends StatelessWidget {
  final String title;
  final List<String> values;
  final Color? color;
  final IconData Function(String label) iconOf;

  const SummaryChipGroup(
    this.title,
    this.values, {
    super.key,
    this.color,
    this.iconOf = _defaultIcon,
  });

  static IconData _defaultIcon(String _) => ServiceOrderIcons.fallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummarySubsectionTitle(title),
        if (values.isEmpty)
          const Text(
            'Ninguno',
            style: TextStyle(color: ServiceOrderColors.hintText, fontSize: 14),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ServiceOrderTag(
                  label: value,
                  icon: iconOf(value),
                  color: color,
                ),
            ],
          ),
      ],
    );
  }
}

class SummaryTextBlock extends StatelessWidget {
  final String title;
  final String value;

  const SummaryTextBlock(this.title, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummarySubsectionTitle(title),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ServiceOrderColors.field,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.isEmpty ? 'Sin comentarios' : value,
            style: TextStyle(
              color: value.isEmpty
                  ? ServiceOrderColors.hintText
                  : ServiceOrderColors.mutedText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
