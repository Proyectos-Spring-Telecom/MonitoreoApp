import '../repositories/auth_repository.dart';

class ChangePasswordUseCase {
  final AuthRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<String?> call({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) =>
      repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmation: confirmation,
      );
}
