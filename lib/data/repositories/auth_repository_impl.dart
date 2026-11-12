import 'package:flutter/foundation.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth_tokens.dart';

class AuthRepositoryImpl implements AuthRepository, ApiAuthHandler {
  static const String notInstallerMessage =
      'Esta aplicación es solo para técnicos instaladores.';

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  /// Se ejecuta cuando la sesión ya no puede renovarse (refresh rechazado).
  VoidCallback? onSessionExpiredCallback;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      final tokens = await remoteDataSource.login(email, password);
      await localDataSource.saveTokens(tokens);
    } catch (e) {
      await localDataSource.clearAuthData();
      if (e is Failure) rethrow;
      throw AuthFailure('Error inesperado: ${e.toString()}');
    }

    // El login solo termina cuando /login/me confirma la sesión y el rol.
    try {
      final user = await remoteDataSource.me();
      if (!user.isInstaller) {
        await logout();
        throw const AuthFailure(notInstallerMessage, statusCode: 403);
      }
      await localDataSource.saveUser(user);
      return user;
    } catch (e) {
      await localDataSource.clearAuthData();
      if (e is NetworkFailure) rethrow;
      if (e is AuthFailure && e.message == notInstallerMessage) rethrow;
      final serverMessage = e is Failure &&
              e.message != ApiClient.sessionExpiredMessage &&
              e.message != ApiClient.unauthorizedMessage
          ? e.message
          : null;
      throw AuthFailure(
        serverMessage ?? 'No se pudo validar tu sesión. Intenta de nuevo.',
        statusCode: e is Failure ? e.statusCode : null,
      );
    }
  }

  @override
  Future<User> fetchProfile() async {
    final user = await remoteDataSource.me();
    if (!user.isInstaller) {
      await onSessionExpired();
      throw const AuthFailure(notInstallerMessage, statusCode: 403);
    }
    await localDataSource.saveUser(user);
    return user;
  }

  @override
  Future<String?> requestPasswordReset(String email) => _guard(
        () => remoteDataSource.requestPasswordReset(email.trim()),
        'No se pudo enviar el correo de recuperación. Intenta de nuevo.',
      );

  @override
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) =>
      _guard(
        () => remoteDataSource.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmation: confirmation,
        ),
        'No se pudo cambiar la contraseña. Intenta de nuevo.',
      );

  Future<String?> _guard(
    Future<String?> Function() action,
    String fallbackMessage,
  ) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (_) {
      throw ServerFailure(fallbackMessage);
    }
  }

  /// La sesión local se limpia aunque el servidor no responda.
  @override
  Future<void> logout() async {
    final refreshToken = await localDataSource.getRefreshToken();
    if (refreshToken != null) {
      try {
        await remoteDataSource.logout(refreshToken);
      } catch (_) {}
    }
    await localDataSource.clearAuthData();
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final user = await localDataSource.getUser();
      if (user == null) return null;
      if (!user.isInstaller || !await _hasTokens()) {
        await localDataSource.clearAuthData();
        return null;
      }
      return user;
    } on Failure {
      rethrow;
    } catch (e) {
      throw CacheFailure('Error al obtener usuario: ${e.toString()}');
    }
  }

  Future<bool> _hasTokens() async =>
      await localDataSource.getAccessToken() != null ||
      await localDataSource.getRefreshToken() != null;

  @override
  Future<String?> getAccessToken() => localDataSource.getAccessToken();

  /// Un rechazo del servidor (4xx) termina la sesión; los errores de red o
  /// 5xx se propagan para no cerrar la sesión por una falla temporal.
  @override
  Future<bool> refreshAccessToken() async {
    final refreshToken = await localDataSource.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final tokens = await remoteDataSource.refresh(refreshToken);
      await localDataSource.saveTokens(
        AuthTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken ?? refreshToken,
        ),
      );
      return true;
    } on Failure catch (e) {
      final status = e.statusCode;
      if (e is AuthFailure || (status != null && status < 500)) return false;
      rethrow;
    }
  }

  @override
  Future<void> onSessionExpired() async {
    await localDataSource.clearAuthData();
    onSessionExpiredCallback?.call();
  }
}
