part of 'accessibility_bloc.dart';

/// Valeurs possibles des réglages tri-états.
///
/// Stockées en `String` et non en `bool?` : Hive ne distingue pas une clé
/// absente d'une clé à `null`, ce qui rendrait « jamais choisi » et
/// « explicitement désactivé » indiscernables.
abstract final class AccessibilityMode {
  static const String system = 'system';
  static const String on = 'on';
  static const String off = 'off';

  static const List<String> values = [system, on, off];

  /// Vrai si [mode] est une valeur connue. Toute autre valeur, lue depuis un
  /// box corrompu, doit retomber sur [system].
  static bool isValid(String? mode) => mode != null && values.contains(mode);
}

/// Bornes du facteur de taille de texte.
///
/// Le plafond à 2.0 vient de WCAG 1.4.4 : les contenus doivent rester
/// utilisables jusqu'à 200 %. Au-delà, les écrans ne sont pas tenables.
const double kA11yMinTextScale = 0.85;
const double kA11yMaxTextScale = 2.0;

class AccessibilityState extends Equatable {
  const AccessibilityState({
    this.followSystemTextScale = true,
    this.textScaleFactor = 1.0,
    this.highContrast = AccessibilityMode.system,
    this.reduceMotion = AccessibilityMode.system,
    this.boldText = false,
    this.underlineLinks = false,
    this.reinforceLabels = false,
    this.persistentMessages = false,
    this.confirmImportantActions = false,
  });

  /// Quand vrai, la taille suit le réglage du système et [textScaleFactor] est
  /// ignoré.
  final bool followSystemTextScale;

  /// Facteur appliqué quand [followSystemTextScale] est faux. Borné entre
  /// [kA11yMinTextScale] et [kA11yMaxTextScale].
  final double textScaleFactor;

  final String highContrast;
  final String reduceMotion;
  final bool boldText;
  final bool underlineLinks;
  final bool reinforceLabels;
  final bool persistentMessages;
  final bool confirmImportantActions;

  AccessibilityState copyWith({
    bool? followSystemTextScale,
    double? textScaleFactor,
    String? highContrast,
    String? reduceMotion,
    bool? boldText,
    bool? underlineLinks,
    bool? reinforceLabels,
    bool? persistentMessages,
    bool? confirmImportantActions,
  }) =>
      AccessibilityState(
        followSystemTextScale:
            followSystemTextScale ?? this.followSystemTextScale,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        highContrast: highContrast ?? this.highContrast,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        boldText: boldText ?? this.boldText,
        underlineLinks: underlineLinks ?? this.underlineLinks,
        reinforceLabels: reinforceLabels ?? this.reinforceLabels,
        persistentMessages: persistentMessages ?? this.persistentMessages,
        confirmImportantActions:
            confirmImportantActions ?? this.confirmImportantActions,
      );

  @override
  List<Object?> get props => [
        followSystemTextScale,
        textScaleFactor,
        highContrast,
        reduceMotion,
        boldText,
        underlineLinks,
        reinforceLabels,
        persistentMessages,
        confirmImportantActions,
      ];
}
