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
  const ConnectOnboardingPending();
}

class ConnectOnboardingComplete extends ConnectOnboardingState {
  const ConnectOnboardingComplete();
}

class ConnectOnboardingError extends ConnectOnboardingState {
  final String message;
  const ConnectOnboardingError(this.message);
}
