import 'package:dony/features/traveler_status/data/traveler_status.dart';

/// Déclaration enregistrée, telle que `PUT /traveler-status/me` la renvoie à
/// son propriétaire (qui voit son propre numéro d'immatriculation).
class TravelerStatusDeclaration {
  const TravelerStatusDeclaration({
    required this.status,
    this.declaredAt,
    this.businessName,
    this.registrationNumber,
    this.country,
  });

  factory TravelerStatusDeclaration.fromJson(Map<String, dynamic> json) =>
      TravelerStatusDeclaration(
        // Statut illisible : le back vient de l'enregistrer, la déclaration est
        // faite ; on retombe sur le particulier plutôt que de faire échouer.
        status:
            TravelerStatus.parse(json['status'] as String?) ??
            TravelerStatus.individual,
        declaredAt: json['declaredAt'] == null
            ? null
            : DateTime.tryParse(json['declaredAt'] as String),
        businessName: json['businessName'] as String?,
        registrationNumber: json['registrationNumber'] as String?,
        country: json['country'] as String?,
      );

  final TravelerStatus status;
  final DateTime? declaredAt;
  final String? businessName;
  final String? registrationNumber;
  final String? country;
}
