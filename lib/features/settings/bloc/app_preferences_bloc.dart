import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'app_preferences_event.dart';
part 'app_preferences_state.dart';

class AppPreferencesBloc extends Bloc<AppPreferencesEvent, AppPreferencesState> {
  final Box _box;

  AppPreferencesBloc(this._box)
      : super(AppPreferencesState(
          preferences: UserPreferencesModel.fromHive(_box),
        )) {
    on<ThemeChanged>(_onThemeChanged);
    on<LanguageChanged>(_onLanguageChanged);
    on<DestinationToggled>(_onDestinationToggled);
    on<BiometricToggled>(_onBiometricToggled);
    on<AppLockBiometricToggled>(_onAppLockBiometricToggled);
  }

  void _onThemeChanged(
    ThemeChanged event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(themeMode: event.themeMode);
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onLanguageChanged(
    LanguageChanged event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated =
        state.preferences.copyWith(languageCode: event.languageCode);
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onDestinationToggled(
    DestinationToggled event,
    Emitter<AppPreferencesState> emit,
  ) {
    final current = List<String>.from(state.preferences.favDestinations);
    if (current.contains(event.countryCode)) {
      current.remove(event.countryCode);
    } else {
      current.add(event.countryCode);
    }
    final updated = state.preferences.copyWith(favDestinations: current);
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onBiometricToggled(
    BiometricToggled event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(
      biometricEnabled: !state.preferences.biometricEnabled,
    );
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onAppLockBiometricToggled(
    AppLockBiometricToggled event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(
      appLockBiometricEnabled: !state.preferences.appLockBiometricEnabled,
    );
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }
}
