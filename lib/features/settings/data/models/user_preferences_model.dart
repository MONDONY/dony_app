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

  /// Bulle flottante de l'assistant : côtés possibles et hauteur par défaut.
  static const String kBubbleSideLeft = 'left';
  static const String kBubbleSideRight = 'right';
  static const double kDefaultAssistantBubbleY = 0.65;

  final String themeMode;
  final String languageCode;
  final String weightUnit;
  final String currencyCode;
  final String profileVisibility;
  final bool hidePhoneNumber;
  final bool biometricEnabled;
  final bool appLockBiometricEnabled;
  final bool assistantBubbleEnabled;
  final String assistantBubbleSide;
  final double assistantBubbleY;
  final bool assistantHintSeen;

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
    this.assistantBubbleEnabled = true,
    this.assistantBubbleSide = kBubbleSideRight,
    this.assistantBubbleY = kDefaultAssistantBubbleY,
    this.assistantHintSeen = false,
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
    bool? assistantBubbleEnabled,
    String? assistantBubbleSide,
    double? assistantBubbleY,
    bool? assistantHintSeen,
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
    assistantBubbleEnabled:
        assistantBubbleEnabled ?? this.assistantBubbleEnabled,
    assistantBubbleSide: assistantBubbleSide ?? this.assistantBubbleSide,
    assistantBubbleY: assistantBubbleY ?? this.assistantBubbleY,
    assistantHintSeen: assistantHintSeen ?? this.assistantHintSeen,
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
    assistantBubbleEnabled: _readBool(
      box,
      HiveService.kAssistantBubbleEnabled,
      defaultValue: true,
    ),
    assistantBubbleSide: normalizeBubbleSide(
      box.get(HiveService.kAssistantBubbleSide, defaultValue: kBubbleSideRight),
    ),
    assistantBubbleY: normalizeBubbleY(
      box.get(
        HiveService.kAssistantBubbleY,
        defaultValue: kDefaultAssistantBubbleY,
      ),
    ),
    assistantHintSeen: _readBool(
      box,
      HiveService.kAssistantHintSeen,
      defaultValue: false,
    ),
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
    box.put(HiveService.kAssistantBubbleEnabled, assistantBubbleEnabled);
    box.put(HiveService.kAssistantBubbleSide, assistantBubbleSide);
    box.put(HiveService.kAssistantBubbleY, assistantBubbleY);
    box.put(HiveService.kAssistantHintSeen, assistantHintSeen);
  }

  /// Côté de la bulle : seule la valeur `'left'` garde la gauche, tout le
  /// reste (valeur inconnue, absente, non textuelle) retombe à droite.
  static String normalizeBubbleSide(Object? raw) =>
      raw == kBubbleSideLeft ? kBubbleSideLeft : kBubbleSideRight;

  /// Hauteur de la bulle, toujours dans [0, 1]. Un nombre hors bornes est
  /// ramené à la borne ; NaN ou une valeur d'un autre type (String, null…)
  /// revient au défaut, sans jamais lever d'exception.
  static double normalizeBubbleY(Object? raw) {
    if (raw is! num) return kDefaultAssistantBubbleY;
    final y = raw.toDouble();
    if (y.isNaN) return kDefaultAssistantBubbleY;
    return y.clamp(0.0, 1.0).toDouble();
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

  static bool _readBool(Box box, String key, {required bool defaultValue}) {
    final raw = box.get(key, defaultValue: defaultValue);
    return raw is bool ? raw : defaultValue;
  }
}
