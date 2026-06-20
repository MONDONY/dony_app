import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';

class CancellationRemoteDatasource {
  final ApiClient _apiClient;

  CancellationRemoteDatasource(this._apiClient);

  Future<CancellationModel> cancelTrip({
    required String announcementId,
    required String reason,
  }) async {
    final response = await _apiClient.dio.post('/cancellations', data: {
      'announcementId': announcementId,
      'reason': reason,
    });
    return CancellationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RematchSuggestionModel>> getRematchSuggestions(String cancellationId) async {
    final response = await _apiClient.dio.get('/cancellations/$cancellationId/rematch-suggestions');
    return (response.data as List)
        .map((s) => RematchSuggestionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<void> reportNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/report-noshow');
  }

  Future<void> reportTravelerNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/report-traveler-noshow');
  }

  Future<void> contestNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/contest-noshow');
  }

  /// L'expéditeur confirme lui-même son absence signalée par le voyageur :
  /// le bid est annulé, pas de débit (endpoint dédié SENDER).
  Future<void> confirmNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/confirm-noshow-self');
  }

  /// Annulation après remise (HANDED_OVER) — expéditeur OU voyageur (D5/D6).
  /// Le backend renvoie le bid mis à jour ; on ignore le corps, l'écran rafraîchit
  /// via BidBloc.BidDetailRequested.
  Future<void> cancelAfterHandover(String bidId) async {
    await _apiClient.dio.post('/bids/$bidId/cancel-after-handover');
  }

  /// Le voyageur saisit le code de retour détenu par l'expéditeur (D7).
  Future<ReturnCodeModel> confirmReturn(String bidId, String code) async {
    final response = await _apiClient.dio.post(
      '/cancellations/bids/$bidId/confirm-return',
      data: {'returnCode': code},
    );
    return ReturnCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// L'expéditeur consulte son code de retour + l'état de la restitution (D7).
  Future<ReturnCodeModel> getReturnCode(String bidId) async {
    final response =
        await _apiClient.dio.get('/cancellations/bids/$bidId/return-code');
    return ReturnCodeModel.fromJson(response.data as Map<String, dynamic>);
  }
}
