import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';

/// Appel API `PUT /traveler-status/me` (déclaration du statut légal).
class TravelerStatusRemoteDatasource {
  TravelerStatusRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<TravelerStatusDeclaration> declare({
    required TravelerStatus status,
    bool? personalUseConfirmed,
    String? businessName,
    String? registrationNumber,
    String? country,
  }) async {
    final response = await _apiClient.dio.put(
      '/traveler-status/me',
      data: {
        'status': status.wire,
        'personalUseConfirmed': ?personalUseConfirmed,
        'businessName': ?businessName?.trim(),
        'registrationNumber': ?registrationNumber?.trim(),
        'country': ?country,
      },
    );
    return TravelerStatusDeclaration.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
