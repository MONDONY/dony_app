import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

class BidRemoteDatasource {
  final ApiClient _apiClient;

  BidRemoteDatasource(this._apiClient);

  Future<BidCheckoutResponseModel> checkoutBid({
    required String announcementId,
    required double weightKg,
    required double declaredValueEur,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    List<Map<String, dynamic>>? gridItems,
  }) async {
    final body = <String, dynamic>{
      'announcementId': announcementId,
      'weightKg': weightKg,
      'declaredValueEur': declaredValueEur,
      'description': description,
      'contentCategory': contentCategory,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'disclaimerSigned': true,
    };
    if (gridItems != null && gridItems.isNotEmpty) {
      body['gridItems'] = gridItems;
    }
    final response = await _apiClient.dio.post('/bids/checkout', data: body);
    return BidCheckoutResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidModel> createBid({
    required String announcementId,
    required double weightKg,
    required double declaredValueEur,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
    String? phoneNumber,
    String? countryCode,
    List<Map<String, dynamic>>? gridItems,
  }) async {
    // Serialize enum: orangeMoney → ORANGE_MONEY
    final paymentMethodStr = paymentMethod == BidPaymentMethod.orangeMoney
        ? 'ORANGE_MONEY'
        : paymentMethod.name.toUpperCase();
    final body = <String, dynamic>{
      'weightKg': weightKg,
      'declaredValueEur': declaredValueEur,
      'description': description,
      'contentCategory': contentCategory,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'disclaimerSigned': true,
      'paymentMethod': paymentMethodStr,
    };
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (countryCode != null) body['countryCode'] = countryCode;
    if (gridItems != null && gridItems.isNotEmpty) {
      body['gridItems'] = gridItems;
    }
    final response = await _apiClient.dio.post(
      '/announcements/$announcementId/bids',
      data: body,
    );
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BidModel>> getBidsForAnnouncement(String announcementId) async {
    final response = await _apiClient.dio.get('/announcements/$announcementId/bids');
    return (response.data as List)
        .map((j) => BidModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<BidModel> getBidById(String bidId) async {
    final response = await _apiClient.dio.get('/bids/$bidId');
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BidModel>> getMyBids() async {
    final response = await _apiClient.dio.get('/bids/me');
    return (response.data as List)
        .map((j) => BidModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<BidModel> acceptBid(String bidId) async {
    final response = await _apiClient.dio.put('/bids/$bidId/accept');
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidModel> rejectBid(String bidId, {String? reason}) async {
    final response = await _apiClient.dio.put(
      '/bids/$bidId/reject',
      data: reason != null ? {'reason': reason} : null,
    );
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidModel> cancelBid(String bidId, {String? reason}) async {
    final response = await _apiClient.dio.put(
      '/bids/$bidId/cancel',
      data: reason != null ? {'reason': reason} : null,
    );
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> hideBid(String bidId) async {
    await _apiClient.dio.delete('/bids/$bidId/me');
  }

  Future<void> dismissBidAsTraveler(String bidId) async {
    await _apiClient.dio.delete('/bids/$bidId/traveler');
  }

  Future<BidModel> setHandover({
    required String bidId,
    required String location,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) async {
    final response = await _apiClient.dio.put(
      '/bids/$bidId/handover',
      data: {
        'location': location,
        'windowStart': windowStart.toUtc().toIso8601String(),
        'windowEnd': windowEnd.toUtc().toIso8601String(),
      },
    );
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidModel> confirmPresence(String bidId) async {
    final response = await _apiClient.dio.put('/bids/$bidId/confirm-presence');
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidModel> confirmPayment(String bidId) async {
    final response = await _apiClient.dio.post('/bids/$bidId/confirm-payment');
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AcceptanceResponse> acceptBidWithCommission(String bidId) async {
    try {
      final response = await _apiClient.dio.post('/bids/$bidId/accept-with-commission');
      return AcceptanceResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Le backend retourne 422 pour FAILED (carte refusée, etc.)
      // On parse le body comme AcceptanceResponse pour afficher la raison précise
      if (e.response?.statusCode == 422 && e.response?.data != null) {
        return AcceptanceResponse.fromJson(e.response!.data as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Future<ConfirmResponse> confirmCommissionAcceptance(String bidId) async {
    final response = await _apiClient.dio.post('/bids/$bidId/confirm-acceptance');
    return ConfirmResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
