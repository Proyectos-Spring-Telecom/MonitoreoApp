class PasswordRule {
  final String label;
  final bool Function(String password) isMet;

  const PasswordRule(this.label, this.isMet);
}

/// Reglas de fuerza que exige el API para una contraseña nueva; deben
/// cumplirse todas.
class PasswordRules {
  PasswordRules._();

  static const int minLength = 7;
  static const int maxLength = 15;

  static final List<PasswordRule> all = [
    PasswordRule(
      'Entre $minLength y $maxLength caracteres',
      (p) => p.length >= minLength && p.length <= maxLength,
    ),
    PasswordRule(
        'Al menos una mayúscula (A-Z)', (p) => p.contains(RegExp(r'[A-Z]'))),
    PasswordRule(
        'Al menos una minúscula (a-z)', (p) => p.contains(RegExp(r'[a-z]'))),
    PasswordRule(
        'Al menos un número (0-9)', (p) => p.contains(RegExp(r'[0-9]'))),
    PasswordRule(
      'Al menos un carácter especial (!@#\$%…)',
      (p) => p.contains(RegExp(r'[^A-Za-z0-9]')),
    ),
  ];

  static int metCount(String password) =>
      all.where((rule) => rule.isMet(password)).length;

  static bool isValid(String password) => metCount(password) == all.length;

  /// Error para el campo de la contraseña nueva, o `null` si es válida.
  static String? validate(String password) {
    if (password.isEmpty) return 'Ingresa la nueva contraseña.';
    if (!isValid(password)) return 'No cumple con todos los requisitos.';
    return null;
  }

  static String? validateConfirmation(String confirmation, String password) {
    if (confirmation.isEmpty) return 'Confirma la nueva contraseña.';
    if (confirmation != password) return 'Las contraseñas no coinciden.';
    return null;
  }
}
