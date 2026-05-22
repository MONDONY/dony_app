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

class DestinationToggled extends AppPreferencesEvent {
  final String countryCode; // 'SN' | 'CI' | 'ML' | 'CM'
  const DestinationToggled(this.countryCode);

  @override
  List<Object?> get props => [countryCode];
}

class BiometricToggled extends AppPreferencesEvent {
  const BiometricToggled();
}
