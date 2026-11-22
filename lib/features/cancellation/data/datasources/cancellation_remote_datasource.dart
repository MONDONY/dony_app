import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';

class CancellationRemoteDatasource {
  final ApiClient _apiClient;

  CancellationRemoteDatasource(this._apiClient);

  Future<CancellationModel> cancelTrip({
    required String announcementId,
    required String reason,
  }) async {
    final response = await _apiClient.dio.post(
      '/cancellations',
      data: {'announcementId': announcementId, 'reason': reason},
    );
    return CancellationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RematchSuggestionModel>> getRematchSuggestions(
    String cancellationId,
  ) async {
    final response = await _apiClient.dio.get(
      '/cancellations/$cancellationId/rematch-suggestions',
    );
    return (response.data as List)
        .map((s) => RematchSuggestionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<void> reportNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/report-noshow');
  }

  Future<void> reportTravelerNoShow(String bidId) async {
    await _apiClient.dio.post(
      '/cancellations/bids/$bidId/report-traveler-noshow',
    );
  }

  Future<void> contestNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/contest-noshow');
  }

  /// Signalement « destinataire absent » (FLUTTER-E2). `contactConfirmed` :
  /// le voyageur confirme avoir attendu et tenté de joindre le destinataire.
  /// Un back antérieur ignore le corps.
  Future<void> reportDeliveryNoShow(
    String bidId, {
    bool contactConfirmed = false,
  }) async {
    await _apiClient.dio.post(
      '/cancellations/bids/$bidId/report-delivery-noshow',
      data: {'contactConfirmed': contactConfirmed},
    );
  }

  /// État de la procédure « destinataire absent » du colis (FLUTTER-E2).
  Future<DeliveryNoShowProcedureModel> getDeliveryNoShowProcedure(
    String bidId,
  ) async {
    final response = await _apiClient.dio.get(
      '/cancellations/bids/$bidId/delivery-noshow',
    );
    return DeliveryNoShowProcedureModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// L'expéditeur fixe un nouveau rendez-vous de livraison pendant la garde.
  Future<DeliveryNoShowProcedureModel> setRetryAppointment(
    String bidId, {
    required DateTime appointmentAt,
    String? note,
  }) async {
    final response = await _apiClient.dio.post(
      '/cancellations/bids/$bidId/delivery-noshow/retry-appointment',
      data: {
        'appointmentAt': appointmentAt.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return DeliveryNoShowProcedureModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> reportTravelerDeliveryNoShow(String bidId) async {
    await _apiClient.dio.post(
      '/cancellations/bids/$bidId/report-traveler-delivery-noshow',
    );
  }

  Future<void> contestDeliveryNoShow(String bidId) async {
    await _apiClient.dio.post(
      '/cancellations/bids/$bidId/contest-delivery-noshow',
    );
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

  /// Réponse de l'expéditeur au report du trajet : garder son colis sur la
  /// nouvelle date (`keep`) ou se retirer sans frais. Réponse 204, l'écran se
  /// recharge via BidBloc.BidDetailRequested.
  Future<void> decideReschedule(String bidId, {required bool keep}) async {
    await _apiClient.dio.post(
      '/cancellations/bids/$bidId/reschedule-decision',
      data: {'decision': keep ? 'KEEP' : 'WITHDRAW'},
    );
  }

  /// Le voyageur saisit le code de retour détenu par l'expéditeur (D7).
  Future<ReturnCodeModel> confirmReturn(String bidId, String code) async {
    final response = await _apiClient.dio.post(
      '/cancellations/bids/$bidId/confirm-return',
      data: {'returnCode': code},
    );
    return ReturnCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Aperçu des frais d'annulation de l'expéditeur avant qu'il confirme
  /// (yadony-back #779). Expéditeur seul (403 sinon), 404 sur un colis inconnu
  /// ou sur un back antérieur à la route. Lecture seule.
  Future<CancellationFeePreviewModel> getFeePreview(String bidId) async {
    final response = await _apiClient.dio.get(
      '/cancellations/bids/$bidId/fee-preview',
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('fee-preview: unexpected body');
    }
    return CancellationFeePreviewModel.fromJson(data);
  }

  /// État public des frais d'annulation (`GET /config/cancellation-fee`,
  /// sans authentification) : l'app y choisit ses textes. 404 sur un back
  /// antérieur à la route, remonté tel quel.
  Future<CancellationFeeConfigModel> getFeeConfig() async {
    final response = await _apiClient.dio.get('/config/cancellation-fee');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('cancellation-fee config: unexpected body');
    }
    return CancellationFeeConfigModel.fromJson(data);
  }

  /// L'expéditeur consulte son code de retour + l'état de la restitution (D7).
  Future<ReturnCodeModel> getReturnCode(String bidId) async {
    final response = await _apiClient.dio.get(
      '/cancellations/bids/$bidId/return-code',
    );
    return ReturnCodeModel.fromJson(response.data as Map<String, dynamic>);
  }
}
