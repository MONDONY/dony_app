import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';

class BidRemoteDatasource {
  final ApiClient _apiClient;

  BidRemoteDatasource(this._apiClient);

  /// Upload une photo de colis (multipart) → renvoie la clé S3.
  Future<String> uploadBidPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'colis.jpg'),
    });
    final response = await _apiClient.dio.post('/bids/photos', data: formData);
    return (response.data as Map<String, dynamic>)['key'] as String;
  }

  Future<BidCheckoutResponseModel> checkoutBid({
    required String announcementId,
    required double weightKg,
    required double declaredValueEur,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    List<String>? photoKeys,
    List<Map<String, dynamic>>? gridItems,
  }) async {
    final body = <String, dynamic>{
      'announcementId': announcementId,
      'declaredValueEur': declaredValueEur,
      'description': description,
      'contentCategory': contentCategory,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'disclaimerSigned': true,
    };
    // Poids omis en mode GRID pur (le backend exige ≥ 0.1 kg s'il est présent).
    if (weightKg > 0) body['weightKg'] = weightKg;
    if (photoKeys != null && photoKeys.isNotEmpty) {
      body['photoKeys'] = photoKeys;
    }
    if (gridItems != null && gridItems.isNotEmpty) {
      body['gridItems'] = gridItems;
    }
    final response = await _apiClient.dio.post('/bids/checkout', data: body);
    return BidCheckoutResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Devis : calcule net/commission/total avec promo éventuel.
  /// Lève une [DioException] avec le code promo-* si le code est invalide.
  Future<BidQuoteResponse> quoteBid({
    required String announcementId,
    double? weightKg,
    String? promoCode,
    List<Map<String, dynamic>>? gridItems,
  }) async {
    final body = <String, dynamic>{
      'announcementId': announcementId,
    };
    // Poids omis en mode GRID pur (le backend exige ≥ 0.1 kg s'il est présent).
    if (weightKg != null && weightKg > 0) body['weightKg'] = weightKg;
    if (promoCode != null && promoCode.isNotEmpty) {
      body['promoCode'] = promoCode.trim().toUpperCase();
    }
    if (gridItems != null && gridItems.isNotEmpty) body['gridItems'] = gridItems;
    final response = await _apiClient.dio.post('/bids/quote', data: body);
    return BidQuoteResponse.fromJson(response.data as Map<String, dynamic>);
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
    String? promoCode,
    List<String>? photoKeys,
    List<Map<String, dynamic>>? gridItems,
  }) async {
    final body = <String, dynamic>{
      'declaredValueEur': declaredValueEur,
      'description': description,
      'contentCategory': contentCategory,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'disclaimerSigned': true,
      'paymentMethod': paymentMethod.apiValue,
    };
    // Poids omis en mode GRID pur (le backend exige ≥ 0.1 kg s'il est présent).
    if (weightKg > 0) body['weightKg'] = weightKg;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (countryCode != null) body['countryCode'] = countryCode;
    if (promoCode != null && promoCode.isNotEmpty) {
      body['promoCode'] = promoCode.trim().toUpperCase();
    }
    if (photoKeys != null && photoKeys.isNotEmpty) {
      body['photoKeys'] = photoKeys;
    }
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

  Future<BidModel> confirmPresence(String bidId) async {
    final response = await _apiClient.dio.put('/bids/$bidId/confirm-presence');
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BidModel> confirmPayment(String bidId) async {
    final response = await _apiClient.dio.post('/bids/$bidId/confirm-payment');
    return BidModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AcceptanceResponse> acceptBidWithCommission(
    String bidId, {
    String commissionSource = 'WALLET_FIRST',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/bids/$bidId/accept-with-commission',
        queryParameters: {'commissionSource': commissionSource},
      );
      return AcceptanceResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Le backend retourne 409 pour INSUFFICIENT_WALLET et 422 pour FAILED.
      // On parse le body comme AcceptanceResponse pour obtenir les détails (solde dispo, etc.)
      final code = e.response?.statusCode;
      if ((code == 409 || code == 422) && e.response?.data != null) {
        return AcceptanceResponse.fromJson(e.response!.data as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Future<ConfirmResponse> confirmCommissionAcceptance(String bidId) async {
    try {
      final response = await _apiClient.dio.post('/bids/$bidId/confirm-acceptance');
      return ConfirmResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Le backend retourne 422 avec ConfirmAcceptanceResponse(accepted:false, error:...)
      // quand la confirmation échoue après 3DS. Sans ce catch Dio lèverait une exception
      // au lieu de retourner le ConfirmResponse, rendant le chemin cardDeclined mort.
      if (e.response?.statusCode == 422 && e.response?.data != null) {
        return ConfirmResponse.fromJson(e.response!.data as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
