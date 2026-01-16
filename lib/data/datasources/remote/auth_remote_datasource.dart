import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl(this.apiClient);

  @override
  Future<UserModel> login(String email, String password) async {
    // Mock de autenticación - Simula delay de red
    await Future.delayed(const Duration(seconds: 1));

    // Validación mock simple
    if (email.isEmpty || password.isEmpty) {
      throw const AuthFailure('Email y contraseña son requeridos');
    }

    // Simula login exitoso con cualquier credencial
    // En producción, aquí se haría la llamada real a la API
    return UserModel(
      id: '1',
      name: email.split('@')[0],
      email: email,
      avatarUrl: null,
    );

    // Ejemplo de cómo sería con API real:
    // try {
    //   final response = await apiClient.post(
    //     '/auth/login',
    //     body: {'email': email, 'password': password},
    //   );
    //   return UserModel.fromJson(response);
    // } catch (e) {
    //   throw AuthFailure('Error al iniciar sesión: ${e.toString()}');
    // }
  }
}
