import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/data/datasources/delivery_address_datasource.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/data/datasources/trip_template_datasource.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/data/datasources/trip_recurrence_datasource.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_recurrence_repository.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/datasources/pickup_address_datasource.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/data/subscriptions_remote_datasource.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
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
import 'package:dony/features/profile/bloc/traveler_upgrade_bloc.dart';
import 'package:dony/features/profile/data/pro_stats_repository.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/profile/data/traveler_upgrade_repository.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/data/datasources/blocked_users_datasource.dart';
import 'package:dony/features/settings/data/datasources/business_prefs_remote_datasource.dart';
import 'package:dony/features/settings/data/datasources/privacy_settings_datasource.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:dony/features/settings/data/connected_devices_datasource.dart';
import 'package:dony/features/settings/data/connected_devices_repository.dart';
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
import 'package:dony/core/services/analytics_consent_remote.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/device_id_service.dart';
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
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/data/datasources/price_grid_datasource.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
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
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/data/datasources/commission_method_remote_datasource.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/referral_datasource.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/data/stripe_account_datasource.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies({required String apiBaseUrl}) async {
  // Core
  getIt.registerLazySingleton<HiveService>(() => HiveService());
  getIt.registerLazySingleton<AnalyticsConsentRemote>(
    () => ApiAnalyticsConsentRemote(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AnalyticsService>(
    () => AnalyticsService(
      getIt<HiveService>(),
      remote: getIt<AnalyticsConsentRemote>(),
    ),
  );
  getIt.registerLazySingleton<ActiveRoleCubit>(
    () => ActiveRoleCubit(hiveService: getIt<HiveService>()),
  );
  getIt.registerLazySingleton<DeviceIdService>(() => DeviceIdService());
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: apiBaseUrl,
      deviceIdService: getIt<DeviceIdService>(),
    ),
  );
  getIt.registerLazySingleton<NotificationRemoteDatasource>(
    () => NotificationRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(getIt<NotificationRemoteDatasource>()),
  );
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService(
      getIt<ApiClient>(),
      getIt<NotificationRepository>(),
      getIt<DeviceIdService>(),
    ),
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
    () => AuthBloc(
      getIt<AuthRepository>(),
      getIt<LocalAuthService>(),
      analytics: getIt<AnalyticsService>(),
    ),
  );

  // Local auth (biometric + PIN)
  getIt.registerLazySingleton<LocalAuthService>(() => LocalAuthService());
  getIt.registerFactory<LocalAuthBloc>(
    () => LocalAuthBloc(
      getIt<LocalAuthService>(),
      getIt<HiveService>().userPrefs,
    ),
  );

  // KYC
  getIt.registerLazySingleton<KycRepository>(
    () => KycRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<KycBloc>(
    () => KycBloc(getIt<KycRepository>(), getIt<AnalyticsService>()),
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
      getIt<AnalyticsService>(),
    ),
  );
  getIt.registerFactory<TripsSummaryCubit>(
    () => TripsSummaryCubit(getIt<AnnouncementRepository>()),
  );
  getIt.registerFactory<TripFilterCubit>(
    () => TripFilterCubit(getIt<AnalyticsService>()),
  );

  // Price Grid
  getIt.registerLazySingleton<PriceGridDatasource>(
    () => PriceGridDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PriceGridRepository>(
    () => PriceGridRepository(getIt<PriceGridDatasource>()),
  );
  getIt.registerFactory<PriceGridBloc>(
    () => PriceGridBloc(getIt<PriceGridRepository>()),
  );

  // Matching — Bids
  getIt.registerLazySingleton<BidRemoteDatasource>(
    () => BidRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BidRepository>(
    () => BidRepository(getIt<BidRemoteDatasource>()),
  );
  getIt.registerFactory<BidBloc>(
    () => BidBloc(getIt<BidRepository>(), getIt<AnalyticsService>()),
  );
  getIt.registerFactory<ShipmentFilterCubit>(
    () => ShipmentFilterCubit(getIt<AnalyticsService>()),
  );

  // Matching — Mobile Money
  getIt.registerLazySingleton<MobileMoneyRemoteDatasource>(
    () => MobileMoneyRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<MobileMoneyRepository>(
    () => MobileMoneyRepository(getIt<MobileMoneyRemoteDatasource>()),
  );
  getIt.registerFactory<MobileMoneyPaymentBloc>(
    () => MobileMoneyPaymentBloc(getIt<MobileMoneyRepository>()),
  );

  // Cash commission method
  getIt.registerLazySingleton<CommissionMethodRemoteDatasource>(
    () => CommissionMethodRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CommissionMethodRepository>(
    () => CommissionMethodRepository(getIt<CommissionMethodRemoteDatasource>()),
  );
  getIt.registerFactory<CommissionMethodBloc>(
    () => CommissionMethodBloc(getIt<CommissionMethodRepository>()),
  );
  getIt.registerFactory<BidAcceptanceBloc>(
    () => BidAcceptanceBloc(getIt<BidRepository>(), Stripe.instance, getIt<AnalyticsService>()),
  );
  getIt.registerFactory<BidListFilterCubit>(
    () => BidListFilterCubit(),
  );

  // Payments
  getIt.registerLazySingleton<PaymentRemoteDatasource>(
    () => PaymentRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PaymentRepository>(
    () => PaymentRepository(getIt<PaymentRemoteDatasource>()),
  );
  getIt.registerFactory<PaymentBloc>(
    () => PaymentBloc(getIt<PaymentRepository>(), getIt<AnalyticsService>()),
  );

  // Wallet
  getIt.registerLazySingleton<WalletRemoteDatasource>(
    () => WalletRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<WalletRepository>(
    () => WalletRepository(getIt<WalletRemoteDatasource>()),
  );
  getIt.registerFactory<WalletBloc>(
    () => WalletBloc(getIt<WalletRepository>(), getIt<AnalyticsService>()),
  );

  // Cancellation
  getIt.registerLazySingleton<CancellationRemoteDatasource>(
    () => CancellationRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CancellationRepository>(
    () => CancellationRepository(getIt<CancellationRemoteDatasource>()),
  );
  getIt.registerFactory<CancellationBloc>(
    () => CancellationBloc(getIt<CancellationRepository>(), getIt<AnalyticsService>()),
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
      getIt<AnalyticsService>(),
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
  getIt.registerLazySingleton<TravelerUpgradeRepository>(
    () => TravelerUpgradeRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<TravelerUpgradeBloc>(
    () => TravelerUpgradeBloc(getIt<TravelerUpgradeRepository>()),
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
      getIt<AnalyticsService>(),
    ),
  );

  // Settings — Data Export (RGPD)
  getIt.registerFactory<DataExportBloc>(
    () => DataExportBloc(getIt<ApiClient>()),
  );

  // Settings — App Preferences (theme, language, SMS, destinations)
  getIt.registerLazySingleton<AppPreferencesBloc>(
    () => AppPreferencesBloc(getIt<HiveService>().userPrefs),
  );

  // Settings — Privacy (contactKycOnly via backend)
  getIt.registerLazySingleton<PrivacySettingsDatasource>(
    () => PrivacySettingsDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PrivacySettingsRepository>(
    () => PrivacySettingsRepository(getIt<PrivacySettingsDatasource>()),
  );
  getIt.registerFactory<PrivacySettingsBloc>(
    () => PrivacySettingsBloc(
      getIt<PrivacySettingsRepository>(),
      getIt<HiveService>().userPrefs,
    ),
  );
  getIt.registerLazySingleton<BlockedUsersDatasource>(
    () => BlockedUsersDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BlockedUsersRepository>(
    () => BlockedUsersRepository(getIt<BlockedUsersDatasource>()),
  );
  getIt.registerFactory<BlockedUsersBloc>(
    () => BlockedUsersBloc(getIt<BlockedUsersRepository>()),
  );

  // Settings — Notification preferences
  getIt.registerFactory<NotificationPrefsBloc>(
    () => NotificationPrefsBloc(getIt<HiveService>().userPrefs),
  );

  // Settings — Business preferences (Hive + API sync)
  getIt.registerLazySingleton<BusinessPrefsRemoteDatasource>(
    () => BusinessPrefsRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BusinessPrefsRepository>(
    () => BusinessPrefsRepository(getIt<BusinessPrefsRemoteDatasource>()),
  );
  getIt.registerLazySingleton<BusinessPrefsBloc>(
    () => BusinessPrefsBloc(getIt<BusinessPrefsRepository>(), getIt<HiveService>().userPrefs),
    dispose: (b) => b.close(),
  );

  // Settings — Accessibility (text scale, high contrast, reduce animations)
  getIt.registerFactory<AccessibilityBloc>(
    () => AccessibilityBloc(getIt<HiveService>().userPrefs),
  );

  // Settings — Diagnostics (version app + ping API)
  getIt.registerFactory<DiagnosticsBloc>(
    () => DiagnosticsBloc(getIt<ApiClient>()),
  );

  // Settings — Connected Devices
  getIt.registerLazySingleton<ConnectedDevicesDatasource>(
    () => ConnectedDevicesDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ConnectedDevicesRepository>(
    () => ConnectedDevicesRepository(getIt<ConnectedDevicesDatasource>()),
  );
  getIt.registerFactory<ConnectedDevicesBloc>(
    () => ConnectedDevicesBloc(getIt<ConnectedDevicesRepository>()),
  );

  // Ratings
  getIt.registerLazySingleton<RatingRepository>(
    () => RatingRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<RatingBloc>(
    () => RatingBloc(getIt<RatingRepository>(), getIt<AnalyticsService>()),
  );
  getIt.registerLazySingleton<MyReviewsBloc>(
    () => MyReviewsBloc(getIt<RatingRepository>()),
    dispose: (b) => b.close(),
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
    () => TrackingBloc(getIt<TrackingRepository>(), getIt<OfflineSyncService>(), getIt<AnalyticsService>()),
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

  // Address book — Delivery Addresses
  getIt.registerLazySingleton<DeliveryAddressDatasource>(
    () => DeliveryAddressDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<DeliveryAddressRepository>(
    () => DeliveryAddressRepository(getIt<DeliveryAddressDatasource>()),
  );
  getIt.registerFactory<DeliveryAddressBloc>(
    () => DeliveryAddressBloc(getIt<DeliveryAddressRepository>()),
  );

  // Trip templates — modèles de trajet réutilisables
  getIt.registerLazySingleton<TripTemplateDatasource>(
    () => TripTemplateDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TripTemplateRepository>(
    () => TripTemplateRepository(getIt<TripTemplateDatasource>()),
  );
  getIt.registerFactory<TripTemplateBloc>(
    () => TripTemplateBloc(getIt<TripTemplateRepository>()),
  );
  getIt.registerLazySingleton<TripRecurrenceDatasource>(
    () => TripRecurrenceDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TripRecurrenceRepository>(
    () => TripRecurrenceRepository(getIt<TripRecurrenceDatasource>()),
  );
  getIt.registerFactory<TripRecurrenceBloc>(
    () => TripRecurrenceBloc(getIt<TripRecurrenceRepository>()),
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

  // Subscriptions (abonnements voyageurs)
  getIt.registerLazySingleton<SubscriptionsRepository>(
    () => SubscriptionsRemoteDatasource(getIt<ApiClient>()),
  );
  getIt.registerFactory<SubscriptionsBloc>(
    () => SubscriptionsBloc(getIt<SubscriptionsRepository>()),
  );
  getIt.registerFactory<TravelerHubBloc>(
    () => TravelerHubBloc(getIt<SubscriptionsRepository>()),
  );
  getIt.registerFactory<TravelerSubscribeBloc>(
    () => TravelerSubscribeBloc(getIt<SubscriptionsRepository>()),
  );

  // Referral
  getIt.registerLazySingleton<ReferralDatasource>(
    () => ReferralDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReferralRepository>(
    () => ReferralRepository(getIt<ReferralDatasource>()),
  );
  getIt.registerLazySingleton<ReferralBloc>(
    () => ReferralBloc(getIt<ReferralRepository>(), getIt<AnalyticsService>()),
    dispose: (b) => b.close(),
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
  // param1 = demande à éditer (null → mode création).
  getIt.registerFactoryParam<PackageRequestFormBloc, PackageRequest?, void>(
    (editing, _) => PackageRequestFormBloc(
      getIt<PackageRequestRepository>(),
      analytics: getIt<AnalyticsService>(),
      editing: editing,
    ),
  );
  getIt.registerFactory<PackageRequestSearchBloc>(
    () => PackageRequestSearchBloc(getIt<PackageRequestRepository>(), getIt<AnalyticsService>()),
  );
  getIt.registerLazySingleton<PackageRequestBloc>(
    () => PackageRequestBloc(getIt<PackageRequestRepository>()),
    dispose: (b) => b.close(),
  );
  getIt.registerFactory<NegotiationBloc>(
    () => NegotiationBloc(getIt<NegotiationRepository>(), analytics: getIt<AnalyticsService>()),
  );
  getIt.registerLazySingleton<NegotiationListBloc>(
    () => NegotiationListBloc(getIt<NegotiationRepository>()),
    dispose: (b) => b.close(),
  );
  getIt.registerFactory<CompleteDetailsBloc>(
    () => CompleteDetailsBloc(getIt<PackageRequestRepository>()),
  );
  getIt.registerFactory<RequestFilterCubit>(
    () => RequestFilterCubit(),
  );
  getIt.registerFactory<NegotiationFilterCubit>(
    () => NegotiationFilterCubit(),
  );

  // Stripe account status (global singleton)
  getIt.registerLazySingleton<StripeAccountDatasource>(
    () => StripeAccountDatasource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<IStripeAccountRepository>(
    () => StripeAccountRepository(getIt<StripeAccountDatasource>()),
  );
  getIt.registerLazySingleton<StripeAccountBloc>(
    () => StripeAccountBloc(getIt<IStripeAccountRepository>()),
    dispose: (b) => b.close(),
  );
}
