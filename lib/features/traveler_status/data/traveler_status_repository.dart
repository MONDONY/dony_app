import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_remote_datasource.dart';

/// Lecture du droit de publier, jamais bloquante : [eligibility] vaut « OK »
/// quand la lecture échoue, [failureCode] dit pourquoi (à tracer) ou reste
/// `null` quand il n'y a rien à signaler (lecture réussie, ou route absente
/// d'un ancien back).
typedef EligibilityCheck = ({
  PublishingEligibility eligibility,
  String? failureCode,
});

/// Statut du voyageur. L'erreur du back (422 `traveler-status-invalid`…)
/// remonte telle quelle : le cubit la déballe.
class TravelerStatusRepository {
  TravelerStatusRepository(this._remote);

  final TravelerStatusRemoteDatasource _remote;

  /// Déclare « particulier » (avec la confirmation de voyager à titre
  /// personnel).
  Future<TravelerStatusDeclaration> declareIndividual() =>
      _remote.declareIndividual();

  /// Droit de publier tel que le back le lit ; l'erreur remonte.
  Future<PublishingEligibility> fetchEligibility() =>
      _remote.fetchEligibility();

  /// Comme [fetchEligibility], mais sans jamais lever : un 404 (ancien back
  /// sans la route), une coupure réseau ou une réponse illisible autorisent la
  /// publication. On ne bloque jamais un voyageur sur une lecture qui échoue.
  Future<EligibilityCheck> checkEligibility() async {
    try {
      return (eligibility: await fetchEligibility(), failureCode: null);
    } on Object catch (e) {
      final error = unwrapDioError(e);
      final notFound =
          error is NotFoundException ||
          (e is DioException && e.response?.statusCode == 404);
      return (
        eligibility: PublishingEligibility.ok,
        failureCode: notFound ? null : (error.code ?? 'unknown'),
      );
    }
  }
}
