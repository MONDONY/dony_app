import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/core/error/app_exception.dart';

abstract class ReferralState {
  const ReferralState();
}

class ReferralInitial extends ReferralState {
  const ReferralInitial();
}

class ReferralLoading extends ReferralState {
  const ReferralLoading();
}

class ReferralLoaded extends ReferralState {
  const ReferralLoaded(this.info);
  final ReferralInfo info;
}

class ReferralError extends ReferralState {
  const ReferralError(this.message);
  final String message;
}

class ReferralRedeemLoading extends ReferralState {
  const ReferralRedeemLoading();
}

class ReferralRedeemed extends ReferralState {
  const ReferralRedeemed();
}

class ReferralRedeemError extends ReferralState {
  const ReferralRedeemError(this.error);
  final AppException error;
}
