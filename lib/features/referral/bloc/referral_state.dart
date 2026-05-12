import 'package:dony/features/referral/data/models/referral_info.dart';

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
