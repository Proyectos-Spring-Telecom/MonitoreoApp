import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authController = context.read<AuthController>();
      await authController.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (authController.isAuthenticated && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  void _openForgotPassword() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushNamed(
      AppConstants.forgotPasswordRoute,
      arguments: _emailController.text.trim(),
    );
  }

  Widget _buildCard() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFieldLabel('Correo Electrónico'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: authInputDecoration(
              hint: 'Ingresa tu correo electrónico',
              icon: Icons.mail_outline,
            ),
            validator: Validators.email,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 22),
          const AuthFieldLabel('Contraseña'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: authInputDecoration(
              hint: 'Ingresa tu contraseña',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthColors.mutedText,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: Validators.password,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 12),
          AuthLink(
            label: '¿Olvidaste tu contraseña?',
            onTap: _openForgotPassword,
          ),
          const SizedBox(height: 24),
          Consumer<AuthController>(
            builder: (context, authController, child) {
              if (authController.isLoading) return const AuthLoading();

              if (authController.errorMessage != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthErrorBox(authController.errorMessage!),
                    const SizedBox(height: 16),
                    AuthSubmitButton(
                      label: 'Reintentar',
                      onPressed: _handleLogin,
                    ),
                  ],
                );
              }

              return AuthSubmitButton(
                label: 'Iniciar Sesión',
                onPressed: _handleLogin,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Hola, inicia sesión',
      subtitle: 'Acceso para operadores en campo',
      card: _buildCard(),
    );
  }
}
