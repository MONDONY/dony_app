import 'package:dony/core/storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UserPreferencesModel {
  final String themeMode;        // 'system' | 'light' | 'dark'
  final String languageCode;     // 'fr' | 'en'
  final bool smsAlertsEnabled;
  final List<String> favDestinations;
  final String weightUnit;       // 'kg' | 'lbs'
  final String currencyCode;     // 'EUR' | 'XOF' | 'XAF'
  final int pickupRadiusKm;
  final String textScale;        // 'small'|'normal'|'large'|'xlarge'
  final bool highContrast;
  final bool reduceAnimations;
  final String profileVisibility; // 'public' | 'limited'
  final bool hidePhoneNumber;

  const UserPreferencesModel({
    this.themeMode = 'system',
    this.languageCode = 'fr',
    this.smsAlertsEnabled = false,
    this.favDestinations = const [],
    this.weightUnit = 'kg',
    this.currencyCode = 'EUR',
    this.pickupRadiusKm = 10,
    this.textScale = 'normal',
    this.highContrast = false,
    this.reduceAnimations = false,
    this.profileVisibility = 'public',
    this.hidePhoneNumber = false,
  });

  UserPreferencesModel copyWith({
    String? themeMode,
    String? languageCode,
    bool? smsAlertsEnabled,
    List<String>? favDestinations,
    String? weightUnit,
    String? currencyCode,
    int? pickupRadiusKm,
    String? textScale,
    bool? highContrast,
    bool? reduceAnimations,
    String? profileVisibility,
    bool? hidePhoneNumber,
  }) => UserPreferencesModel(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    smsAlertsEnabled: smsAlertsEnabled ?? this.smsAlertsEnabled,
    favDestinations: favDestinations ?? this.favDestinations,
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    pickupRadiusKm: pickupRadiusKm ?? this.pickupRadiusKm,
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    reduceAnimations: reduceAnimations ?? this.reduceAnimations,
    profileVisibility: profileVisibility ?? this.profileVisibility,
    hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
  );

  factory UserPreferencesModel.fromHive(Box box) => UserPreferencesModel(
    themeMode: box.get(HiveService.kThemeMode, defaultValue: 'system') as String,
    languageCode: box.get(HiveService.kLanguageCode, defaultValue: 'fr') as String,
    smsAlertsEnabled: box.get(HiveService.kSmsAlertsEnabled, defaultValue: false) as bool,
    favDestinations: List<String>.from(
      box.get(HiveService.kFavDestinations, defaultValue: <String>[]) as List),
    weightUnit: box.get(HiveService.kWeightUnit, defaultValue: 'kg') as String,
    currencyCode: box.get(HiveService.kCurrencyCode, defaultValue: 'EUR') as String,
    pickupRadiusKm: box.get(HiveService.kPickupRadiusKm, defaultValue: 10) as int,
    textScale: box.get(HiveService.kTextScale, defaultValue: 'normal') as String,
    highContrast: box.get(HiveService.kHighContrast, defaultValue: false) as bool,
    reduceAnimations: box.get(HiveService.kReduceAnimations, defaultValue: false) as bool,
    profileVisibility: box.get(HiveService.kProfileVisibility, defaultValue: 'public') as String,
    hidePhoneNumber: box.get(HiveService.kHidePhoneNumber, defaultValue: false) as bool,
  );

  void writeToHive(Box box) {
    box.put(HiveService.kThemeMode, themeMode);
    box.put(HiveService.kLanguageCode, languageCode);
    box.put(HiveService.kSmsAlertsEnabled, smsAlertsEnabled);
    box.put(HiveService.kFavDestinations, favDestinations);
    box.put(HiveService.kWeightUnit, weightUnit);
    box.put(HiveService.kCurrencyCode, currencyCode);
    box.put(HiveService.kPickupRadiusKm, pickupRadiusKm);
    box.put(HiveService.kTextScale, textScale);
    box.put(HiveService.kHighContrast, highContrast);
    box.put(HiveService.kReduceAnimations, reduceAnimations);
    box.put(HiveService.kProfileVisibility, profileVisibility);
    box.put(HiveService.kHidePhoneNumber, hidePhoneNumber);
  }
}
