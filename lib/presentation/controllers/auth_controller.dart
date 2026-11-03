import 'package:flutter/foundation.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/fetch_profile_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Resultado de una acción de contraseña: [message] es el texto del servidor
/// (o uno propio) listo para mostrarse.
typedef AuthActionResult = ({bool ok, String? message});

class AuthController extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final FetchProfileUseCase fetchProfileUseCase;
  final RequestPasswordResetUseCase requestPasswordResetUseCase;
  final ChangePasswordUseCase changePasswordUseCase;

  /// Limpia lo que quedó de la sesión (catálogos y claves de órdenes) al
  /// cerrar sesión o cuando expira.
  final Future<void> Function()? onSignedOut;

  AuthController({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.fetchProfileUseCase,
    required this.requestPasswordResetUseCase,
    required this.changePasswordUseCase,
    this.onSignedOut,
  });

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;
  bool _isRefreshingProfile = false;
  String? _profileError;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isRefreshingProfile => _isRefreshingProfile;
  String? get profileError => _profileError;

  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await loginUseCase(email, password);
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      _profileError = null;
    } on Failure catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _user = null;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error inesperado: ${e.toString()}';
      _user = null;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await logoutUseCase();
      await _clearSession();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error al cerrar sesión: ${e.toString()}';
    }

    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _user = await getCurrentUserUseCase();
      _status =
          _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Actualiza el usuario con `GET /login/me`. Si el token venció, el
  /// [ApiClient] lo renueva; si la sesión ya no es válida se llama a
  /// [expireSession].
  Future<void> refreshProfile() async {
    if (!isAuthenticated || _isRefreshingProfile) return;
    _isRefreshingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      _user = await fetchProfileUseCase();
    } on Failure catch (e) {
      if (e.message != ApiClient.sessionExpiredMessage) {
        _profileError = e.message;
      }
    } catch (e) {
      _profileError = 'No se pudo actualizar tu perfil.';
    }

    _isRefreshingProfile = false;
    notifyListeners();
  }

  // Las acciones de contraseña no cambian el estado de la sesión: cada
  // pantalla maneja su propio indicador de carga y sus mensajes.

  Future<AuthActionResult> requestPasswordReset(String email) => _run(
        () => requestPasswordResetUseCase(email),
        'No se pudo enviar el correo de recuperación. Intenta de nuevo.',
      );

  Future<AuthActionResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) =>
      _run(
        () => changePasswordUseCase(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmation: confirmation,
        ),
        'No se pudo cambiar la contraseña. Intenta de nuevo.',
      );

  Future<AuthActionResult> _run(
    Future<String?> Function() action,
    String fallbackError,
  ) async {
    try {
      return (ok: true, message: await action());
    } on Failure catch (e) {
      return (ok: false, message: e.message);
    } catch (_) {
      return (ok: false, message: fallbackError);
    }
  }

  Future<void> _clearSession() async {
    try {
      await onSignedOut?.call();
    } catch (_) {}
  }

  void expireSession() {
    _clearSession();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = ApiClient.sessionExpiredMessage;
    _profileError = null;
    notifyListeners();
  }
}
