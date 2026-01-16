import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../models/user_model.dart';
import 'local_storage.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> clearAuthData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final LocalStorage localStorage;

  AuthLocalDataSourceImpl(this.localStorage);

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

  @override
  Future<void> saveToken(String token) async {
    try {
      await localStorage.saveString(AppConstants.authTokenKey, token);
    } catch (e) {
      throw CacheFailure('Error al guardar token: ${e.toString()}');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await localStorage.getString(AppConstants.authTokenKey);
    } catch (e) {
      throw CacheFailure('Error al obtener token: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAuthData() async {
    try {
      await localStorage.remove(AppConstants.userDataKey);
      await localStorage.remove(AppConstants.authTokenKey);
      await localStorage.remove(AppConstants.isLoggedInKey);
    } catch (e) {
      throw CacheFailure('Error al limpiar datos de autenticación: ${e.toString()}');
    }
  }
}
