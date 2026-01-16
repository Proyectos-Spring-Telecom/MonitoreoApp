import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/errors/failures.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../datasources/local/auth_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      // Llamada al datasource remoto (mock por ahora)
      final userModel = await remoteDataSource.login(email, password);

      // Guardar usuario y token localmente
      await localDataSource.saveUser(userModel);
      await localDataSource.saveToken('mock_token_${userModel.id}');

      return userModel;
    } on Failure {
      rethrow;
    } catch (e) {
      throw AuthFailure('Error inesperado: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await localDataSource.clearAuthData();
    } catch (e) {
      throw AuthFailure('Error al cerrar sesión: ${e.toString()}');
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final userModel = await localDataSource.getUser();
      return userModel;
    } catch (e) {
      throw CacheFailure('Error al obtener usuario: ${e.toString()}');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final user = await localDataSource.getUser();
      final token = await localDataSource.getToken();
      return user != null && token != null;
    } catch (e) {
      return false;
    }
  }
}
