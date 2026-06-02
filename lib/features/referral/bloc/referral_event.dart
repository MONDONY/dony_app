abstract class ReferralEvent {
  const ReferralEvent();
}

class ReferralLoadRequested extends ReferralEvent {
  const ReferralLoadRequested();
}

class ReferralCodeCopied extends ReferralEvent {
  const ReferralCodeCopied();
}

class ReferralShared extends ReferralEvent {
  const ReferralShared();
}

class ReferralRedeemRequested extends ReferralEvent {
  const ReferralRedeemRequested(this.code);
  final String code;
}
