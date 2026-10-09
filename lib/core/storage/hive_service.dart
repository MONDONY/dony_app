import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String offlineQueueBox = 'offline_queue';
  static const String userPrefsBox = 'user_prefs';

  // Feuille « Ne manquez aucun appel » (appels Yadony sur l'écran verrouillé,
  // FLUTTER-92), montrée une seule fois par installation.
  static const String kCallLockScreenPromptShown =
      'call_lock_screen_prompt_shown';

  // Carte d'introduction du hub Activités, fermée manuellement (X).
  static const String kHubIntroDismissed = 'hub_intro_dismissed';

  // Préfixe des clés de fermeture des ContextualTutorialCard, une par
  // tutoriel (id concaténé). Fermée par tap sur la carte (ouverture) comme
  // par le bouton X (sans ouvrir) — les deux masquent définitivement.
  static const String kContextualTutorialDismissedPrefix =
      'contextual_tutorial_dismissed_';

  /// Question d'intention aux comptes existants : nombre d'affichages et date
  /// du dernier (guidage après KYC, 2 affichages max à 7 jours d'écart).
  static const String kIntentPromptCount = 'intent_prompt_count';
  static const String kIntentPromptLastAt = 'intent_prompt_last_at';

  // ── Préférences app ──────────────────────────────────────────────────────
  static const String kThemeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const String kLanguageCode = 'language_code'; // 'system' | 'fr' | 'en'
  // 'fav_destinations' (destinations favorites) n'est plus lue ni écrite
  // (FLUTTER-H5) : la clé peut subsister sur d'anciens appareils, sans effet.

  // Trajets épinglés en tête de « Mes trajets » (FLUTTER-FS), propres à
  // l'appareil. List<String> d'identifiants d'annonce.
  static const String kPinnedTripIds = 'pinned_trip_ids';

  // 3 dernières villes sélectionnées par champ, affichées au focus avant
  // frappe (voir RecentCityStore). List<Map> sérialisation CityModel.toJson().
  static const String kRecentDepartureCities = 'recent_departure_cities';
  static const String kRecentArrivalCities = 'recent_arrival_cities';

  // ── Préférences métier ───────────────────────────────────────────────────
  static const String kWeightUnit = 'weight_unit'; // 'kg' | 'lbs'
  // Devise active, telle que renvoyée par le serveur (dérivée du pays) : une
  // des 7 devises de SupportedCurrency, jamais devinée côté client.
  static const String kCurrencyCode = 'currency_code';
  // Devise d'affichage (presentment, lot 8) : 'AUTO' = suivre la devise active,
  // sinon une des 7 devises. Purement visuelle, jamais verrouillee par le solde.
  static const String kDisplayCurrencyCode = 'display_currency_code';
  static const String kCountryCode =
      'country_code'; // ISO 3166-1 alpha-2, ou absent
  static const String kTravelerCountryUnsupported =
      'traveler_country_unsupported';
  static const String kPickupRadiusKm = 'pickup_radius_km'; // int
  static const String kDefaultPackageWeight = 'default_package_weight'; // int
  static const String kMinBidPrice = 'min_bid_price'; // int
  static const String kContactMode = 'contact_mode'; // String?
  static const String kResponseDelay = 'response_delay'; // int?

  // ── Accessibilité ────────────────────────────────────────────────────────
  // Clés héritées, lues une seule fois pour la migration puis supprimées.
  static const String kTextScale =
      'text_scale'; // 'small'|'normal'|'large'|'xlarge'
  static const String kHighContrast = 'high_contrast'; // bool
  static const String kReduceAnimations = 'reduce_animations'; // bool

  static const String kA11yFollowSystemTextScale =
      'a11y_follow_system_text_scale'; // bool
  static const String kA11yTextScaleFactor = 'a11y_text_scale_factor'; // double
  static const String kA11yHighContrast =
      'a11y_high_contrast'; // 'system'|'on'|'off'
  static const String kA11yReduceMotion =
      'a11y_reduce_motion'; // 'system'|'on'|'off'
  static const String kA11yBoldText = 'a11y_bold_text'; // bool
  static const String kA11yUnderlineLinks = 'a11y_underline_links'; // bool
  static const String kA11yReinforceLabels = 'a11y_reinforce_labels'; // bool
  static const String kA11yPersistentMessages =
      'a11y_persistent_messages'; // bool
  static const String kA11yConfirmImportant = 'a11y_confirm_important'; // bool

  // ── Confidentialité ──────────────────────────────────────────────────────
  static const String kProfileVisibility =
      'profile_visibility'; // 'public' | 'limited'
  static const String kHidePhoneNumber = 'hide_phone_number'; // bool
  static const String kShowResidenceCountry = 'show_residence_country'; // bool
  static const String kShowLastSeen = 'show_last_seen'; // bool
  static const String kContactKycOnly = 'contact_kyc_only'; // bool

  // ── Sécurité ─────────────────────────────────────────────────────────────
  static const String kBiometricEnabled = 'biometric_enabled'; // bool
  static const String kAppLockBiometric = 'app_lock_biometric'; // bool

  // ── Analytics (consentement RGPD opt-in) ─────────────────────────────────
  // null = pas encore demandé · true = accepté · false = refusé.
  static const String kAnalyticsConsent = 'analytics_consent'; // bool?
  // true une fois le SDK PostHog vérifié/réparé (identify parti en opt-out).
  static const String kPosthogIdentityRepaired =
      'posthog_identity_repaired_v1'; // bool
  // Code ISO-3166-1 alpha-2 détecté par GPS (ex: 'FR', 'SN'). Absent = non détecté.
  static const String kDetectedCountryCode = 'detected_country_code'; // String?

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
