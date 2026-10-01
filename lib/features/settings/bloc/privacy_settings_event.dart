part of 'privacy_settings_bloc.dart';

sealed class PrivacySettingsEvent {
  const PrivacySettingsEvent();
}

/// Charge la préférence contactKycOnly depuis le backend.
class PrivacySettingsLoadRequested extends PrivacySettingsEvent {
  const PrivacySettingsLoadRequested();
}

/// Met à jour la préférence contactKycOnly côté backend (optimistic update).
class ContactKycOnlyToggled extends PrivacySettingsEvent {
  final bool value;
  const ContactKycOnlyToggled(this.value);

  @override
  bool operator ==(Object other) =>
      other is ContactKycOnlyToggled && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Masque (true) ou révèle (false) mon numéro auprès de mes contreparties.
/// Même traitement optimiste que [ContactKycOnlyToggled].
/// Afficher ou non son pays de résidence sur son profil public (FLUTTER-4H).
class ShowResidenceCountryToggled extends PrivacySettingsEvent {
  final bool value;
  const ShowResidenceCountryToggled(this.value);

  @override
  bool operator ==(Object other) =>
      other is ShowResidenceCountryToggled && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class HidePhoneNumberToggled extends PrivacySettingsEvent {
  final bool value;
  const HidePhoneNumberToggled(this.value);

  @override
  bool operator ==(Object other) =>
      other is HidePhoneNumberToggled && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
