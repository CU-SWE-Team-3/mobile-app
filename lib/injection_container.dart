import 'package:get_it/get_it.dart';

import 'core/network/dio_client.dart';
import 'core/socket/socket_service.dart';
import 'features/auth/data/datasources/auth_mock_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/register_use_case.dart';
import 'features/engagement/data/sources/engagement_remote_data_source.dart';
import 'features/messaging/data/datasources/messaging_remote_data_source.dart';
import 'features/messaging/data/repositories/messaging_repository_impl.dart';
import 'features/messaging/domain/repositories/messaging_repository.dart';

/// Global service locator instance.
/// Access anywhere via: sl<MyService>()
final sl = GetIt.instance;

Future<void> initDependencies() async {
  _initAuth();
  _initEngagement();
  _initMessaging();
  // TODO: Each team member registers their module dependencies here.
  // Follow the same pattern used in _initAuth() below.
  // Example:
  //   _initProfile();
  //   _initPlayer();
}

void _initEngagement() {
  sl.registerLazySingleton<EngagementRemoteDataSource>(
    () => EngagementRemoteDataSource(dioClient.dio),
  );
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

void _initMessaging() {
  sl.registerLazySingleton<SocketService>(() => SocketService());

  sl.registerLazySingleton<MessagingRemoteDataSource>(
    () => MessagingRemoteDataSource(dioClient.dio),
  );

  sl.registerLazySingleton<MessagingRepository>(
    () => MessagingRepositoryImpl(sl()),
  );
}
