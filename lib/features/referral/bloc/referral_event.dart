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
