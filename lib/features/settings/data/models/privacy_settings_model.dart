/// Réglages de confidentialité servis par `GET /auth/me/privacy-settings`.
class PrivacySettingsModel {
  /// Seuls les profils ayant validé leur identité peuvent m'envoyer une offre.
  final bool contactKycOnly;

  /// Mon numéro n'est jamais révélé à ma contrepartie, même après acceptation :
  /// la messagerie Yadony devient mon seul canal de contact.
  final bool hidePhoneNumber;

  /// Mon pays de résidence apparaît sur mon profil public (FLUTTER-4H).
  /// Masqué par défaut.
  final bool showResidenceCountry;

  const PrivacySettingsModel({
    required this.contactKycOnly,
    required this.hidePhoneNumber,
    this.showResidenceCountry = false,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) =>
      PrivacySettingsModel(
        contactKycOnly: json['contactKycOnly'] as bool? ?? true,
        hidePhoneNumber: json['hidePhoneNumber'] as bool? ?? false,
        showResidenceCountry: json['showResidenceCountry'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsModel &&
      other.contactKycOnly == contactKycOnly &&
      other.hidePhoneNumber == hidePhoneNumber &&
      other.showResidenceCountry == showResidenceCountry;

  @override
  int get hashCode =>
      Object.hash(contactKycOnly, hidePhoneNumber, showResidenceCountry);
}
