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

  /// Mon numéro reste masqué même après acceptation d'une offre : ma contrepartie
  /// ne peut alors me joindre que par la messagerie dony.
  final bool hidePhoneNumber;

  const PrivacySettingsLoaded({
    required this.contactKycOnly,
    this.hidePhoneNumber = false,
  });

  PrivacySettingsLoaded copyWith({bool? contactKycOnly, bool? hidePhoneNumber}) =>
      PrivacySettingsLoaded(
        contactKycOnly: contactKycOnly ?? this.contactKycOnly,
        hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
      );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsLoaded &&
      other.contactKycOnly == contactKycOnly &&
      other.hidePhoneNumber == hidePhoneNumber;

  @override
  int get hashCode => Object.hash(contactKycOnly, hidePhoneNumber);
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
