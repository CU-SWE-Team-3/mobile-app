import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required int age,
    String? gender,
  });

  Future<User> login({
    required String email,
    required String password,
  });

  Future<void> verifyEmail({
    required String token,
  });

  Future<void> forgotPassword({
    required String email,
  });

  Future<void> logout();

  Future<User?> getCurrentUser();
}