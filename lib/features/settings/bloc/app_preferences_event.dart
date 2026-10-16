part of 'app_preferences_bloc.dart';

abstract class AppPreferencesEvent extends Equatable {
  const AppPreferencesEvent();

  @override
  List<Object?> get props => [];
}

class ThemeChanged extends AppPreferencesEvent {
  final String themeMode; // 'system' | 'light' | 'dark'
  const ThemeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class LanguageChanged extends AppPreferencesEvent {
  final String languageCode;
  const LanguageChanged(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class BiometricToggled extends AppPreferencesEvent {
  const BiometricToggled();
}

class AppLockBiometricToggled extends AppPreferencesEvent {
  const AppLockBiometricToggled();
}

class AssistantBubbleToggled extends AppPreferencesEvent {
  final bool enabled;
  const AssistantBubbleToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Déplacement de la bulle : le côté est normalisé (inconnu → droite) et la
/// hauteur bornée entre 0 et 1 (NaN ignoré, la hauteur courante est gardée).
class AssistantBubbleMoved extends AppPreferencesEvent {
  final String side; // 'left' | 'right'
  final double y; // 0 à 1
  const AssistantBubbleMoved(this.side, this.y);

  @override
  List<Object?> get props => [side, y];
}

class AssistantBubbleReset extends AppPreferencesEvent {
  const AssistantBubbleReset();
}

class AssistantHintDismissed extends AppPreferencesEvent {
  const AssistantHintDismissed();
}
