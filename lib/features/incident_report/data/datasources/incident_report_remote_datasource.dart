import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';

/// Appels API du signalement d'incident (photos + création).
class IncidentReportRemoteDatasource {
  final ApiClient _apiClient;

  IncidentReportRemoteDatasource(this._apiClient);

  /// Upload une capture d'écran ; renvoie la clé S3 à joindre au signalement.
  Future<String> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      // Le nom réel porte l'extension : la capture automatique du scarabée est
      // un PNG, les photos du sélecteur des JPEG. Dio en déduit le type MIME.
      'file': await MultipartFile.fromFile(
        filePath,
        filename: _fileName(filePath),
      ),
    });
    final response = await _apiClient.dio.post(
      '/reports/photos',
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['key'] as String;
  }

  static String _fileName(String filePath) {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    return name.isEmpty ? 'capture.jpg' : name;
  }

  /// Crée le signalement ; renvoie son id.
  ///
  /// [screenRoute] : route de l'écran d'origine pour un rapport du scarabée
  /// (cible APP), ignorée par un backend antérieur à yadony-back #317.
  ///
  /// [messageId] : message Firestore signalé, pour la cible MESSAGE dont
  /// [targetId] est la conversation (`conversations.id`) ; le back vérifie
  /// que le signalant participe à la conversation (FLUTTER-B4).
  Future<String> createReport({
    required String targetType,
    String? targetId,
    required String reason,
    String? description,
    required List<String> photoKeys,
    String? screenRoute,
    String? messageId,
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
        'screenRoute': ?screenRoute,
        'messageId': ?messageId,
      },
    );
    return (response.data as Map<String, dynamic>)['id'] as String;
  }
}
