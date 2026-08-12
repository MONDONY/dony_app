import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';

/// Appels API du signalement d'incident (photos + création).
class IncidentReportRemoteDatasource {
  final ApiClient _apiClient;

  IncidentReportRemoteDatasource(this._apiClient);

  /// Upload une capture d'écran ; renvoie la clé S3 à joindre au signalement.
  Future<String> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'capture.jpg'),
    });
    final response = await _apiClient.dio.post(
      '/reports/photos',
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['key'] as String;
  }

  /// Crée le signalement ; renvoie son id.
  Future<String> createReport({
    required String targetType,
    String? targetId,
    required String reason,
    String? description,
    required List<String> photoKeys,
  }) async {
    final response = await _apiClient.dio.post(
      '/reports',
      data: {
        'targetType': targetType,
        'targetId': ?targetId,
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
        'photoKeys': photoKeys,
      },
    );
    return (response.data as Map<String, dynamic>)['id'] as String;
  }
}
