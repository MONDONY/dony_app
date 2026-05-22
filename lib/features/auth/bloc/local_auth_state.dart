import 'package:dony/core/error/app_exception.dart';
import 'package:equatable/equatable.dart';

abstract class LocalAuthState extends Equatable {
  const LocalAuthState();
}

class LocalAuthInitial extends LocalAuthState {
  const LocalAuthInitial();

  @override
  List<Object?> get props => const [];
}

class LocalAuthChecking extends LocalAuthState {
  const LocalAuthChecking();

  @override
  List<Object?> get props => const [];
}

class LocalAuthPinRequired extends LocalAuthState {
  const LocalAuthPinRequired({
    this.attemptsLeft = 3,
    this.biometricAvailable = false,
  });
  final int attemptsLeft;
  final bool biometricAvailable;

  @override
  List<Object?> get props => [attemptsLeft, biometricAvailable];
}

class LocalAuthLocked extends LocalAuthState {
  const LocalAuthLocked(this.secondsLeft);
  final int secondsLeft;

  @override
  List<Object?> get props => [secondsLeft];
}

class LocalAuthSuccess extends LocalAuthState {
  const LocalAuthSuccess();

  @override
  List<Object?> get props => const [];
}

class LocalAuthError extends LocalAuthState {
  const LocalAuthError(this.error);
  final AppException error;

  @override
  List<Object?> get props => [error];
}

/// Aucun PIN configuré — l'utilisateur doit en créer un (premier login ou PIN effacé)
class LocalAuthNoPinSet extends LocalAuthState {
  const LocalAuthNoPinSet();

  @override
  List<Object?> get props => const [];
}
