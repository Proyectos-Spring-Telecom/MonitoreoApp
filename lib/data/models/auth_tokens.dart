import '../../core/errors/failures.dart';
import '../../core/utils/json_reader.dart';

class AuthTokens {
  final String accessToken;
  final String? refreshToken;

  const AuthTokens({required this.accessToken, this.refreshToken});

  /// Los tokens pueden venir en la raíz o dentro de `data`, con varias claves.
  factory AuthTokens.fromResponse(dynamic json) {
    final layers = JsonReader.layers(json);
    final access = JsonReader.string(
      layers,
      const ['token', 'accessToken', 'access_token'],
    );
    if (access == null) {
      throw const ServerFailure(
        'El servidor no devolvió un token de acceso válido.',
      );
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: JsonReader.string(
        layers,
        const ['refreshToken', 'refresh_token'],
      ),
    );
  }
}
