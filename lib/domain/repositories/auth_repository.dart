import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();

  /// Consulta el usuario en sesión al servidor y actualiza la copia local.
  Future<User> fetchProfile();

  // Los servicios de contraseña devuelven el texto de confirmación del
  // servidor, si lo hay.

  /// Solicita el correo para restablecer la contraseña; no requiere sesión.
  Future<String?> requestPasswordReset(String email);

  /// Cambia la contraseña del usuario en sesión.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  });
}
