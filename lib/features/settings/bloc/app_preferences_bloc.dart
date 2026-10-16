import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'app_preferences_event.dart';
part 'app_preferences_state.dart';

class AppPreferencesBloc
    extends Bloc<AppPreferencesEvent, AppPreferencesState> {
  final Box _box;

  AppPreferencesBloc(this._box)
    : super(
        AppPreferencesState(preferences: UserPreferencesModel.fromHive(_box)),
      ) {
    on<ThemeChanged>(_onThemeChanged);
    on<LanguageChanged>(_onLanguageChanged);
    on<BiometricToggled>(_onBiometricToggled);
    on<AppLockBiometricToggled>(_onAppLockBiometricToggled);
    on<AssistantBubbleToggled>(_onAssistantBubbleToggled);
    on<AssistantBubbleMoved>(_onAssistantBubbleMoved);
    on<AssistantBubbleReset>(_onAssistantBubbleReset);
    on<AssistantHintDismissed>(_onAssistantHintDismissed);
  }

  void _onThemeChanged(ThemeChanged event, Emitter<AppPreferencesState> emit) {
    final updated = state.preferences.copyWith(themeMode: event.themeMode);
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onLanguageChanged(
    LanguageChanged event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(
      languageCode: event.languageCode,
    );
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

  void _onAssistantBubbleToggled(
    AssistantBubbleToggled event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(
      assistantBubbleEnabled: event.enabled,
    );
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onAssistantBubbleMoved(
    AssistantBubbleMoved event,
    Emitter<AppPreferencesState> emit,
  ) {
    final current = state.preferences;
    // Un NaN venu du geste ne doit pas écraser la position connue.
    final y = event.y.isNaN
        ? current.assistantBubbleY
        : UserPreferencesModel.normalizeBubbleY(event.y);
    final updated = current.copyWith(
      assistantBubbleSide: UserPreferencesModel.normalizeBubbleSide(event.side),
      assistantBubbleY: y,
    );
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onAssistantBubbleReset(
    AssistantBubbleReset event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(
      assistantBubbleSide: UserPreferencesModel.kBubbleSideRight,
      assistantBubbleY: UserPreferencesModel.kDefaultAssistantBubbleY,
    );
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }

  void _onAssistantHintDismissed(
    AssistantHintDismissed event,
    Emitter<AppPreferencesState> emit,
  ) {
    final updated = state.preferences.copyWith(assistantHintSeen: true);
    updated.writeToHive(_box);
    emit(AppPreferencesState(preferences: updated));
  }
}
