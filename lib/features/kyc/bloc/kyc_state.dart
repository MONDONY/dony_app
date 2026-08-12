import 'package:dony/core/error/app_exception.dart';

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
  const KycStatusLoaded({
    required this.kycStatus,
    required this.verificationStatus,
    this.rejectionCode,
  });
  final String kycStatus;
  final String verificationStatus;
  final String? rejectionCode;
}

class KycError extends KycState {
  const KycError(this.error);
  final AppException error;
}
