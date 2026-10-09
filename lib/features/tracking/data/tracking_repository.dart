import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/utils/server_date_time.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';

typedef ConfirmationCodeResult = ({
  String? code,
  DateTime? expiresAt,
  bool publicPageVisible,
});

/// Demande de nouveau code de retrait transmise à l'expéditeur (FLUTTER-G2).
typedef PickupCodeRequestResult = ({
  DateTime? requestedAt,
  DateTime? nextRequestAllowedAt,
});

class TrackingRepository {
  final ApiClient _apiClient;

  TrackingRepository(this._apiClient);

  Future<QrCodeModel> getQrCode(String bidId) async {
    final response = await _apiClient.dio.get('/tracking/$bidId/qr-code');
    return QrCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TrackingSearchModel> searchByTrackingNumber(String number) async {
    final response = await _apiClient.dio.get(
      '/tracking/search',
      queryParameters: {'number': number},
    );
    return TrackingSearchModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TrackingEventModel> postScan({
    required String bidId,
    required String eventType,
    double? gpsLat,
    double? gpsLon,
    String? gpsLabel,
    String? photoUrl,
    DateTime? offlineTimestamp,
    ScanMethod? scanMethod,
    String? trackingNumber,
  }) async {
    final response = await _apiClient.dio.post(
      '/tracking/events',
      data: {
        'bidId': bidId,
        'eventType': eventType,
        'gpsLat': ?gpsLat,
        'gpsLon': ?gpsLon,
        'gpsLabel': ?gpsLabel,
        'photoUrl': ?photoUrl,
        'scanMethod': ?scanMethod?.wire,
        // Remise du colis (DEPART) : numéro de suivi donné par l'expéditeur.
        'trackingNumber': ?trackingNumber,
        if (offlineTimestamp != null)
          'offlineTimestamp': offlineTimestamp.toUtc().toIso8601String(),
      },
    );
    return TrackingEventModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TrackingEventModel>> getEvents(String bidId) async {
    final response = await _apiClient.dio.get('/tracking/$bidId/events');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => TrackingEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TripScanHistoryEntryModel>> getTripScanHistory(
    String announcementId,
  ) async {
    final response = await _apiClient.dio.get(
      '/tracking/announcements/$announcementId/events',
    );
    final list = response.data as List<dynamic>;
    return list
        .map(
          (e) => TripScanHistoryEntryModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<String> uploadTrackingPhoto(String bidId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'scan.jpg'),
      'bidId': bidId,
    });
    final response = await _apiClient.dio.post(
      '/storage/upload/tracking',
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['key'] as String;
  }

  Future<ConfirmationCodeResult> refreshCode(String bidId) async {
    final response = await _apiClient.dio.post('/tracking/$bidId/refresh-code');
    final data = response.data as Map<String, dynamic>;
    final rawExpiry = data['expiresAt'] as String?;
    return (
      code: data['confirmationCode'] as String?,
      expiresAt: rawExpiry != null ? DateTime.parse(rawExpiry) : null,
      publicPageVisible: data['publicPageVisible'] as bool? ?? false,
    );
  }

  /// Le voyageur demande à l'expéditeur un nouveau code de retrait, bloqué ou
  /// expiré (`POST /tracking/{bidId}/request-code`, yadony-back #461,
  /// FLUTTER-G2). Erreurs : 403 `forbidden`, 409 `code-request-not-allowed` /
  /// `code-still-valid`, 429 `code-request-too-soon` avec
  /// `nextRequestAllowedAt` et `retryAfterSeconds`.
  Future<PickupCodeRequestResult> requestNewCode(String bidId) async {
    final response = await _apiClient.dio.post('/tracking/$bidId/request-code');
    final data = response.data is Map
        ? response.data as Map<String, dynamic>
        : const <String, dynamic>{};
    DateTime? date(String key) {
      final raw = data[key];
      if (raw is! String || raw.trim().isEmpty) return null;
      try {
        return parseServerDateTime(raw);
      } on FormatException {
        return null;
      }
    }

    return (
      requestedAt: date('requestedAt'),
      nextRequestAllowedAt: date('nextRequestAllowedAt'),
    );
  }

  Future<ConfirmationCodeResult> setConfirmationCodePublicVisible(
    String bidId, {
    required bool visible,
  }) async {
    final response = await _apiClient.dio.post(
      '/tracking/$bidId/confirmation-code/public',
      queryParameters: {'visible': visible},
    );
    final data = response.data as Map<String, dynamic>;
    final rawExpiry = data['expiresAt'] as String?;
    return (
      code: data['confirmationCode'] as String?,
      expiresAt: rawExpiry != null ? DateTime.parse(rawExpiry) : null,
      publicPageVisible: data['publicPageVisible'] as bool? ?? false,
    );
  }

  Future<TrackingEventModel> confirmDelivery({
    required String bidId,
    required String code,
    String? photoUrl,
    ScanMethod? scanMethod,
    double? gpsLat,
    double? gpsLon,
    String? gpsLabel,
  }) async {
    final response = await _apiClient.dio.post(
      '/tracking/$bidId/confirm-delivery',
      data: {
        'confirmationCode': code,
        'photoUrl': ?photoUrl,
        'scanMethod': ?scanMethod?.wire,
        'gpsLat': ?gpsLat,
        'gpsLon': ?gpsLon,
        'gpsLabel': ?gpsLabel,
      },
    );
    return TrackingEventModel.fromJson(response.data as Map<String, dynamic>);
  }
}
