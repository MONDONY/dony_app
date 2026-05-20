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
  List<Object?> get props => [firstName, lastName, email, birthDate, city, phoneNumber];
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
  final List<String> roles;
  const AuthRegisterWithEmailRequested({required this.email, required this.roles});
  @override
  List<Object?> get props => [email, roles];
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
  const AuthAddEmailFromProfileRequested({required this.email, required this.code});
  @override
  List<Object?> get props => [email, code];
}
