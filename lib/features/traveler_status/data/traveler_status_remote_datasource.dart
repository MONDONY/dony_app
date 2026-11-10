import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';

/// Appels API du statut du voyageur : déclaration « particulier »
/// (`PUT /traveler-status/me`) et droit de publier
/// (`GET /travelers/me/publishing-eligibility`).
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

  Future<PublishingEligibility> fetchEligibility() async {
    final response = await _apiClient.dio.get(
      '/travelers/me/publishing-eligibility',
    );
    return PublishingEligibility.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
