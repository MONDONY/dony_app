abstract class LocalAuthEvent {
  const LocalAuthEvent();
}

class LocalAuthStarted extends LocalAuthEvent {
  const LocalAuthStarted();
}

class LocalAuthBiometricRequested extends LocalAuthEvent {
  const LocalAuthBiometricRequested();
}

class LocalAuthPinSubmitted extends LocalAuthEvent {
  const LocalAuthPinSubmitted(this.pin);
  final String pin;
}

class LocalAuthLockExpired extends LocalAuthEvent {
  const LocalAuthLockExpired();
}
