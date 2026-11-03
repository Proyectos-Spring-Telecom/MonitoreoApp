import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../models/auth_tokens.dart';
import '../../models/user_model.dart';
import 'local_storage.dart';
import 'secure_storage.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> saveTokens(AuthTokens tokens);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> clearAuthData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final LocalStorage localStorage;
  final SecureStorage secureStorage;

  AuthLocalDataSourceImpl(this.localStorage, this.secureStorage);

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      await localStorage.saveMap(AppConstants.userDataKey, user.toJson());
      await localStorage.saveString(AppConstants.isLoggedInKey, 'true');
    } catch (e) {
      throw CacheFailure('Error al guardar usuario: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getUser() async {
    try {
      final userData = await localStorage.getMap(AppConstants.userDataKey);
      if (userData == null) return null;
      return UserModel.fromJson(userData);
    } catch (e) {
      throw CacheFailure('Error al obtener usuario: ${e.toString()}');
    }
  }

  /// Si la respuesta no trae refresh token se conserva el anterior.
  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    try {
      await secureStorage.write(AppConstants.authTokenKey, tokens.accessToken);
      final refreshToken = tokens.refreshToken;
      if (refreshToken != null) {
        await secureStorage.write(AppConstants.refreshTokenKey, refreshToken);
      }
    } catch (e) {
      throw CacheFailure('Error al guardar la sesión: ${e.toString()}');
    }
  }

  @override
  Future<String?> getAccessToken() => _readSecure(AppConstants.authTokenKey);

  @override
  Future<String?> getRefreshToken() =>
      _readSecure(AppConstants.refreshTokenKey);

  Future<String?> _readSecure(String key) async {
    try {
      final value = await secureStorage.read(key);
      return value == null || value.isEmpty ? null : value;
    } catch (e) {
      throw CacheFailure('Error al leer la sesión: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAuthData() async {
    try {
      await secureStorage.delete(AppConstants.authTokenKey);
      await secureStorage.delete(AppConstants.refreshTokenKey);
      await localStorage.remove(AppConstants.userDataKey);
      await localStorage.remove(AppConstants.isLoggedInKey);
      // Token simulado que guardaban versiones anteriores en SharedPreferences.
      await localStorage.remove(AppConstants.authTokenKey);
    } catch (e) {
      throw CacheFailure(
        'Error al limpiar datos de autenticación: ${e.toString()}',
      );
    }
  }
}
