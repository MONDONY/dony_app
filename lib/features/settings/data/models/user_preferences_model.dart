import 'package:dony/core/storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Préférences locales (Hive, clé/valeur, sans adaptateur ni typeId).
///
/// L'ancienne clé `fav_destinations` (section « Destinations favorites »,
/// retirée : FLUTTER-H5) peut rester dans la boîte des appareils existants ;
/// elle n'est plus ni lue ni écrite, ce qui ne gêne pas la lecture des autres.
/// Même chose pour `pickup_radius_km` (« Rayon de collecte », retiré le
/// 2026-10-11 : le réglage n'avait aucun effet).
class UserPreferencesModel {
  /// Langue de l'app : `'system'` suit le téléphone, `'fr'`/`'en'` forcent.
  static const String kLanguageSystem = 'system';
  static const Set<String> _languageCodes = {kLanguageSystem, 'fr', 'en'};

  final String themeMode;
  final String languageCode;
  final String weightUnit;
  final String currencyCode;
  final String profileVisibility;
  final bool hidePhoneNumber;
  final bool biometricEnabled;
  final bool appLockBiometricEnabled;

  const UserPreferencesModel({
    // Thème clair par défaut : le sombre reste accessible, mais il se choisit
    // explicitement dans Réglages (« Système » y compris).
    this.themeMode = 'light',
    this.languageCode = kLanguageSystem,
    this.weightUnit = 'kg',
    this.currencyCode = 'EUR',
    this.profileVisibility = 'public',
    this.hidePhoneNumber = false,
    this.biometricEnabled = false,
    this.appLockBiometricEnabled = true,
  });

  UserPreferencesModel copyWith({
    String? themeMode,
    String? languageCode,
    String? weightUnit,
    String? currencyCode,
    String? profileVisibility,
    bool? hidePhoneNumber,
    bool? biometricEnabled,
    bool? appLockBiometricEnabled,
  }) => UserPreferencesModel(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    profileVisibility: profileVisibility ?? this.profileVisibility,
    hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    appLockBiometricEnabled:
        appLockBiometricEnabled ?? this.appLockBiometricEnabled,
  );

  factory UserPreferencesModel.fromHive(Box box) => UserPreferencesModel(
    themeMode: box.get(HiveService.kThemeMode, defaultValue: 'light') as String,
    languageCode: _readLanguageCode(box),
    weightUnit: box.get(HiveService.kWeightUnit, defaultValue: 'kg') as String,
    currencyCode:
        box.get(HiveService.kCurrencyCode, defaultValue: 'EUR') as String,
    profileVisibility:
        box.get(HiveService.kProfileVisibility, defaultValue: 'public')
            as String,
    hidePhoneNumber:
        box.get(HiveService.kHidePhoneNumber, defaultValue: false) as bool,
    biometricEnabled:
        box.get(HiveService.kBiometricEnabled, defaultValue: false) as bool,
    appLockBiometricEnabled:
        box.get(HiveService.kAppLockBiometric, defaultValue: true) as bool,
  );

  void writeToHive(Box box) {
    box.put(HiveService.kThemeMode, themeMode);
    box.put(HiveService.kLanguageCode, languageCode);
    box.put(HiveService.kWeightUnit, weightUnit);
    box.put(HiveService.kCurrencyCode, currencyCode);
    box.put(HiveService.kProfileVisibility, profileVisibility);
    box.put(HiveService.kHidePhoneNumber, hidePhoneNumber);
    box.put(HiveService.kBiometricEnabled, biometricEnabled);
    box.put(HiveService.kAppLockBiometric, appLockBiometricEnabled);
  }

  static String _readLanguageCode(Box box) {
    final raw = box.get(
      HiveService.kLanguageCode,
      defaultValue: kLanguageSystem,
    );
    return raw is String && _languageCodes.contains(raw)
        ? raw
        : kLanguageSystem;
  }
}
