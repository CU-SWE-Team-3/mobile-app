import 'package:soundcloud_clone/core/constants/app_config.dart';
import 'package:soundcloud_clone/features/auth/data/datasources/auth_mock_datasource.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthMockDatasource mockDatasource;

  AuthRepositoryImpl({required this.mockDatasource});

  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required int age,
    String? gender,
  }) async {
    if (AppConfig.useMockData) {
      return mockDatasource.register(
        email: email,
        password: password,
        displayName: displayName,
        age: age,
        gender: gender,
      );
    }
    throw UnimplementedError('Real API not connected yet');
  }

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      return mockDatasource.login(email: email, password: password);
    }
    throw UnimplementedError('Real API not connected yet');
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    if (AppConfig.useMockData) {
      return mockDatasource.verifyEmail(token: token);
    }
    throw UnimplementedError('Real API not connected yet');
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    if (AppConfig.useMockData) {
      return mockDatasource.forgotPassword(email: email);
    }
    throw UnimplementedError('Real API not connected yet');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getCurrentUser() async => null;
}
