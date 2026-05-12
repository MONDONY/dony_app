import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_datasource.dart';

class ReferralRepository {
  const ReferralRepository(this._datasource);
  final ReferralDatasource _datasource;

  Future<ReferralInfo> getMyReferral() => _datasource.getMyReferral();
  Future<ReferralInfo> regenerateCode() => _datasource.regenerateCode();
  Future<void> redeemCode(String code) => _datasource.redeemCode(code);
}
