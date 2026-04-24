abstract class LocalAuthState {
  const LocalAuthState();
}

class LocalAuthInitial extends LocalAuthState {
  const LocalAuthInitial();
}

class LocalAuthChecking extends LocalAuthState {
  const LocalAuthChecking();
}

class LocalAuthPinRequired extends LocalAuthState {
  const LocalAuthPinRequired({
    this.attemptsLeft = 3,
    this.biometricAvailable = false,
  });
  final int attemptsLeft;
  final bool biometricAvailable;
}

class LocalAuthLocked extends LocalAuthState {
  const LocalAuthLocked(this.secondsLeft);
  final int secondsLeft;
}

class LocalAuthSuccess extends LocalAuthState {
  const LocalAuthSuccess();
}

class LocalAuthError extends LocalAuthState {
  const LocalAuthError(this.message);
  final String message;
}

/// Aucun PIN configuré — l'utilisateur doit en créer un (premier login ou PIN effacé)
class LocalAuthNoPinSet extends LocalAuthState {
  const LocalAuthNoPinSet();
}
