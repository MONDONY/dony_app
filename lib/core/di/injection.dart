import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies({required String apiBaseUrl}) async {
  // Core
  getIt.registerLazySingleton<HiveService>(() => HiveService());
  getIt.registerLazySingleton<ApiClient>(() => ApiClient(baseUrl: apiBaseUrl));
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());

  // Auth
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<AuthRemoteDatasource>()),
  );
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(getIt<AuthRepository>()),
  );

  // Local auth (biometric + PIN)
  getIt.registerLazySingleton<LocalAuthService>(() => LocalAuthService());
  getIt.registerFactory<LocalAuthBloc>(
    () => LocalAuthBloc(getIt<LocalAuthService>()),
  );
}
