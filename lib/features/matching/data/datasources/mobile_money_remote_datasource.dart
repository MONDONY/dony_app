import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_model.dart';

class MobileMoneyRemoteDatasource {
  const MobileMoneyRemoteDatasource(this._client);
  final ApiClient _client;

  Future<MobileMoneyPaymentModel> getStatus(String bidId) async {
    final response = await _client.dio
        .get<Map<String, dynamic>>('/bids/$bidId/mobile-money/status');
    return MobileMoneyPaymentModel.fromJson(response.data!);
  }

  Future<MobileMoneyPaymentModel> regenerateLink(String bidId) async {
    final response = await _client.dio
        .post<Map<String, dynamic>>('/bids/$bidId/mobile-money/initiate');
    return MobileMoneyPaymentModel.fromJson(response.data!);
  }
}
