import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../errors/failures.dart';

class ApiClient {
  final http.Client client;
  final String baseUrl;

  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConstants.baseUrl;

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = _buildHeaders(headers, token);

      final response = await client
          .get(uri, headers: requestHeaders)
          .timeout(AppConstants.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw NetworkFailure('Error de conexión: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = _buildHeaders(headers, token);

      final response = await client
          .post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw NetworkFailure('Error de conexión: ${e.toString()}');
    }
  }

  Map<String, String> _buildHeaders(
    Map<String, String>? headers,
    String? token,
  ) {
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      defaultHeaders['Authorization'] = 'Bearer $token';
    }

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }

    return defaultHeaders;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw const AuthFailure('No autorizado');
    } else {
      throw ServerFailure(
        'Error del servidor: ${response.statusCode}',
      );
    }
  }
}
