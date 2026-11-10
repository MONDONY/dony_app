import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/network/retry_policy.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';

/// Appels API du statut du voyageur : déclaration « particulier »
/// (`PUT /traveler-status/me`) et droit de publier
/// (`GET /travelers/me/publishing-eligibility`).
/// Au moins la limite de tentatives de `RetryOnTransientErrorInterceptor`.
const int _noMoreRetries = 99;

class TravelerStatusRemoteDatasource {
  TravelerStatusRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  /// « Particulier » avec la confirmation de voyager à titre personnel. Le
  /// professionnel n'existe plus ici (422 `traveler-status-invalid`) : il fait
  /// une demande GP Pro.
  Future<TravelerStatusDeclaration> declareIndividual() async {
    final response = await _apiClient.dio.put(
      '/traveler-status/me',
      data: {
        'status': TravelerStatus.individual.wire,
        'personalUseConfirmed': true,
      },
    );
    return TravelerStatusDeclaration.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Délai de la lecture du droit de publier. Court : un échec n'arrête
  /// personne (le back reste le garde-fou), il ne doit donc pas non plus faire
  /// attendre le voyageur. Sans nouvelle tentative réseau (clé de tentative au
  /// maximum), sinon les 30 s habituelles reviendraient en cas de coupure.
  static const eligibilityTimeout = Duration(seconds: 8);

  Future<PublishingEligibility> fetchEligibility() async {
    final response = await _apiClient.dio.get(
      '/travelers/me/publishing-eligibility',
      options: Options(
        sendTimeout: eligibilityTimeout,
        receiveTimeout: eligibilityTimeout,
        extra: {RetryPolicy.transientAttemptKey: _noMoreRetries},
      ),
    );
    return PublishingEligibility.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
