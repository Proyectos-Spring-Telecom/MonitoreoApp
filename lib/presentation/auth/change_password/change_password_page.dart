import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/password_rules.dart';
import '../../../core/widgets/app_message.dart';
import '../../controllers/auth_controller.dart';
import '../../service_order/widgets/service_order_fields.dart';
import '../../service_order/widgets/service_order_ui.dart';
import '../widgets/password_strength_panel.dart';

/// Cambio de contraseña del usuario en sesión
/// (`PATCH /usuarios/actualizar/contrasena`).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showErrors = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _currentController,
      _newController,
      _confirmController,
    ]) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String? get _currentError =>
      _currentController.text.isEmpty ? 'Ingresa tu contraseña actual.' : null;

  String? get _newError => PasswordRules.validate(_newController.text);

  String? get _confirmError => PasswordRules.validateConfirmation(
      _confirmController.text, _newController.text);

  Future<void> _handleSubmit() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (_currentError != null || _newError != null || _confirmError != null) {
      setState(() => _showErrors = true);
      AppMessage.error(context, 'Revisa los campos marcados.');
      return;
    }

    setState(() => _isSaving = true);
    final result = await context.read<AuthController>().changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
          confirmation: _confirmController.text,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.ok) {
      AppMessage.error(
        context,
        result.message ?? 'No se pudo cambiar la contraseña.',
      );
      return;
    }

    _currentController.clear();
    _newController.clear();
    _confirmController.clear();
    AppMessage.success(
      context,
      result.message ?? 'Contraseña actualizada correctamente.',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        titleSpacing: 0,
        leading: const ServiceOrderBackButton(
          fallbackRoute: AppConstants.profileRoute,
        ),
        title: const Text(
          'Cambio de contraseña',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: AutofillGroup(
        child: ServiceOrderFormBody(
          action: ServiceOrderBottomButton(
            label: _isSaving ? 'Guardando...' : 'Cambiar contraseña',
            icon: Icons.lock_reset,
            isLoading: _isSaving,
            onPressed: _handleSubmit,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ServiceOrderInfoBanner(
                icon: Icons.lock_outline,
                message:
                    'Sigue las indicaciones para realizar el cambio de contraseña.',
              ),
              const SizedBox(height: 14),
              const ServiceOrderRequiredLegend(),
              const SizedBox(height: 14),
              _buildCurrentCard(),
              const SizedBox(height: 16),
              _buildNewCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentCard() {
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.key_outlined,
            title: 'Contraseña actual',
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirma tu identidad con la contraseña que usas hoy.',
            style: TextStyle(color: ServiceOrderColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _PasswordField(
            label: 'Contraseña actual',
            hint: 'Ingresa tu contraseña actual',
            controller: _currentController,
            autofillHint: AutofillHints.password,
            errorText: _showErrors ? _currentError : null,
            enabled: !_isSaving,
          ),
        ],
      ),
    );
  }

  Widget _buildNewCard() {
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.lock_reset,
            title: 'Nueva contraseña',
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea una contraseña segura que cumpla todos los requisitos.',
            style: TextStyle(color: ServiceOrderColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _PasswordField(
            label: 'Nueva contraseña',
            hint: 'Ingresa la nueva contraseña',
            controller: _newController,
            autofillHint: AutofillHints.newPassword,
            errorText: _showErrors ? _newError : null,
            enabled: !_isSaving,
          ),
          const SizedBox(height: 14),
          PasswordStrengthPanel(
            password: _newController.text,
            backgroundColor: ServiceOrderColors.field,
          ),
          const SizedBox(height: 18),
          _PasswordField(
            label: 'Confirmar contraseña',
            hint: 'Repite la nueva contraseña',
            controller: _confirmController,
            autofillHint: AutofillHints.newPassword,
            errorText: _showErrors ? _confirmError : null,
            enabled: !_isSaving,
            isLast: true,
            onSubmitted: _handleSubmit,
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String autofillHint;
  final String? errorText;
  final bool enabled;
  final bool isLast;
  final VoidCallback? onSubmitted;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.autofillHint,
    this.errorText,
    this.enabled = true,
    this.isLast = false,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(
            TextSpan(
              text: widget.label,
              children: const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
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
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscure,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: [widget.autofillHint],
          keyboardType: TextInputType.visiblePassword,
          textInputAction:
              widget.isLast ? TextInputAction.done : TextInputAction.next,
          onSubmitted:
              widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: serviceOrderInputDecoration(
            hint: widget.hint,
            errorText: widget.errorText,
          ).copyWith(
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: ServiceOrderColors.mutedText,
              size: 22,
            ),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: ServiceOrderColors.mutedText,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }
}
