import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';

class ReferralDatasource {
  const ReferralDatasource(this._apiClient);
  final ApiClient _apiClient;

  /// Taille de page des filleuls, alignée sur la pagination standard (20).
  static const refereesPageSize = 20;

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

  /// Filleuls du compte, page [page] (yadony-back #528). Un back antérieur
  /// répond 404 : l'appelant masque alors la section.
  Future<RefereePage> getReferees({int page = 0}) async {
    final response = await _apiClient.dio.get(
      '/me/referral/referees',
      queryParameters: {'page': page, 'size': refereesPageSize},
    );
    return RefereePage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Choisit la récompense d'une invitation ; rend le filleul mis à jour.
  Future<Referee> chooseReward(String invitationId, RewardChoice choice) async {
    final response = await _apiClient.dio.post(
      '/me/referral/rewards/$invitationId/choose',
      data: {'choice': choice.wire},
    );
    return Referee.fromJson(response.data as Map<String, dynamic>);
  }
}
