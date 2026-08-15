import 'package:dony/core/storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UserPreferencesModel {
  final String themeMode;
  final String languageCode;
  final List<String> favDestinations;
  final String weightUnit;
  final String currencyCode;
  final int pickupRadiusKm;
  final String profileVisibility;
  final bool hidePhoneNumber;
  final bool biometricEnabled;
  final bool appLockBiometricEnabled;

  const UserPreferencesModel({
    // Thème clair par défaut : le sombre reste accessible, mais il se choisit
    // explicitement dans Réglages (« Système » y compris).
    this.themeMode = 'light',
    this.languageCode = 'fr',
    this.favDestinations = const [],
    this.weightUnit = 'kg',
    this.currencyCode = 'EUR',
    this.pickupRadiusKm = 10,
    this.profileVisibility = 'public',
    this.hidePhoneNumber = false,
    this.biometricEnabled = false,
    this.appLockBiometricEnabled = true,
  });

  UserPreferencesModel copyWith({
    String? themeMode,
    String? languageCode,
    List<String>? favDestinations,
    String? weightUnit,
    String? currencyCode,
    int? pickupRadiusKm,
    String? profileVisibility,
    bool? hidePhoneNumber,
    bool? biometricEnabled,
    bool? appLockBiometricEnabled,
  }) => UserPreferencesModel(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    favDestinations: favDestinations ?? this.favDestinations,
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    pickupRadiusKm: pickupRadiusKm ?? this.pickupRadiusKm,
    profileVisibility: profileVisibility ?? this.profileVisibility,
    hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    appLockBiometricEnabled:
        appLockBiometricEnabled ?? this.appLockBiometricEnabled,
  );

  factory UserPreferencesModel.fromHive(Box box) => UserPreferencesModel(
    themeMode: box.get(HiveService.kThemeMode, defaultValue: 'light') as String,
    languageCode:
        box.get(HiveService.kLanguageCode, defaultValue: 'fr') as String,
    favDestinations: List<String>.from(
      box.get(HiveService.kFavDestinations, defaultValue: <String>[]) as List,
    ),
    weightUnit: box.get(HiveService.kWeightUnit, defaultValue: 'kg') as String,
    currencyCode:
        box.get(HiveService.kCurrencyCode, defaultValue: 'EUR') as String,
    pickupRadiusKm:
        box.get(HiveService.kPickupRadiusKm, defaultValue: 10) as int,
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
    box.put(HiveService.kFavDestinations, favDestinations);
    box.put(HiveService.kWeightUnit, weightUnit);
    box.put(HiveService.kCurrencyCode, currencyCode);
    box.put(HiveService.kPickupRadiusKm, pickupRadiusKm);
    box.put(HiveService.kProfileVisibility, profileVisibility);
    box.put(HiveService.kHidePhoneNumber, hidePhoneNumber);
    box.put(HiveService.kBiometricEnabled, biometricEnabled);
    box.put(HiveService.kAppLockBiometric, appLockBiometricEnabled);
  }
}
