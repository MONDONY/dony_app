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

  /// Ma dernière connexion apparaît sur mon profil public, au jour près
  /// (FLUTTER-4H partie 2). Visible par défaut.
  final bool showLastSeen;

  const PrivacySettingsModel({
    required this.contactKycOnly,
    required this.hidePhoneNumber,
    this.showResidenceCountry = false,
    this.showLastSeen = true,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) =>
      PrivacySettingsModel(
        contactKycOnly: json['contactKycOnly'] as bool? ?? true,
        hidePhoneNumber: json['hidePhoneNumber'] as bool? ?? false,
        showResidenceCountry: json['showResidenceCountry'] as bool? ?? false,
        showLastSeen: json['showLastSeen'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettingsModel &&
      other.contactKycOnly == contactKycOnly &&
      other.hidePhoneNumber == hidePhoneNumber &&
      other.showResidenceCountry == showResidenceCountry &&
      other.showLastSeen == showLastSeen;

  @override
  int get hashCode => Object.hash(
    contactKycOnly,
    hidePhoneNumber,
    showResidenceCountry,
    showLastSeen,
  );
}
