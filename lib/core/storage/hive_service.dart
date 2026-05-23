import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String offlineQueueBox = 'offline_queue';
  static const String userPrefsBox = 'user_prefs';

  // Clés pour les flags "premier pas" (onboarding par rôle)
  static const String kHasPublishedAsTraveler = 'has_published_as_traveler';
  static const String kHasPublishedAsSender = 'has_published_as_sender';

  // Timestamp (ms epoch) de la première vue du banner expéditeur ; le banner
  // expire 5 min après cette première vue.
  static const String kSenderBannerFirstSeenAt = 'sender_banner_first_seen_at';

  // Drapeaux de fermeture manuelle (X) des banners d'onboarding.
  static const String kTravelerBannerDismissed = 'traveler_banner_dismissed';
  static const String kSenderBannerDismissed = 'sender_banner_dismissed';

  // ── Préférences app ──────────────────────────────────────────────────────
  static const String kThemeMode         = 'theme_mode';       // 'system' | 'light' | 'dark'
  static const String kLanguageCode      = 'language_code';    // 'fr' | 'en'
  static const String kFavDestinations   = 'fav_destinations'; // List<String> ex: ['SN','CI']

  // ── Préférences métier ───────────────────────────────────────────────────
  static const String kWeightUnit        = 'weight_unit';      // 'kg' | 'lbs'
  static const String kCurrencyCode      = 'currency_code';    // 'EUR' | 'XOF' | 'XAF'
  static const String kPickupRadiusKm    = 'pickup_radius_km'; // int

  // ── Accessibilité ────────────────────────────────────────────────────────
  static const String kTextScale         = 'text_scale';       // 'small'|'normal'|'large'|'xlarge'
  static const String kHighContrast      = 'high_contrast';    // bool
  static const String kReduceAnimations  = 'reduce_animations';// bool

  // ── Confidentialité ──────────────────────────────────────────────────────
  static const String kProfileVisibility = 'profile_visibility'; // 'public' | 'limited'
  static const String kHidePhoneNumber   = 'hide_phone_number'; // bool
  static const String kContactKycOnly    = 'contact_kyc_only';  // bool

  // ── Sécurité ─────────────────────────────────────────────────────────────
  static const String kBiometricEnabled   = 'biometric_enabled'; // bool
  static const String kAppLockBiometric   = 'app_lock_biometric'; // bool

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(offlineQueueBox);
    await Hive.openBox(userPrefsBox);
  }

  Box<Map> get offlineQueue => Hive.box<Map>(offlineQueueBox);

  Box get userPrefs => Hive.box(userPrefsBox);

  ValueListenable<Box> listenUserPrefs({required List<String> keys}) =>
      userPrefs.listenable(keys: keys);
}
