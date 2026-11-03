import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

/// Recuperación de contraseña. Recibe como argumento de la ruta el correo que
/// el usuario ya había escrito en el login.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const int _resendSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _readArguments = false;
  bool _isSending = false;
  String? _errorMessage;
  String? _sentTo;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArguments) return;
    _readArguments = true;
    final email = ModalRoute.of(context)?.settings.arguments;
    if (email is String) _emailController.text = email;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending || _resendIn > 0) return;
    if (_sentTo == null && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _sentTo ?? _emailController.text.trim();
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    final result =
        await context.read<AuthController>().requestPasswordReset(email);
    if (!mounted) return;

    setState(() {
      _isSending = false;
      _errorMessage = result.ok ? null : result.message;
      if (result.ok) _sentTo = email;
    });
    if (result.ok) _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  void _useAnotherEmail() {
    _resendTimer?.cancel();
    setState(() {
      _sentTo = null;
      _resendIn = 0;
      _errorMessage = null;
    });
  }

  void _backToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppConstants.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;

    return AuthLayout(
      title: sentTo == null ? 'Recupera tu contraseña' : '¡Ya casi está listo!',
      subtitle: sentTo == null
          ? 'Te enviaremos las instrucciones a tu correo'
          : 'Solo sigue estos pasos para recuperar tu acceso',
      card: sentTo == null ? _buildFormCard() : _buildSentCard(sentTo),
    );
  }

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFieldLabel('Correo Electrónico'),
          TextFormField(
            controller: _emailController,
            enabled: !_isSending,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: authInputDecoration(
              hint: 'Ingresa tu correo electrónico',
              icon: Icons.mail_outline,
            ),
            validator: Validators.email,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 12),
          AuthLink(
            label: 'Volver a iniciar sesión',
            onTap: _isSending ? null : _backToLogin,
          ),
          const SizedBox(height: 24),
          ..._buildActions(
            label: 'Enviar instrucciones',
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildSentCard(String email) {
    const textStyle = TextStyle(
      color: AuthColors.mutedText,
      fontSize: 14,
      height: 1.45,
    );
    final canResend = _resendIn <= 0 && !_isSending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthFieldLabel('¿Qué sigue?'),
        _Step(
          number: 1,
          child: Text.rich(
            TextSpan(
              style: textStyle,
              children: [
                const TextSpan(text: 'Abre el correo que te enviamos a '),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        const _Step(
          number: 2,
          child: Text(
            'Toca el enlace y crea tu nueva contraseña.',
            style: textStyle,
          ),
        ),
        const _Step(
          number: 3,
          child: Text(
            'Regresa aquí e inicia sesión con ella.',
            style: textStyle,
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline,
                color: AuthColors.mutedText, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿No lo ves? Puede tardar unos minutos en llegar; revisa '
                'también tu carpeta de correo no deseado.',
                style: TextStyle(
                  color: AuthColors.mutedText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AuthLink(
          label: canResend
              ? '¿No te llegó? Reenviar correo'
              : _isSending
                  ? 'Reenviando...'
                  : 'Reenviar correo en $_resendIn s',
          onTap: canResend ? _send : null,
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          AuthErrorBox(_errorMessage!),
          const SizedBox(height: 16),
        ],
        AuthSubmitButton(
          label: 'Volver a iniciar sesión',
          onPressed: _isSending ? null : _backToLogin,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _isSending ? null : _useAnotherEmail,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              'Usar otro correo',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions({
    required String label,
    required VoidCallback onPressed,
  }) {
    if (_isSending) return const [AuthLoading()];
    if (_errorMessage != null) {
      return [
        AuthErrorBox(_errorMessage!),
        const SizedBox(height: 16),
        AuthSubmitButton(label: 'Reintentar', onPressed: onPressed),
      ];
    }
    return [AuthSubmitButton(label: label, onPressed: onPressed)];
  }
}

class _Step extends StatelessWidget {
  final int number;
  final Widget child;

  const _Step({required this.number, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AuthColors.button,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
