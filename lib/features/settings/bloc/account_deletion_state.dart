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

class AccountReactivated extends AccountDeletionState {
  final UserModel user;
  const AccountReactivated(this.user);

  @override
  List<Object?> get props => [user];
}

class AccountDeletionError extends AccountDeletionState {
  final String message;
  final bool isEscrowBlocked;

  const AccountDeletionError({
    required this.message,
    this.isEscrowBlocked = false,
  });

  @override
  List<Object?> get props => [message, isEscrowBlocked];
}
