import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';

/// Appels HTTP du fil de négociation du prix d'un trajet.
///
/// Style identique à [BidRemoteDatasource] : aucun try/catch, les
/// [DioException] remontent brutes et sont déballées par le BLoC via
/// `unwrapDioError`.
class BidNegotiationRemoteDatasource {
  final ApiClient _apiClient;

  BidNegotiationRemoteDatasource(this._apiClient);

  /// Première proposition d'un expéditeur sur un trajet négociable.
  Future<BidNegotiation> propose({
    required String announcementId,
    required double? weightKg,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    required double proposedTotalEur,
    BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
    String? phoneNumber,
    String? countryCode,
    List<String>? photoKeys,
    List<Map<String, dynamic>>? customItems,
    List<Map<String, dynamic>>? gridItems,
  }) async {
    final body = <String, dynamic>{
      'description': description,
      'contentCategory': contentCategory,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'disclaimerSigned': true,
      'paymentMethod': paymentMethod.apiValue,
      'proposedTotalEur': proposedTotalEur,
    };
    // Poids omis en mode grille pur (le backend exige ≥ 0.1 kg s'il est présent).
    if (weightKg != null && weightKg > 0) body['weightKg'] = weightKg;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (countryCode != null) body['countryCode'] = countryCode;
    if (photoKeys != null && photoKeys.isNotEmpty) {
      body['photoKeys'] = photoKeys;
    }
    if (customItems != null && customItems.isNotEmpty) {
      body['customItems'] = customItems;
    }
    if (gridItems != null && gridItems.isNotEmpty) {
      body['gridItems'] = gridItems;
    }
    final response = await _apiClient.dio.post(
      '/announcements/$announcementId/bids/negotiation',
      data: body,
    );
    return BidNegotiation.fromJson(response.data as Map<String, dynamic>);
  }

  /// Contre-offre de l'une des deux parties.
  Future<BidNegotiation> counter(
    String bidId, {
    required double proposedTotalEur,
    String? body,
  }) async {
    final payload = <String, dynamic>{'proposedTotalEur': proposedTotalEur};
    if (body != null && body.trim().isNotEmpty) payload['body'] = body;
    final response = await _apiClient.dio.post(
      '/bids/$bidId/negotiation/counter',
      data: payload,
    );
    return BidNegotiation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidNegotiation> accept(String bidId) async {
    final response = await _apiClient.dio.post(
      '/bids/$bidId/negotiation/accept',
    );
    return BidNegotiation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidNegotiation> reject(String bidId) async {
    final response = await _apiClient.dio.post(
      '/bids/$bidId/negotiation/reject',
    );
    return BidNegotiation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidNegotiation> cancel(String bidId) async {
    final response = await _apiClient.dio.post(
      '/bids/$bidId/negotiation/cancel',
    );
    return BidNegotiation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidNegotiation> thread(String bidId) async {
    final response = await _apiClient.dio.get('/bids/$bidId/negotiation');
    return BidNegotiation.fromJson(response.data as Map<String, dynamic>);
  }

  /// Marque le fil comme lu (badge de non-lus). Réponse 204, sans corps.
  Future<void> markRead(String bidId) async {
    await _apiClient.dio.post('/bids/$bidId/negotiation/read');
  }

  Future<List<BidNegotiationSummary>> myNegotiations() async {
    final response = await _apiClient.dio.get('/bids/negotiations/me');
    return ((response.data as List<dynamic>?) ?? const [])
        .map((e) => BidNegotiationSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
