import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';
import '../utils/json_reader.dart';

/// Archivo para una petición `multipart/form-data`.
class ApiFile {
  final String field;
  final Uint8List bytes;
  final String filename;
  final String contentType;

  const ApiFile({
    required this.field,
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

class _MultipartBody {
  final Map<String, String> fields;
  final List<ApiFile> files;

  const _MultipartBody(this.fields, this.files);
}

/// Lo implementa la capa de autenticación para que [ApiClient] pueda poner el
/// token en cada petición y renovarlo cuando el servidor responde 401.
abstract class ApiAuthHandler {
  Future<String?> getAccessToken();

  /// `false` cuando la sesión ya no puede renovarse.
  Future<bool> refreshAccessToken();

  Future<void> onSessionExpired();
}

class ApiClient {
  static const String sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const String unauthorizedMessage = 'No autorizado.';

  final http.Client client;
  final String baseUrl;
  ApiAuthHandler? authHandler;

  Future<bool>? _refreshInProgress;

  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.authHandler,
  })  : client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConstants.baseUrl;

  /// Con `auth: false` la petición no lleva Bearer ni intenta renovar el token
  /// (login, refresh y logout).
  ///
  /// Con `expireSessionOn401: false` un 401 que persiste tras renovar el
  /// token se reporta como error y no cierra la sesión (p. ej. contraseña
  /// actual incorrecta).
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? query,
    bool auth = true,
  }) =>
      _send('GET', endpoint, query: query, auth: auth);

  /// Descarga un archivo (p. ej. un PDF) y devuelve sus bytes sin decodificar.
  Future<Uint8List> getBytes(String endpoint, {String accept = '*/*'}) async =>
      await _send('GET', endpoint, auth: true, rawAccept: accept) as Uint8List;

  Future<dynamic> post(String endpoint, {Object? body, bool auth = true}) =>
      _send('POST', endpoint, body: body, auth: auth);

  Future<dynamic> put(String endpoint, {Object? body, bool auth = true}) =>
      _send('PUT', endpoint, body: body, auth: auth);

  Future<dynamic> patch(
    String endpoint, {
    Object? body,
    bool auth = true,
    bool expireSessionOn401 = true,
  }) =>
      _send(
        'PATCH',
        endpoint,
        body: body,
        auth: auth,
        expireSessionOn401: expireSessionOn401,
      );

  Future<dynamic> delete(String endpoint, {Object? body, bool auth = true}) =>
      _send('DELETE', endpoint, body: body, auth: auth);

  /// Envía `multipart/form-data` (textos en [fields] y archivos en [files]).
  Future<dynamic> multipart(
    String method,
    String endpoint, {
    Map<String, String> fields = const {},
    List<ApiFile> files = const [],
    bool auth = true,
  }) =>
      _send(
        method,
        endpoint,
        multipart: _MultipartBody(fields, files),
        auth: auth,
      );

  Future<dynamic> _send(
    String method,
    String endpoint, {
    Object? body,
    _MultipartBody? multipart,
    Map<String, String>? query,
    required bool auth,
    bool expireSessionOn401 = true,
    String? rawAccept,
  }) async {
    final handler = auth ? authHandler : null;
    Future<http.Response> perform() =>
        _perform(method, endpoint, body, multipart, query, handler, rawAccept);
    final raw = rawAccept != null;

    final response = await perform();
    if (handler == null || response.statusCode != 401) {
      return _handleResponse(response, raw: raw);
    }

    if (await _refreshOnce(handler)) {
      final retry = await perform();
      if (retry.statusCode != 401 || !expireSessionOn401) {
        return _handleResponse(retry, raw: raw);
      }
    }

    await handler.onSessionExpired();
    throw const AuthFailure(sessionExpiredMessage, statusCode: 401);
  }

  /// Varias peticiones con 401 simultáneas comparten una sola renovación.
  Future<bool> _refreshOnce(ApiAuthHandler handler) {
    return _refreshInProgress ??= handler
        .refreshAccessToken()
        .whenComplete(() => _refreshInProgress = null);
  }

  /// La petición se construye en cada intento: un multipart no se puede reenviar.
  Future<http.Response> _perform(
    String method,
    String endpoint,
    Object? body,
    _MultipartBody? multipart,
    Map<String, String>? query,
    ApiAuthHandler? handler,
    String? accept,
  ) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }

    final headers = {'Accept': accept ?? 'application/json'};
    final token = await handler?.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.BaseRequest request;
    if (multipart != null) {
      request = http.MultipartRequest(method, uri)
        ..headers.addAll(headers)
        ..fields.addAll(multipart.fields)
        ..files.addAll([
          for (final file in multipart.files)
            http.MultipartFile.fromBytes(
              file.field,
              file.bytes,
              filename: file.filename,
              contentType: MediaType.parse(file.contentType),
            ),
        ]);
    } else {
      final jsonRequest = http.Request(method, uri)
        ..headers.addAll(headers)
        ..headers['Content-Type'] = 'application/json';
      if (body != null) jsonRequest.body = jsonEncode(body);
      request = jsonRequest;
    }

    final timeout = multipart != null
        ? AppConstants.uploadTimeout
        : AppConstants.connectionTimeout;

    try {
      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(AppConstants.receiveTimeout);
      _log('$method ${uri.path} → ${response.statusCode}');
      return response;
    } on TimeoutException {
      _log('$method ${uri.path} → timeout');
      throw const NetworkFailure(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    } on http.ClientException catch (e) {
      _log('$method ${uri.path} → ${e.message}');
      throw const NetworkFailure(
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
    }
  }

  dynamic _handleResponse(http.Response response, {bool raw = false}) {
    final code = response.statusCode;
    if (raw && code >= 200 && code < 300) return response.bodyBytes;
    final decoded = _decode(response);
    if (code >= 200 && code < 300) return decoded;

    _log('Error $code: ${response.body}');
    final message = _errorMessage(decoded);
    if (code == 401) {
      throw AuthFailure(message ?? unauthorizedMessage, statusCode: code);
    }
    if (code == 403) {
      throw AuthFailure(
        message ?? 'No tienes permiso para realizar esta acción.',
        statusCode: code,
      );
    }
    if (code == 429) {
      throw ServerFailure(
        message ??
            'Demasiadas solicitudes. Espera un momento e intenta de nuevo.',
        statusCode: code,
      );
    }
    if (code == 404) {
      throw ServerFailure(
        message ?? 'No se encontró la información solicitada.',
        statusCode: code,
        data: decoded,
      );
    }
    if (code >= 500) {
      throw ServerFailure(
        message ?? 'El servidor presentó un error. Intenta más tarde.',
        statusCode: code,
      );
    }
    throw ServerFailure(
      message ?? 'No se pudo completar la solicitud ($code).',
      statusCode: code,
      data: decoded,
    );
  }

  static dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// Textos genéricos de Express (p. ej. "Unauthorized") que no sirven
  /// como mensaje para el usuario.
  static const Set<String> _genericBodies = {
    'unauthorized',
    'forbidden',
    'not found',
    'bad request',
    'internal server error',
    'too many requests',
    'service unavailable',
    'bad gateway',
  };

  static String? _errorMessage(dynamic decoded) {
    if (decoded is String) {
      final text = decoded.trim();
      final usable = text.length < 300 &&
          !text.startsWith('<') &&
          !_genericBodies.contains(text.toLowerCase());
      return usable ? text : null;
    }
    final layers = JsonReader.layers(decoded);
    return JsonReader.string(
      layers,
      const ['message', 'mensaje', 'error', 'title', 'detail'],
    );
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[API] $message');
  }
}
