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

class ConfirmImmediateDeletion extends AccountDeletionEvent {
  const ConfirmImmediateDeletion();
}
