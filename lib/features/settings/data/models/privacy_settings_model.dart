/// Réglages de confidentialité servis par `GET /auth/me/privacy-settings`.
class PrivacySettingsModel {
  /// Seuls les profils ayant validé leur identité peuvent m'envoyer une offre.
  final bool contactKycOnly;

  /// Mon numéro n'est jamais révélé à ma contrepartie, même après acceptation :
  /// la messagerie yadony devient mon seul canal de contact.
  final bool hidePhoneNumber;

  const PrivacySettingsModel({
    required this.contactKycOnly,
    required this.hidePhoneNumber,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) =>
      PrivacySettingsModel(
        contactKycOnly: json['contactKycOnly'] as bool? ?? true,
        hidePhoneNumber: json['hidePhoneNumber'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsModel &&
      other.contactKycOnly == contactKycOnly &&
      other.hidePhoneNumber == hidePhoneNumber;

  @override
  int get hashCode => Object.hash(contactKycOnly, hidePhoneNumber);
}
