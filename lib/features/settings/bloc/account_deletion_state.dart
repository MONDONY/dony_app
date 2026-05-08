part of 'account_deletion_bloc.dart';

sealed class AccountDeletionState extends Equatable {
  const AccountDeletionState();

  @override
  List<Object?> get props => [];
}

class AccountDeletionInitial extends AccountDeletionState {
  const AccountDeletionInitial();
}

class AccountDeletionLoading extends AccountDeletionState {
  const AccountDeletionLoading();
}

class AccountDeletionRequested extends AccountDeletionState {
  const AccountDeletionRequested();
}

class DeletionOtpSent extends AccountDeletionState {
  final String verificationId;
  final String phoneHint;

  const DeletionOtpSent({required this.verificationId, required this.phoneHint});

  @override
  List<Object?> get props => [verificationId, phoneHint];
}

class AccountDeletionImmediate extends AccountDeletionState {
  const AccountDeletionImmediate();
}

class AccountReactivated extends AccountDeletionState {
  final UserModel user;
  const AccountReactivated(this.user);

  @override
  List<Object?> get props => [user];
}

class AccountDeletionError extends AccountDeletionState {
  final String message;
  final bool isEscrowBlocked;
  final bool isReauthRequired;

  const AccountDeletionError({
    required this.message,
    this.isEscrowBlocked = false,
    this.isReauthRequired = false,
  });

  @override
  List<Object?> get props => [message, isEscrowBlocked, isReauthRequired];
}
