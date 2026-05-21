part of 'privacy_settings_bloc.dart';

abstract class PrivacySettingsEvent extends Equatable {
  const PrivacySettingsEvent();

  @override
  List<Object?> get props => [];
}

class ProfileVisibilityChanged extends PrivacySettingsEvent {
  final String visibility; // 'public' | 'limited'

  const ProfileVisibilityChanged(this.visibility);

  @override
  List<Object?> get props => [visibility];
}

class HidePhoneToggled extends PrivacySettingsEvent {
  const HidePhoneToggled();
}
