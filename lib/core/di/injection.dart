import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/favorite_travelers/bloc/favorite_traveler_bloc.dart';
import 'package:dony/features/favorite_travelers/data/datasources/favorite_traveler_datasource.dart';
import 'package:dony/features/favorite_travelers/data/repositories/favorite_traveler_repository.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/datasources/pickup_address_datasource.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/datasources/recipient_datasource.dart';
import 'package:dony/features/recipients/data/repositories/recipient_repository.dart';
import 'package:dony/features/city/data/city_datasource.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/config/data/config_datasource.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_datasource.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:dony/features/profile/bloc/pro_stats_bloc.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:dony/features/profile/data/pro_stats_repository.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/data/firebase_phone_reauth.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
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
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/data/notification_remote_datasource.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/package_request/bloc/complete_details_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies({required String apiBaseUrl}) async {
  // Core
  getIt.registerLazySingleton<HiveService>(() => HiveService());
  getIt.registerLazySingleton<ActiveRoleCubit>(
    () => ActiveRoleCubit(hiveService: getIt<HiveService>()),
  );
  getIt.registerLazySingleton<ApiClient>(() => ApiClient(baseUrl: apiBaseUrl));
  getIt.registerLazySingleton<NotificationRemoteDatasource>(
    () => NotificationRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(getIt<NotificationRemoteDatasource>()),
  );
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService(getIt<ApiClient>(), getIt<NotificationRepository>()),
    dispose: (s) => s.dispose(),
  );
  getIt.registerFactory<NotificationBloc>(
    () => NotificationBloc(getIt<NotificationRepository>()),
  );
  getIt.registerLazySingleton<EnvoisRefreshNotifier>(() => EnvoisRefreshNotifier());
  getIt.registerLazySingleton<PendingSearchNotifier>(() => PendingSearchNotifier());
  getIt.registerLazySingleton<SavedTripsService>(
    () => SavedTripsService(getIt<HiveService>()),
  );
  getIt.registerLazySingleton<AddressAutocompleteService>(
    () => AddressAutocompleteService(dio: getIt<ApiClient>().dio),
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
    () => AnnouncementBloc(
      getIt<AnnouncementRepository>(),
      getIt<HiveService>(),
    ),
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

  // Messaging
  getIt.registerLazySingleton<ConversationRepository>(
    () => ConversationRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<FirestoreChatRepository>(
    () => FirestoreChatRepository(FirebaseFirestore.instance),
  );
  getIt.registerLazySingleton<ConversationListBloc>(
    () => ConversationListBloc(
      getIt<ConversationRepository>(),
      getIt<FirestoreChatRepository>(),
    ),
    dispose: (b) => b.close(),
  );
  getIt.registerFactory<ChatBloc>(
    () => ChatBloc(
      getIt<FirestoreChatRepository>(),
      getIt<ConversationRepository>(),
    ),
  );
  getIt.registerFactory<ConversationOpenBloc>(
    () => ConversationOpenBloc(getIt<ConversationRepository>()),
  );

  // Config (commission rate)
  getIt.registerLazySingleton<ConfigDatasource>(
    () => ConfigDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<IConfigRepository>(
    () => ConfigRepository(getIt<ConfigDatasource>()),
  );
  getIt.registerFactory<ConfigBloc>(
    () => ConfigBloc(getIt<IConfigRepository>()),
  );

  // Connect onboarding
  getIt.registerLazySingleton<ConnectOnboardingDatasource>(
    () => ConnectOnboardingDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<IConnectOnboardingRepository>(
    () => ConnectOnboardingRepository(getIt<ConnectOnboardingDatasource>()),
  );
  getIt.registerFactory<ConnectOnboardingBloc>(
    () => ConnectOnboardingBloc(getIt<IConnectOnboardingRepository>()),
  );

  // Profile (upgrade PRO + statistiques PRO)
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ProStatsRepository>(
    () => ProStatsRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<ProStatsBloc>(
    () => ProStatsBloc(getIt<ProStatsRepository>()),
  );
  getIt.registerFactory<SupportContactBloc>(
    () => SupportContactBloc(),
  );

  // Settings — Account Deletion
  getIt.registerLazySingleton<AccountDeletionRepository>(
    () => AccountDeletionRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<FirebasePhoneReauth>(
    () => FirebasePhoneReauthImpl(),
  );
  getIt.registerFactory<AccountDeletionBloc>(
    () => AccountDeletionBloc(
      getIt<AccountDeletionRepository>(),
      getIt<FirebasePhoneReauth>(),
    ),
  );

  // Ratings
  getIt.registerLazySingleton<RatingRepository>(
    () => RatingRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<RatingBloc>(
    () => RatingBloc(getIt<RatingRepository>()),
  );
  getIt.registerFactory<MyReviewsBloc>(
    () => MyReviewsBloc(getIt<RatingRepository>()),
  );
  getIt.registerFactory<ProfilePublicBloc>(
    () => ProfilePublicBloc(
      getIt<ProfileRepository>(),
      getIt<RatingRepository>(),
    ),
  );

  // Tracking
  getIt.registerLazySingleton<TrackingRepository>(
    () => TrackingRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<OfflineSyncService>(
    () => OfflineSyncService(getIt<HiveService>(), getIt<TrackingRepository>()),
    dispose: (s) => s.dispose(),
  );
  getIt.registerFactory<TrackingBloc>(
    () => TrackingBloc(getIt<TrackingRepository>(), getIt<OfflineSyncService>()),
  );

  // City autocomplete
  getIt.registerLazySingleton<CityDatasource>(
    () => CityDatasource(dio: getIt<ApiClient>().dio),
  );
  getIt.registerLazySingleton<CityRepository>(
    () => CityRepository(datasource: getIt<CityDatasource>()),
  );
  getIt.registerFactory<CitySearchBloc>(
    () => CitySearchBloc(getIt<CityRepository>()),
  );

  // Address book — Pickup Addresses
  getIt.registerLazySingleton<PickupAddressDatasource>(
    () => PickupAddressDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PickupAddressRepository>(
    () => PickupAddressRepository(getIt<PickupAddressDatasource>()),
  );
  getIt.registerFactory<PickupAddressBloc>(
    () => PickupAddressBloc(getIt<PickupAddressRepository>()),
  );

  // Address book — Recipients
  getIt.registerLazySingleton<RecipientDatasource>(
    () => RecipientDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<RecipientRepository>(
    () => RecipientRepository(getIt<RecipientDatasource>()),
  );
  getIt.registerFactory<RecipientBloc>(
    () => RecipientBloc(getIt<RecipientRepository>()),
  );

  // Address book — Favorite Travelers
  getIt.registerLazySingleton<FavoriteTravelerDatasource>(
    () => FavoriteTravelerDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<FavoriteTravelerRepository>(
    () => FavoriteTravelerRepository(getIt<FavoriteTravelerDatasource>()),
  );
  getIt.registerFactory<FavoriteTravelerBloc>(
    () => FavoriteTravelerBloc(getIt<FavoriteTravelerRepository>()),
  );

  // Package request marketplace
  getIt.registerLazySingleton<PackageRequestRepository>(
    () => PackageRequestRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<NegotiationRepository>(
    () => NegotiationRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PriceEstimationRepository>(
    () => PriceEstimationRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<PackageRequestFormBloc>(
    () => PackageRequestFormBloc(getIt<PackageRequestRepository>()),
  );
  getIt.registerFactory<PackageRequestSearchBloc>(
    () => PackageRequestSearchBloc(getIt<PackageRequestRepository>()),
  );
  getIt.registerFactory<PackageRequestBloc>(
    () => PackageRequestBloc(getIt<PackageRequestRepository>()),
  );
  getIt.registerFactory<NegotiationBloc>(
    () => NegotiationBloc(getIt<NegotiationRepository>()),
  );
  getIt.registerFactory<NegotiationListBloc>(
    () => NegotiationListBloc(getIt<NegotiationRepository>()),
  );
  getIt.registerFactory<CompleteDetailsBloc>(
    () => CompleteDetailsBloc(getIt<PackageRequestRepository>()),
  );
}
