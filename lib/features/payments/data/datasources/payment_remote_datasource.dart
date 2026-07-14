import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/saved_card_model.dart';

class PaymentRemoteDatasource {
  final ApiClient _client;

  PaymentRemoteDatasource(this._client);

  Future<ConnectAccountModel> createConnectAccount() async {
    final response = await _client.dio.post('/payments/connect/account');
    return ConnectAccountModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> createOnboardingLink() async {
    final response = await _client.dio.post('/payments/connect/onboarding-link');
    return response.data['url'] as String;
  }

  Future<ConnectAccountModel> refreshConnectAccount() async {
    final response = await _client.dio.post('/payments/connect/refresh');
    return ConnectAccountModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PaymentModel> createPayment(String bidId) async {
    final response = await _client.dio.post(
      '/payments',
      data: {'bidId': bidId},
    );
    return PaymentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SavedCardModel>> listSavedPaymentMethods() async {
    final response = await _client.dio.get('/payments/me/payment-methods');
    return (response.data as List<dynamic>)
        .map((e) => SavedCardModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateSavePaymentMethod(
    String paymentIntentId,
    bool save,
  ) async {
    await _client.dio.patch(
      '/payments/intents/$paymentIntentId/save-payment-method',
      data: {'save': save},
    );
  }

  Future<EphemeralKeyModel> createEphemeralKey(String stripeVersion) async {
    final response = await _client.dio.post(
      '/payments/me/ephemeral-key',
      data: {'stripeVersion': stripeVersion},
    );
    return EphemeralKeyModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PaymentModel?> getPaymentForBid(String bidId) async {
    try {
      final response = await _client.dio.get('/payments/bid/$bidId');
      return PaymentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
