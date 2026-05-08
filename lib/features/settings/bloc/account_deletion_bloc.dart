import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'account_deletion_event.dart';
part 'account_deletion_state.dart';

class AccountDeletionBloc
    extends Bloc<AccountDeletionEvent, AccountDeletionState> {
  final AccountDeletionRepository _repository;

  AccountDeletionBloc(this._repository) : super(const AccountDeletionInitial()) {
    on<RequestDeletion>(_onRequestDeletion);
    on<ReactivateAccount>(_onReactivateAccount);
  }

  Future<void> _onRequestDeletion(
    RequestDeletion event,
    Emitter<AccountDeletionState> emit,
  ) async {
    emit(const AccountDeletionLoading());
    try {
      await _repository.requestDeletion();
      emit(const AccountDeletionRequested());
    } on ValidationException {
      emit(const AccountDeletionError(
        message:
            'Vous avez un paiement en cours. La suppression sera possible une fois la livraison confirmée.',
        isEscrowBlocked: true,
      ));
    } on AppException catch (e) {
      emit(AccountDeletionError(message: e.message));
    } catch (_) {
      emit(const AccountDeletionError(
          message: 'Une erreur est survenue. Veuillez réessayer.'));
    }
  }

  Future<void> _onReactivateAccount(
    ReactivateAccount event,
    Emitter<AccountDeletionState> emit,
  ) async {
    emit(const AccountDeletionLoading());
    try {
      final user = await _repository.reactivateAccount();
      emit(AccountReactivated(user));
    } on AppException catch (e) {
      emit(AccountDeletionError(message: e.message));
    } catch (_) {
      emit(const AccountDeletionError(
          message: 'Une erreur est survenue. Veuillez réessayer.'));
    }
  }
}
