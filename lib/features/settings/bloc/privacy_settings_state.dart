part of 'privacy_settings_bloc.dart';

sealed class PrivacySettingsState {
  const PrivacySettingsState();
}

class PrivacySettingsInitial extends PrivacySettingsState {
  const PrivacySettingsInitial();
}

class PrivacySettingsLoading extends PrivacySettingsState {
  const PrivacySettingsLoading();
}

class PrivacySettingsLoaded extends PrivacySettingsState {
  final bool contactKycOnly;
  const PrivacySettingsLoaded({required this.contactKycOnly});

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsLoaded && other.contactKycOnly == contactKycOnly;

  @override
  int get hashCode => contactKycOnly.hashCode;
}

class PrivacySettingsError extends PrivacySettingsState {
  final String message;
  const PrivacySettingsError(this.message);

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
