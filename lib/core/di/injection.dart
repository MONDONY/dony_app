import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies({required String apiBaseUrl}) async {
  // Core
  getIt.registerLazySingleton<HiveService>(() => HiveService());
  getIt.registerLazySingleton<ApiClient>(() => ApiClient(baseUrl: apiBaseUrl));
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<SavedTripsService>(
    () => SavedTripsService(getIt<HiveService>()),
  );

  // Auth
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<AuthRemoteDatasource>()),
  );
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(getIt<AuthRepository>(), getIt<LocalAuthService>()),
  );

  // Local auth (biometric + PIN)
  getIt.registerLazySingleton<LocalAuthService>(() => LocalAuthService());
  getIt.registerFactory<LocalAuthBloc>(
    () => LocalAuthBloc(getIt<LocalAuthService>()),
  );

  // KYC
  getIt.registerLazySingleton<KycRepository>(
    () => KycRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<KycBloc>(
    () => KycBloc(getIt<KycRepository>()),
  );

  // Matching — Announcements
  getIt.registerLazySingleton<AnnouncementRemoteDatasource>(
    () => AnnouncementRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AnnouncementRepository>(
    () => AnnouncementRepository(getIt<AnnouncementRemoteDatasource>()),
  );
  getIt.registerFactory<AnnouncementBloc>(
    () => AnnouncementBloc(getIt<AnnouncementRepository>()),
  );

  // Matching — Bids
  getIt.registerLazySingleton<BidRemoteDatasource>(
    () => BidRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BidRepository>(
    () => BidRepository(getIt<BidRemoteDatasource>()),
  );
  getIt.registerFactory<BidBloc>(
    () => BidBloc(getIt<BidRepository>()),
  );

  // Payments
  getIt.registerLazySingleton<PaymentRemoteDatasource>(
    () => PaymentRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PaymentRepository>(
    () => PaymentRepository(getIt<PaymentRemoteDatasource>()),
  );
  getIt.registerFactory<PaymentBloc>(
    () => PaymentBloc(getIt<PaymentRepository>()),
  );

  // Cancellation
  getIt.registerLazySingleton<CancellationRemoteDatasource>(
    () => CancellationRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CancellationRepository>(
    () => CancellationRepository(getIt<CancellationRemoteDatasource>()),
  );
  getIt.registerFactory<CancellationBloc>(
    () => CancellationBloc(getIt<CancellationRepository>()),
  );

  // Tracking
  getIt.registerLazySingleton<TrackingRepository>(
    () => TrackingRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<TrackingBloc>(
    () => TrackingBloc(getIt<TrackingRepository>()),
  );
}
