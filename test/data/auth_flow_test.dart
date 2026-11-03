import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoreo/core/constants/app_constants.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/network/api_client.dart';
import 'package:monitoreo/core/utils/json_reader.dart';
import 'package:monitoreo/data/datasources/local/auth_local_datasource.dart';
import 'package:monitoreo/data/datasources/local/local_storage.dart';
import 'package:monitoreo/data/datasources/remote/auth_remote_datasource.dart';
import 'package:monitoreo/data/models/auth_tokens.dart';
import 'package:monitoreo/data/models/user_model.dart';
import 'package:monitoreo/data/repositories/auth_repository_impl.dart';

import '../helpers/in_memory_secure_storage.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Respuesta real de `GET /login/me` (permisos recortados), de un usuario
/// rol 1: la App no lo deja entrar.
const adminMeResponse = {
  'message': 'Perfil obtenido exitosamente',
  'id': 1,
  'nombre': 'root',
  'apellidoPaterno': 'spring',
  'apellidoMaterno': 'next',
  'idCliente': 1,
  'nombreCliente': 'Next',
  'apellidoPaternoCliente': '',
  'apellidoMaternoCliente': '',
  'logotipo': '',
  'telefono': '7773896248',
  'ultimoLogin': '2026-10-27T18:37:20.000Z',
  'fechaCreacion': '2026-04-15T11:43:58.000Z',
  'fotoPerfil':
      'https://nextspring.s3.us-east-1.amazonaws.com/Imagenes/user.png',
  'userName': 'admin@next.mx',
  'rol': {
    'id': '1',
    'nombre': 'SA',
    'descripcion': 'SupÃ©r Administrador',
    'fechaCreacion': '2025-12-26T15:28:12.000Z',
    'fechaActualizacion': '2025-12-26T15:28:12.000Z',
    'estatus': 1,
  },
  'permisos': [
    {'idPermiso': '1'},
    {'idPermiso': '2'},
    {'idPermiso': '133'},
  ],
};

/// La misma respuesta con el rol del técnico (8), el único que entra (§1).
final meResponse = {
  ...adminMeResponse,
  'rol': {...adminMeResponse['rol']! as Map<String, Object>, 'id': '8'},
};

class Harness {
  final requests = <http.Request>[];
  final secure = InMemorySecureStorage();
  late final ApiClient apiClient;
  late final AuthLocalDataSourceImpl local;
  late final AuthRepositoryImpl repository;
  int expiredCalls = 0;

  Harness._();

  static Future<Harness> create(Handler handler) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final harness = Harness._();
    harness.apiClient = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) {
        harness.requests.add(request);
        return handler(request);
      }),
    );
    harness.local =
        AuthLocalDataSourceImpl(LocalStorageImpl(prefs), harness.secure);
    harness.repository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(harness.apiClient),
      localDataSource: harness.local,
    )..onSessionExpiredCallback = () => harness.expiredCalls++;
    harness.apiClient.authHandler = harness.repository;
    return harness;
  }

  List<String> get paths => requests.map((r) => r.url.path).toList();

  Future<void> seedSession({
    String access = 'old-access',
    String? refresh = 'refresh-1',
  }) async {
    await local
        .saveTokens(AuthTokens(accessToken: access, refreshToken: refresh));
    await local.saveUser(UserModel.fromJson(meResponse));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login', () {
    test('envía userName y password, guarda tokens y encadena /login/me',
        () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login') {
          return jsonResponse({
            'data': {'access_token': 'access-1', 'refresh_token': 'refresh-1'},
          });
        }
        if (request.url.path == '/login/me') return jsonResponse(meResponse);
        return jsonResponse(null, 404);
      });

      final user = await h.repository.login('admin@next.mx', 'secreta');

      expect(h.paths, ['/login', '/login/me']);
      expect(jsonDecode(h.requests[0].body), {
        'userName': 'admin@next.mx',
        'password': 'secreta',
      });
      expect(h.requests[0].headers.containsKey('Authorization'), isFalse);
      expect(h.requests[1].headers['Authorization'], 'Bearer access-1');

      expect(user.id, '1');
      expect(user.name, 'root spring next');
      expect(user.email, 'admin@next.mx');
      expect(user.phone, '7773896248');
      expect(user.avatarUrl,
          'https://nextspring.s3.us-east-1.amazonaws.com/Imagenes/user.png');
      expect(user.role, 'Supér Administrador',
          reason: 'usa la descripción y repara la codificación');
      expect(user.isActive, isNull, reason: 'el estatus del rol no aplica');
      expect(user.clientId, '1');
      expect(user.clientName, 'Next');
      expect(user.permissions, ['1', '2', '133']);
      expect(user.roleId, '8');
      expect(user.isInstaller, isTrue);

      expect(h.secure.values[AppConstants.authTokenKey], 'access-1');
      expect(h.secure.values[AppConstants.refreshTokenKey], 'refresh-1');
      expect(await h.repository.isLoggedIn(), isTrue);
    });

    test('un usuario que no es rol 8 no entra y se cierra su sesión', () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login') {
          return jsonResponse({'token': 'a', 'refreshToken': 'r'});
        }
        if (request.url.path == '/login/me') {
          return jsonResponse(adminMeResponse);
        }
        return jsonResponse({'message': 'ok'});
      });

      await expectLater(
        h.repository.login('admin@next.mx', 'x'),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          AuthRepositoryImpl.notInstallerMessage,
        )),
      );
      expect(h.paths, ['/login', '/login/me', '/login/logout']);
      expect(h.secure.values, isEmpty);
      expect(await h.repository.isLoggedIn(), isFalse);
    });

    test('acepta tokens en la raíz con claves token/refreshToken', () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login') {
          return jsonResponse({'token': 'a', 'refreshToken': 'r'});
        }
        return jsonResponse(meResponse);
      });
      await h.repository.login('a@b.mx', 'x');
      expect(h.secure.values[AppConstants.authTokenKey], 'a');
      expect(h.secure.values[AppConstants.refreshTokenKey], 'r');
    });

    test('credenciales inválidas sin mensaje → mensaje claro y nada guardado',
        () async {
      final h = await Harness.create((_) async => jsonResponse(null, 401));
      await expectLater(
        h.repository.login('a@b.mx', 'mal'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            'Correo o contraseña incorrectos.',
          ),
        ),
      );
      expect(h.secure.values, isEmpty);
      expect(h.paths, ['/login']);
    });

    test('401 en texto plano "Unauthorized" (Express) → mensaje en español',
        () async {
      final h = await Harness.create(
        (_) async => http.Response(
          'Unauthorized',
          401,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      await expectLater(
        h.repository.login('a@b.mx', 'mal'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            'Correo o contraseña incorrectos.',
          ),
        ),
      );
    });

    test('429 por límite de solicitudes → mensaje en español', () async {
      final h = await Harness.create(
        (_) async => http.Response('Too Many Requests', 429),
      );
      await expectLater(
        h.repository.login('a@b.mx', 'x'),
        throwsA(isA<ServerFailure>().having(
          (e) => e.message,
          'message',
          'Demasiadas solicitudes. Espera un momento e intenta de nuevo.',
        )),
      );
    });

    test('muestra el mensaje del backend', () async {
      final h = await Harness.create(
        (_) async => jsonResponse({'message': 'Usuario bloqueado'}, 400),
      );
      await expectLater(
        h.repository.login('a@b.mx', 'x'),
        throwsA(isA<ServerFailure>()
            .having((e) => e.message, 'm', 'Usuario bloqueado')),
      );
    });

    test('si /login/me falla, el login no se completa y se limpian tokens',
        () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login') {
          return jsonResponse({'token': 'a', 'refreshToken': 'r'});
        }
        return jsonResponse(null, 500);
      });
      await expectLater(
          h.repository.login('a@b.mx', 'x'), throwsA(isA<AuthFailure>()));
      expect(h.secure.values, isEmpty);
      expect(await h.repository.isLoggedIn(), isFalse);
    });

    test('sin conexión → NetworkFailure', () async {
      final h = await Harness.create(
        (_) async => throw http.ClientException('Failed host lookup'),
      );
      await expectLater(
        h.repository.login('a@b.mx', 'x'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('Refresh automático', () {
    test('401 → refresh sin Bearer → reintenta con el token nuevo', () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login/refresh') {
          return jsonResponse({'accessToken': 'new-access'});
        }
        final auth = request.headers['Authorization'];
        return auth == 'Bearer new-access'
            ? jsonResponse(meResponse)
            : jsonResponse(null, 401);
      });
      await h.seedSession();

      final user = await h.repository.fetchProfile();

      expect(user.name, 'root spring next');
      expect(h.paths, ['/login/me', '/login/refresh', '/login/me']);
      final refreshRequest = h.requests[1];
      expect(refreshRequest.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(refreshRequest.body), {'refreshToken': 'refresh-1'});
      expect(h.secure.values[AppConstants.authTokenKey], 'new-access');
      expect(h.secure.values[AppConstants.refreshTokenKey], 'refresh-1',
          reason: 'sin refresh nuevo se conserva el anterior');
    });

    test('varias peticiones con 401 comparten una sola renovación', () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login/refresh') {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse(
              {'token': 'new-access', 'refreshToken': 'refresh-2'});
        }
        return request.headers['Authorization'] == 'Bearer new-access'
            ? jsonResponse(meResponse)
            : jsonResponse(null, 401);
      });
      await h.seedSession();

      await Future.wait([
        h.apiClient.get('/login/me'),
        h.apiClient.get('/login/me'),
        h.apiClient.get('/login/me'),
      ]);

      expect(h.paths.where((p) => p == '/login/refresh').length, 1);
      expect(h.secure.values[AppConstants.refreshTokenKey], 'refresh-2');
    });

    test('refresh rechazado → sesión expirada, limpia todo y avisa', () async {
      final h = await Harness.create((_) async => jsonResponse(null, 401));
      await h.seedSession();

      await expectLater(
        h.repository.fetchProfile(),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          ApiClient.sessionExpiredMessage,
        )),
      );
      expect(h.expiredCalls, 1);
      expect(h.secure.values, isEmpty);
      expect(await h.repository.getCurrentUser(), isNull);
    });

    test('sin refresh token → sesión expirada sin llamar a /login/refresh',
        () async {
      final h = await Harness.create((_) async => jsonResponse(null, 401));
      await h.seedSession(refresh: null);
      await expectLater(
          h.repository.fetchProfile(), throwsA(isA<AuthFailure>()));
      expect(h.paths, ['/login/me']);
      expect(h.expiredCalls, 1);
    });

    test('falla de red durante el refresh no cierra la sesión', () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login/refresh') {
          throw http.ClientException('Network is unreachable');
        }
        return jsonResponse(null, 401);
      });
      await h.seedSession();
      await expectLater(
          h.repository.fetchProfile(), throwsA(isA<NetworkFailure>()));
      expect(h.expiredCalls, 0);
      expect(h.secure.values[AppConstants.refreshTokenKey], 'refresh-1');
    });

    test('peticiones sin auth no intentan refresh', () async {
      final h = await Harness.create((_) async => jsonResponse(null, 401));
      await h.seedSession();
      await expectLater(
        h.apiClient.post('/login/logout', body: {}, auth: false),
        throwsA(isA<AuthFailure>()),
      );
      expect(h.paths, ['/login/logout']);
      expect(h.expiredCalls, 0);
    });
  });

  group('Logout', () {
    test('envía el refresh token sin Bearer y limpia la sesión', () async {
      final h = await Harness.create((_) async => jsonResponse({'ok': true}));
      await h.seedSession();
      await h.repository.logout();
      expect(h.paths, ['/login/logout']);
      expect(h.requests.single.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(h.requests.single.body), {'refreshToken': 'refresh-1'});
      expect(h.secure.values, isEmpty);
      expect(await h.repository.getCurrentUser(), isNull);
    });

    test('aunque el API falle, la sesión local se limpia', () async {
      final h = await Harness.create((_) async => jsonResponse(null, 500));
      await h.seedSession();
      await h.repository.logout();
      expect(h.secure.values, isEmpty);
    });

    test('sin refresh token no llama al API', () async {
      final h = await Harness.create((_) async => jsonResponse(null));
      await h.seedSession(refresh: null);
      await h.repository.logout();
      expect(h.requests, isEmpty);
      expect(h.secure.values, isEmpty);
    });
  });

  group('Codificación de textos', () {
    test('repara UTF-8 leído como Latin-1 y no altera textos correctos', () {
      expect(JsonReader.repairEncoding('SupÃ©r Administrador'),
          'Supér Administrador');
      expect(JsonReader.repairEncoding('TÃ©cnico de instalaciÃ³n'),
          'Técnico de instalación');
      expect(JsonReader.repairEncoding('Técnico de instalación'),
          'Técnico de instalación');
      expect(JsonReader.repairEncoding('Ñandú'), 'Ñandú');
    });
  });

  group('Sesión guardada', () {
    test('usuario guardado sin tokens (versión simulada anterior) se descarta',
        () async {
      final h = await Harness.create((_) async => jsonResponse(null));
      await h.local.saveUser(UserModel.fromJson(meResponse));
      expect(await h.repository.getCurrentUser(), isNull);
      expect(await h.repository.isLoggedIn(), isFalse);
    });

    test('el usuario guardado conserva todos sus campos', () async {
      final h = await Harness.create((_) async => jsonResponse(null));
      await h.seedSession();
      final user = await h.repository.getCurrentUser();
      expect(user, UserModel.fromJson(meResponse));
      expect(user!.lastLogin, DateTime.utc(2026, 10, 27, 18, 37, 20));
    });
  });

  group('Contraseña', () {
    http.Response text(String body, [int status = 200]) => http.Response(
          body,
          status,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );

    test('olvido: POST sin Bearer con userName y devuelve el texto', () async {
      final h = await Harness.create((_) async => text('Correo enviado'));
      await h.seedSession();

      final message = await h.repository.requestPasswordReset(' a@b.mx ');

      expect(message, 'Correo enviado');
      final request = h.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/login/usuario/recuperar/acceso');
      expect(jsonDecode(request.body), {'userName': 'a@b.mx'});
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('olvido: muestra el mensaje del backend al fallar', () async {
      final h = await Harness.create(
          (_) async => text('No existe un usuario con ese correo', 404));
      await expectLater(
        h.repository.requestPasswordReset('a@b.mx'),
        throwsA(isA<ServerFailure>().having((e) => e.message, 'message',
            'No existe un usuario con ese correo')),
      );
    });

    test('cambio: PATCH con Bearer de sesión y los tres campos', () async {
      final h =
          await Harness.create((_) async => text('Contraseña actualizada'));
      await h.seedSession(access: 'access-1');

      final message = await h.repository.changePassword(
        currentPassword: 'ClaveVieja1!',
        newPassword: 'ClaveNueva2!',
        confirmation: 'ClaveNueva2!',
      );

      expect(message, 'Contraseña actualizada');
      final request = h.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/usuarios/actualizar/contrasena');
      expect(request.headers['Authorization'], 'Bearer access-1');
      expect(jsonDecode(request.body), {
        'passwordActual': 'ClaveVieja1!',
        'passwordNueva': 'ClaveNueva2!',
        'passwordNuevaConfirmacion': 'ClaveNueva2!',
      });
    });

    test('cambio: 401 por contraseña actual incorrecta no cierra la sesión',
        () async {
      final h = await Harness.create((request) async {
        if (request.url.path == '/login/refresh') {
          return jsonResponse({'accessToken': 'access-2'});
        }
        return jsonResponse(
            {'message': 'La contraseña actual es incorrecta'}, 401);
      });
      await h.seedSession();

      await expectLater(
        h.repository.changePassword(
          currentPassword: 'mala',
          newPassword: 'ClaveNueva2!',
          confirmation: 'ClaveNueva2!',
        ),
        throwsA(isA<AuthFailure>().having(
            (e) => e.message, 'message', 'La contraseña actual es incorrecta')),
      );
      expect(h.paths, [
        '/usuarios/actualizar/contrasena',
        '/login/refresh',
        '/usuarios/actualizar/contrasena',
      ]);
      expect(h.expiredCalls, 0);
      expect(await h.repository.isLoggedIn(), isTrue);
    });
  });
}
