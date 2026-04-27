import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';
import '../../data/datasources/auth_mock_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/register_use_case.dart';

//state class
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final RegisterUseCase registerUseCase;
  final DioClient _dioClient;

  AuthNotifier({required this.registerUseCase, required DioClient dioClient})
      : _dioClient = dioClient,
        super(const AuthState());

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required int age,
    String? gender,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await registerUseCase.call(
        email: email,
        password: password,
        displayName: displayName,
        age: age,
        gender: gender,
      );
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Each step is wrapped independently so a failure in one does not
  // prevent the remaining cleanup steps from running.
  Future<void> logout() async {
    try {
      await _dioClient.dio.delete('/notifications/fcm-token');
    } catch (e) {
      debugPrint('[Auth] FCM token unregister failed: $e');
    }
    try {
      await _dioClient.dio.post('/auth/logout');
    } catch (e) {
      debugPrint('[Auth] Server logout failed: $e');
    }
    try {
      await UserSession.clear();
    } catch (e) {
      debugPrint('[Auth] Session clear failed: $e');
    }
    _dioClient.dio.options.headers.remove('Authorization');
    state = const AuthState();
  }
}

// provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final mockDatasource = AuthMockDatasource();
  final repository = AuthRepositoryImpl(mockDatasource: mockDatasource);
  final registerUseCase = RegisterUseCase(repository: repository);
  return AuthNotifier(
    registerUseCase: registerUseCase,
    dioClient: ref.read(dioClientProvider),
  );
});