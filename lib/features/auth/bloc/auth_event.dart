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

  const AuthUpdateProfileRequested({
    this.firstName,
    this.lastName,
    this.email,
    this.birthDate,
    this.city,
  });

  @override
  List<Object?> get props => [firstName, lastName, email, birthDate, city];
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
