import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase({required this.repository});

  Future<User> call({
    required String email,
    required String password,
    required String displayName,
    required int age,
    String? gender,
  }) {
    return repository.register(
      email: email,
      password: password,
      displayName: displayName,
      age: age,
      gender: gender,
    );
  }
}