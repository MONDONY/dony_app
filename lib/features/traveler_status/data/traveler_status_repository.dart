import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_remote_datasource.dart';

/// Déclaration du statut légal du voyageur. L'erreur du back (422
/// `traveler-status-invalid`…) remonte telle quelle : le cubit la déballe.
class TravelerStatusRepository {
  TravelerStatusRepository(this._remote);

  final TravelerStatusRemoteDatasource _remote;

  /// Particulier : [personalUseConfirmed] vrai. Professionnel : raison
  /// sociale, numéro et code pays ISO2 en majuscules.
  Future<TravelerStatusDeclaration> declare({
    required TravelerStatus status,
    bool? personalUseConfirmed,
    String? businessName,
    String? registrationNumber,
    String? country,
  }) => _remote.declare(
    status: status,
    personalUseConfirmed: personalUseConfirmed,
    businessName: businessName,
    registrationNumber: registrationNumber,
    country: country,
  );
}
