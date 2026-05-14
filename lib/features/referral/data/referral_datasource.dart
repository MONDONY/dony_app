import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';

class ReferralDatasource {
  const ReferralDatasource(this._apiClient);
  final ApiClient _apiClient;

  Future<ReferralInfo> getMyReferral() async {
    final response = await _apiClient.dio.get('/me/referral');
    return ReferralInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReferralInfo> regenerateCode() async {
    final response = await _apiClient.dio.post('/me/referral/regenerate');
    return ReferralInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> redeemCode(String code) async {
    await _apiClient.dio.post('/referral/redeem', data: {'code': code});
  }
}
