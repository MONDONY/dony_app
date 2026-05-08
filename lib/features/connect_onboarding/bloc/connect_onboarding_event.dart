part of 'connect_onboarding_bloc.dart';

sealed class ConnectOnboardingEvent {
  const ConnectOnboardingEvent();
}

class ConnectOnboardingStatusRequested extends ConnectOnboardingEvent {
  const ConnectOnboardingStatusRequested();
}

class ConnectOnboardingLinkRequested extends ConnectOnboardingEvent {
  const ConnectOnboardingLinkRequested();
}

class ConnectOnboardingPollingRequested extends ConnectOnboardingEvent {
  const ConnectOnboardingPollingRequested();
}

class ConnectOnboardingLaunchFailed extends ConnectOnboardingEvent {
  final String message;
  const ConnectOnboardingLaunchFailed(this.message);
}
