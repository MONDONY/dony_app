import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dio/dio.dart';

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
