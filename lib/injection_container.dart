import 'package:get_it/get_it.dart';

import 'features/auth/data/datasources/auth_mock_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/register_use_case.dart';

/// Global service locator instance.
/// Access anywhere via: sl<MyService>()
final sl = GetIt.instance;

Future<void> initDependencies() async {
  _initAuth();
  // TODO: Each team member registers their module dependencies here.
  // Follow the same pattern used in _initAuth() below.
  // Example:
  //   _initProfile();
  //   _initPlayer();
}

void _initAuth() {
  sl.registerLazySingleton<AuthMockDatasource>(() => AuthMockDatasource());

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(mockDatasource: sl()),
  );

  sl.registerLazySingleton<RegisterUseCase>(
    () => RegisterUseCase(repository: sl()),
  );
}
