abstract class KycState {
  const KycState();
}

class KycInitial extends KycState {
  const KycInitial();
}

class KycLoading extends KycState {
  const KycLoading();
}

class KycSessionCreated extends KycState {
  const KycSessionCreated({required this.stripeUrl, required this.sessionId});
  final String stripeUrl;
  final String sessionId;
}

class KycStatusLoaded extends KycState {
  const KycStatusLoaded({required this.kycStatus, required this.verificationStatus});
  final String kycStatus;
  final String verificationStatus;
}

class KycError extends KycState {
  const KycError(this.message);
  final String message;
}
