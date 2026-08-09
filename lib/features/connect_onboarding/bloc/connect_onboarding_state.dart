part of 'connect_onboarding_bloc.dart';

sealed class ConnectOnboardingState {
  const ConnectOnboardingState();
}

class ConnectOnboardingInitial extends ConnectOnboardingState {
  const ConnectOnboardingInitial();
}

class ConnectOnboardingLoading extends ConnectOnboardingState {
  const ConnectOnboardingLoading();
}

class ConnectOnboardingNeedsOnboarding extends ConnectOnboardingState {
  const ConnectOnboardingNeedsOnboarding();
}

class ConnectOnboardingUrlReady extends ConnectOnboardingState {
  final String url;
  const ConnectOnboardingUrlReady(this.url);
}

class ConnectOnboardingPending extends ConnectOnboardingState {
  final Set<String> requirementsCurrentlyDue;
  const ConnectOnboardingPending({this.requirementsCurrentlyDue = const {}});
}

class ConnectOnboardingComplete extends ConnectOnboardingState {
  const ConnectOnboardingComplete();
}

class ConnectOnboardingDisabled extends ConnectOnboardingState {
  const ConnectOnboardingDisabled();
}

class ConnectOnboardingRejected extends ConnectOnboardingState {
  final String? reason;
  const ConnectOnboardingRejected({this.reason});
}

class ConnectOnboardingError extends ConnectOnboardingState {
  final AppException error;
  const ConnectOnboardingError(this.error);
}
