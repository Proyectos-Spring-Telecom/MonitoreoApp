import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class FetchProfileUseCase {
  final AuthRepository repository;

  FetchProfileUseCase(this.repository);

  Future<User> call() => repository.fetchProfile();
}
