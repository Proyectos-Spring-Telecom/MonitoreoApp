import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AuthColors {
  AuthColors._();

  static const Color navy = Color(0xFF0E1830);
  static const Color card = Color(0xD9121C34);
  static const Color cardBorder = Color(0x33FFFFFF);
  static const Color field = Color(0xFF141F38);
  static const Color fieldBorder = Color(0x40FFFFFF);
  static const Color button = Color(0xFF1E5BD8);
  static const Color buttonText = Color(0xFF0B1530);
  static const Color mutedText = Color(0xB3FFFFFF);
}

/// Estructura común de las pantallas de acceso (login y recuperación):
/// fondo, logo, título, tarjeta con el formulario y aviso legal.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget card;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    const termsStyle = TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5);
    const termsBold = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );

    return Scaffold(
      backgroundColor: AuthColors.navy,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/login.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.3, 0.55, 1.0],
                    colors: [
                      Color(0x000E1830),
                      Color(0x000E1830),
                      Color(0xB30E1830),
                      Color(0xF20E1830),
                    ],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/images/logos/logo_rosa.webp',
                              height: 38,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 40),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                            decoration: BoxDecoration(
                              color: AuthColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AuthColors.cardBorder),
                            ),
                            child: card,
                          ),
                          const SizedBox(height: 20),
                          const Text.rich(
                            TextSpan(
                              style: termsStyle,
                              children: [
                                TextSpan(text: 'Al iniciar aceptas nuestros '),
                                TextSpan(
                                  text: 'Términos y Condiciones',
                                  style: termsBold,
                                ),
                                TextSpan(text: ' y '),
                                TextSpan(
                                  text: 'Política de Privacidad.',
                                  style: termsBold,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0x80FFFFFF), fontSize: 16),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Icon(icon, color: AuthColors.mutedText, size: 22),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: AuthColors.field,
    contentPadding: const EdgeInsets.symmetric(vertical: 18),
    border: border(AuthColors.fieldBorder),
    enabledBorder: border(AuthColors.fieldBorder),
    focusedBorder: border(AuthColors.button, 1.5),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 1.5),
  );
}

class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.button,
          foregroundColor: AuthColors.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Enlace de texto alineado a la derecha, debajo de los campos.
class AuthLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AuthLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AuthLoading extends StatelessWidget {
  const AuthLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 54,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

class AuthErrorBox extends StatelessWidget {
  final String message;

  const AuthErrorBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x33F44336),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
