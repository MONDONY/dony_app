import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthSendOtpRequested extends AuthEvent {
  final String phoneNumber;

  const AuthSendOtpRequested(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthPhoneVerified extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final bool autoVerified;

  const AuthPhoneVerified({
    required this.verificationId,
    required this.smsCode,
    this.autoVerified = false,
  });

  @override
  List<Object?> get props => [verificationId, smsCode, autoVerified];
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Déconnexion volontaire pour se connecter à un AUTRE compte (depuis l'écran
/// PIN). Contrairement à [AuthLogoutRequested], le PIN local est effacé : le
/// nouveau compte ne doit pas hériter du PIN du compte précédent.
class AuthSwitchAccountRequested extends AuthEvent {
  const AuthSwitchAccountRequested();
}

class AuthDeleteAccountRequested extends AuthEvent {
  const AuthDeleteAccountRequested();
}

class AuthUpdateProfileRequested extends AuthEvent {
  final String? firstName;
  final String? lastName;
  final String? email;
  final DateTime? birthDate;
  final String? city;
  final String? phoneNumber;

  const AuthUpdateProfileRequested({
    this.firstName,
    this.lastName,
    this.email,
    this.birthDate,
    this.city,
    this.phoneNumber,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    email,
    birthDate,
    city,
    phoneNumber,
  ];
}

class OnboardingCompleted extends AuthEvent {
  const OnboardingCompleted();
}

class AuthDialCodeChanged extends AuthEvent {
  final String code;
  final String flag;
  const AuthDialCodeChanged({required this.code, required this.flag});
  @override
  List<Object?> get props => [code, flag];
}

class AuthOtpTimerTicked extends AuthEvent {
  const AuthOtpTimerTicked();
}

class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

class AuthAppleSignInRequested extends AuthEvent {
  const AuthAppleSignInRequested();
}

class AuthEmailOtpSendRequested extends AuthEvent {
  final String email;
  const AuthEmailOtpSendRequested(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthEmailOtpVerifyRequested extends AuthEvent {
  final String email;
  final String code;
  const AuthEmailOtpVerifyRequested({required this.email, required this.code});
  @override
  List<Object?> get props => [email, code];
}

class AuthRegisterWithEmailRequested extends AuthEvent {
  final String email;
  const AuthRegisterWithEmailRequested({required this.email});
  @override
  List<Object?> get props => [email];
}

class AuthAddPhoneFromProfileRequested extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final String phoneNumber;
  const AuthAddPhoneFromProfileRequested({
    required this.verificationId,
    required this.smsCode,
    required this.phoneNumber,
  });
  @override
  List<Object?> get props => [verificationId, smsCode, phoneNumber];
}

class AuthAddEmailFromProfileRequested extends AuthEvent {
  final String email;
  final String code;
  const AuthAddEmailFromProfileRequested({
    required this.email,
    required this.code,
  });
  @override
  List<Object?> get props => [email, code];
}

/// Met à jour l'état AuthBloc directement avec un UserModel déjà chargé,
/// sans faire d'aller-retour réseau. Utilisé après une activation locale
/// (ex. activation rôle TRAVELER) où le serveur a déjà retourné l'entité à jour.
class AuthUserSynced extends AuthEvent {
  final UserModel user;
  const AuthUserSynced(this.user);
  @override
  List<Object?> get props => [user];
}
