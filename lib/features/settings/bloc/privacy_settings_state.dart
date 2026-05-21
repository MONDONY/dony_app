part of 'privacy_settings_bloc.dart';

class PrivacySettingsState extends Equatable {
  final String profileVisibility;
  final bool hidePhoneNumber;

  const PrivacySettingsState({
    this.profileVisibility = 'public',
    this.hidePhoneNumber = false,
  });

  PrivacySettingsState copyWith({
    String? profileVisibility,
    bool? hidePhoneNumber,
  }) =>
      PrivacySettingsState(
        profileVisibility: profileVisibility ?? this.profileVisibility,
        hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
      );

  @override
  List<Object?> get props => [profileVisibility, hidePhoneNumber];
}
