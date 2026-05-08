part of 'account_deletion_bloc.dart';

enum DeleteMode { soft, hard }

sealed class AccountDeletionEvent extends Equatable {
  const AccountDeletionEvent();

  @override
  List<Object?> get props => [];
}

class RequestDeletion extends AccountDeletionEvent {
  const RequestDeletion();
}

class ReactivateAccount extends AccountDeletionEvent {
  const ReactivateAccount();
}

class RequestOtpForImmediateDeletion extends AccountDeletionEvent {
  const RequestOtpForImmediateDeletion();
}

class ConfirmImmediateDeletion extends AccountDeletionEvent {
  final String verificationId;
  final String smsCode;

  const ConfirmImmediateDeletion({
    required this.verificationId,
    required this.smsCode,
  });

  @override
  List<Object?> get props => [verificationId, smsCode];
}
