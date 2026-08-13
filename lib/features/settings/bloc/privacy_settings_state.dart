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
  /// ne peut alors me joindre que par la messagerie Yadony.
  final bool hidePhoneNumber;

  /// Le dernier enregistrement a échoué et l'interrupteur vient d'être remis à
  /// sa valeur précédente. Sans ce drapeau, un rollback est indiscernable d'un
  /// « le réglage refuse de changer » : l'écran doit pouvoir le dire.
  final bool saveFailed;

  const PrivacySettingsLoaded({
    required this.contactKycOnly,
    this.hidePhoneNumber = false,
    this.saveFailed = false,
  });

  PrivacySettingsLoaded copyWith({
    bool? contactKycOnly,
    bool? hidePhoneNumber,
    bool? saveFailed,
  }) => PrivacySettingsLoaded(
    contactKycOnly: contactKycOnly ?? this.contactKycOnly,
    hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsLoaded &&
      other.contactKycOnly == contactKycOnly &&
      other.hidePhoneNumber == hidePhoneNumber &&
      other.saveFailed == saveFailed;

  @override
  int get hashCode => Object.hash(contactKycOnly, hidePhoneNumber, saveFailed);
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
