import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/domain/entities/user.dart';
import 'package:monitoreo/domain/repositories/auth_repository.dart';
import 'package:monitoreo/domain/usecases/change_password_usecase.dart';
import 'package:monitoreo/domain/usecases/fetch_profile_usecase.dart';
import 'package:monitoreo/domain/usecases/get_current_user_usecase.dart';
import 'package:monitoreo/domain/usecases/login_usecase.dart';
import 'package:monitoreo/domain/usecases/logout_usecase.dart';
import 'package:monitoreo/domain/usecases/request_password_reset_usecase.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';

/// Registra las llamadas de contraseña; [failure] hace que fallen.
class FakeAuthRepository implements AuthRepository {
  final resetRequests = <String>[];
  final changes = <({String current, String newPassword, String confirm})>[];
  Failure? failure;
  String? serverMessage;

  AuthController controller() => AuthController(
        loginUseCase: LoginUseCase(this),
        logoutUseCase: LogoutUseCase(this),
        getCurrentUserUseCase: GetCurrentUserUseCase(this),
        fetchProfileUseCase: FetchProfileUseCase(this),
        requestPasswordResetUseCase: RequestPasswordResetUseCase(this),
        changePasswordUseCase: ChangePasswordUseCase(this),
      );

  Future<String?> _respond() async {
    if (failure != null) throw failure!;
    return serverMessage;
  }

  @override
  Future<String?> requestPasswordReset(String email) {
    resetRequests.add(email);
    return _respond();
  }

  @override
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) {
    changes.add((
      current: currentPassword,
      newPassword: newPassword,
      confirm: confirmation,
    ));
    return _respond();
  }

  @override
  Future<User> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<bool> isLoggedIn() async => false;

  @override
  Future<User> fetchProfile() => throw UnimplementedError();
}

class _SignedInAuthRepository extends FakeAuthRepository {
  final User user;

  _SignedInAuthRepository(this.user);

  @override
  Future<User> login(String email, String password) async => user;
}

/// Controlador con [user] en sesión.
Future<AuthController> signedInController(User user) async {
  final controller = _SignedInAuthRepository(user).controller();
  await controller.login(user.email, 'secreta');
  return controller;
}
