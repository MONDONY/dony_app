import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';

/// Appels API `/gp-pro/**` (yadony-back #560).
class GpProRemoteDatasource {
  GpProRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<GpProStatus> fetchStatus() async {
    final response = await _apiClient.dio.get('/gp-pro/me');
    return GpProStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GpProStatus> apply({
    required GpProFrequency frequency,
    String? commercialName,
    List<String> documentIds = const [],
    required GpProSource source,
  }) async {
    final name = commercialName?.trim();
    final response = await _apiClient.dio.post(
      '/gp-pro/applications',
      data: {
        'travelFrequency': frequency.wire,
        if (name != null && name.isNotEmpty) 'commercialName': name,
        if (documentIds.isNotEmpty) 'documentIds': documentIds,
        'source': source.wire,
      },
    );
    return GpProStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GpProDocument> uploadDocument({
    required String filePath,
    required GpProDocType type,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: _fileName(filePath),
      ),
      'type': type.wire,
    });
    final response = await _apiClient.dio.post(
      '/gp-pro/documents',
      data: formData,
    );
    return GpProDocument.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GpProStatus> attachDocuments(List<String> documentIds) async {
    final response = await _apiClient.dio.post(
      '/gp-pro/applications/current/documents',
      data: {'documentIds': documentIds},
    );
    return GpProStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeDocument(String documentId) async {
    await _apiClient.dio.delete('/gp-pro/documents/$documentId');
  }

  Future<void> cancel() async {
    await _apiClient.dio.delete('/gp-pro/applications/current');
  }

  static String _fileName(String filePath) {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    return name.isEmpty ? 'justificatif.jpg' : name;
  }
}
