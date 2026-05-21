import 'package:dony/core/storage/hive_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'privacy_settings_event.dart';
part 'privacy_settings_state.dart';

class PrivacySettingsBloc
    extends Bloc<PrivacySettingsEvent, PrivacySettingsState> {
  final Box _box;

  PrivacySettingsBloc(this._box)
      : super(PrivacySettingsState(
          profileVisibility: _box.get(
            HiveService.kProfileVisibility,
            defaultValue: 'public',
          ) as String,
          hidePhoneNumber: _box.get(
            HiveService.kHidePhoneNumber,
            defaultValue: false,
          ) as bool,
        )) {
    on<ProfileVisibilityChanged>(_onVisibilityChanged);
    on<HidePhoneToggled>(_onHidePhoneToggled);
  }

  void _onVisibilityChanged(
    ProfileVisibilityChanged event,
    Emitter<PrivacySettingsState> emit,
  ) {
    _box.put(HiveService.kProfileVisibility, event.visibility);
    emit(state.copyWith(profileVisibility: event.visibility));
  }

  void _onHidePhoneToggled(
    HidePhoneToggled event,
    Emitter<PrivacySettingsState> emit,
  ) {
    final next = !state.hidePhoneNumber;
    _box.put(HiveService.kHidePhoneNumber, next);
    emit(state.copyWith(hidePhoneNumber: next));
  }
}
