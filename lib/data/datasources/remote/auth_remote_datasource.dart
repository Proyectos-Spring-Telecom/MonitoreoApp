import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/json_reader.dart';
import '../../models/auth_tokens.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthTokens> login(String userName, String password);
  Future<UserModel> me();
  Future<AuthTokens> refresh(String refreshToken);
  Future<void> logout(String refreshToken);

  /// El API envía al correo el enlace al portal web donde se restablece la
  /// contraseña. Devuelve el texto de confirmación del servidor, si lo hay.
  Future<String?> requestPasswordReset(String email);

  /// Cambia la contraseña del usuario en sesión.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl(this.apiClient);

  @override
  Future<AuthTokens> login(String userName, String password) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.login,
        body: {'userName': userName, 'password': password},
        auth: false,
      );
      return AuthTokens.fromResponse(response);
    } on AuthFailure catch (e) {
      if (e.message != ApiClient.unauthorizedMessage) rethrow;
      throw AuthFailure(
        'Correo o contraseña incorrectos.',
        statusCode: e.statusCode,
      );
    }
  }

  @override
  Future<UserModel> me() async {
    final response = await apiClient.get(ApiEndpoints.me);
    return UserModel.fromJson(response);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await apiClient.post(
      ApiEndpoints.refresh,
      body: {'refreshToken': refreshToken},
      auth: false,
    );
    return AuthTokens.fromResponse(response);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await apiClient.post(
      ApiEndpoints.logout,
      body: {'refreshToken': refreshToken},
      auth: false,
    );
  }

  @override
  Future<String?> requestPasswordReset(String email) async {
    final response = await apiClient.post(
      ApiEndpoints.requestPasswordReset,
      body: {'userName': email},
      auth: false,
    );
    return _text(response);
  }

  @override
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    try {
      final response = await apiClient.patch(
        ApiEndpoints.changePassword,
        body: {
          'passwordActual': currentPassword,
          'passwordNueva': newPassword,
          'passwordNuevaConfirmacion': confirmation,
        },
        expireSessionOn401: false,
      );
      return _text(response);
    } on AuthFailure catch (e) {
      if (e.message != ApiClient.unauthorizedMessage) rethrow;
      throw AuthFailure(
        'No se pudo validar tu contraseña actual.',
        statusCode: e.statusCode,
      );
    }
  }

  /// Estos servicios responden texto plano; se acepta también JSON con
  /// `message`.
  static String? _text(dynamic response) {
    if (response is String) {
      final text = response.trim();
      return text.isEmpty || text.length > 300 ? null : text;
    }
    return JsonReader.string(
      JsonReader.layers(response),
      const ['message', 'mensaje'],
    );
  }
}
