import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_message.dart';

class ServiceOrderColors {
  ServiceOrderColors._();

  static const Color card = Color(0xFF1A1930);
  static const Color field = Color(0xFF0F0E22);
  static const Color tile = Color(0xFF2A2940);
  static const Color divider = Color(0x14FFFFFF);
  static const Color mutedText = Color(0xB3FFFFFF);
  static const Color hintText = Color(0x80FFFFFF);
  static const Color accent = Color(0xFF6FA8E8);
  static const Color accentBackground = Color(0xFF2B4468);
  static const Color success = Color(0xFF34C38F);
  static const Color warning = Color(0xFFF5A524);
  static const Color violet = Color(0xFFA78BFA);
  static const Color disabledButton = Color(0xFFA6A5BA);
  static const Color disabledButtonText = Color(0xFFDAD9E6);
}

/// Ícono dentro de un círculo con el color de fondo y borde suaves. Es el
/// ✓/✕ de "SIM nueva"/"SIM a quitar" y de las pruebas correctas o fallidas.
class CircleStatusIcon extends StatelessWidget {
  static const Color removed = Color(0xFFF26D6D);

  final IconData icon;
  final Color color;
  final double size;
  final String? semanticLabel;

  const CircleStatusIcon(
    this.icon,
    this.color, {
    super.key,
    this.size = 26,
    this.semanticLabel,
  });

  /// ✓ verde: correcto o lo que se instala.
  const CircleStatusIcon.check({
    Key? key,
    double size = 26,
    String? semanticLabel,
  }) : this(Icons.check_rounded, ServiceOrderColors.success,
            key: key, size: size, semanticLabel: semanticLabel);

  /// ✕ roja: fallido o lo que se quita.
  const CircleStatusIcon.cross({
    Key? key,
    double size = 26,
    String? semanticLabel,
  }) : this(Icons.close_rounded, removed,
            key: key, size: size, semanticLabel: semanticLabel);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, size: size * 0.62, color: color),
      ),
    );
  }
}

/// Flecha de regreso que siempre se muestra, aunque la pantalla se haya
/// abierto directamente (p. ej. al recargar en web) y no haya ruta anterior.
class ServiceOrderBackButton extends StatelessWidget {
  final String fallbackRoute;
  final Object? fallbackArguments;

  const ServiceOrderBackButton({
    super.key,
    required this.fallbackRoute,
    this.fallbackArguments,
  });

  Future<void> _handlePressed(BuildContext context) async {
    final navigator = Navigator.of(context);
    final handled = await navigator.maybePop();
    if (!handled && !navigator.canPop()) {
      navigator.pushReplacementNamed(
        fallbackRoute,
        arguments: fallbackArguments,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Regresar',
      onPressed: () => _handlePressed(context),
    );
  }
}

/// Etiqueta tipo píldora. Sin [color] se dibuja neutra.
class ServiceOrderTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const ServiceOrderTag({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? ServiceOrderColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.14) ?? ServiceOrderColors.tile,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color?.withValues(alpha: 0.4) ?? Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceOrderCard extends StatelessWidget {
  final Widget child;

  const ServiceOrderCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// Indicación al inicio de cada paso de la orden. Misma forma que el aviso de
/// validación del Resumen, en versión compacta y en azul: el ámbar se reserva
/// para la validación final.
class ServiceOrderStepNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const ServiceOrderStepNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = ServiceOrderColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceOrderInfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const ServiceOrderInfoBanner({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ServiceOrderColors.accentBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ServiceOrderColors.accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceOrderSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final bool isRequired;

  const ServiceOrderSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.error),
                  ),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Fila de solo lectura (etiqueta arriba, valor abajo) con separador.
class ServiceOrderReadOnlyRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLast;

  const ServiceOrderReadOnlyRow(
    this.label,
    this.value, {
    super.key,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null || value!.trim().isEmpty ? '—' : value!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: ServiceOrderColors.divider),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ServiceOrderColors.mutedText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

void showServiceOrderMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  AppMessage.show(
    context,
    message,
    type: isError ? AppMessageType.error : AppMessageType.info,
  );
}

/// Cuerpo desplazable de cada paso de la orden de servicio. [action] va
/// después de la última sección del formulario; si el contenido es más corto
/// que la pantalla, baja hasta el pie para no quedar flotando a media pantalla.
class ServiceOrderFormBody extends StatelessWidget {
  final Widget child;
  final Widget action;
  final ScrollController? controller;

  const ServiceOrderFormBody({
    super.key,
    required this.child,
    required this.action,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(child: child),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Align(alignment: Alignment.bottomCenter, child: action),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón principal de cada paso; se coloca como `action` de
/// [ServiceOrderFormBody].
class ServiceOrderBottomButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Muestra un indicador en lugar del icono y desactiva el botón.
  final bool isLoading;

  const ServiceOrderBottomButton({
    super.key,
    required this.label,
    this.icon = Icons.arrow_forward,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ServiceOrderColors.disabledButtonText,
                ),
              )
            : Icon(icon, size: 22),
        iconAlignment: IconAlignment.end,
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ServiceOrderColors.disabledButton,
          disabledForegroundColor: ServiceOrderColors.disabledButtonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class ServiceOrderSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const ServiceOrderSwitchTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: ServiceOrderColors.divider),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: value
                    ? ServiceOrderColors.accentBackground
                    : ServiceOrderColors.tile,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: value
                    ? ServiceOrderColors.accent
                    : ServiceOrderColors.mutedText,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value ? Colors.white : ServiceOrderColors.mutedText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              thumbColor: const WidgetStatePropertyAll(Colors.white),
              trackColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? ServiceOrderColors.accent
                    : ServiceOrderColors.tile;
              }),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              // Un Icon sin glifo mantiene el mismo tamaño de thumb en ambos estados.
              thumbIcon: const WidgetStatePropertyAll(Icon(null)),
            ),
          ],
        ),
      ),
    );
  }
}
