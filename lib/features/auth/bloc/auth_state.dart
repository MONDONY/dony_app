import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  final String dialCode;
  final String dialFlag;
  const AuthInitial({this.dialCode = '+33', this.dialFlag = '🇫🇷'});
  @override
  List<Object?> get props => [dialCode, dialFlag];
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthOtpSent extends AuthState {
  final String verificationId;
  final String phoneNumber;
  final int secondsLeft;

  const AuthOtpSent({
    required this.verificationId,
    required this.phoneNumber,
    this.secondsLeft = 60,
  });

  AuthOtpSent copyWith({int? secondsLeft}) => AuthOtpSent(
        verificationId: verificationId,
        phoneNumber: phoneNumber,
        secondsLeft: secondsLeft ?? this.secondsLeft,
      );

  @override
  List<Object?> get props => [verificationId, phoneNumber, secondsLeft];
}

class AuthSelectingRoles extends AuthState {
  final Set<String> selectedRoles;
  const AuthSelectingRoles({required this.selectedRoles});
  @override
  List<Object?> get props => [selectedRoles];
}

class AuthOtpVerified extends AuthState {
  final String phoneNumber;

  const AuthOtpVerified({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthAccountDeleted extends AuthState {
  const AuthAccountDeleted();
}

/// L'utilisateur est toujours connecté Firebase mais l'app est verrouillée.
/// L'écran PIN doit s'afficher pour déverrouiller.
class AuthLocked extends AuthState {
  const AuthLocked();
}

/// Émis après une mise à jour de profil réussie.
/// Remplace temporairement AuthAuthenticated jusqu'au prochain check.
class AuthProfileUpdated extends AuthState {
  final UserModel user;

  const AuthProfileUpdated(this.user);

  @override
  List<Object?> get props => [user];
}
