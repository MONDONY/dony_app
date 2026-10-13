import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';

/// Engagements de publication, côté serveur (source de vérité, preuve dans
/// `audit_log`).
class PublishCommitmentRepository {
  PublishCommitmentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PublishCommitments> fetch() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/auth/me/publish-commitments',
    );
    return PublishCommitments.fromJson(response.data!);
  }

  /// Lève une `AppException` de code `publish-commitment-outdated` (409) si
  /// [version] n'est plus celle en vigueur.
  Future<void> accept(PublishCommitmentRole role, String version) async {
    await _apiClient.dio.put<void>(
      '/auth/me/publish-commitments',
      data: {'role': role.wire, 'version': version},
    );
  }
}
