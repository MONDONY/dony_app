import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'account_deletion_event.dart';
part 'account_deletion_state.dart';

class AccountDeletionBloc
    extends Bloc<AccountDeletionEvent, AccountDeletionState> {
  final AccountDeletionRepository _repository;
  final AnalyticsService _analytics;

  AccountDeletionBloc(this._repository, this._analytics)
      : super(const AccountDeletionInitial()) {
    on<RequestDeletion>(_onRequestDeletion);
    on<ReactivateAccount>(_onReactivateAccount);
    on<ConfirmImmediateDeletion>(_onConfirmImmediateDeletion);
  }

  Future<void> _onRequestDeletion(
    RequestDeletion event,
    Emitter<AccountDeletionState> emit,
  ) async {
    emit(const AccountDeletionLoading());
    try {
      await _repository.requestDeletion();
      emit(const AccountDeletionRequested());
      unawaited(_analytics.logEvent(AnalyticsEvents.accountDeletionRequested));
    } on ValidationException catch (e) {
      emit(AccountDeletionError(
        error: ValidationException(
          'Vous avez un paiement en cours. La suppression sera possible une fois la livraison confirmée.',
          code: e.code ?? 'escrow-blocked',
        ),
        isEscrowBlocked: true,
      ));
    } catch (e) {
      emit(AccountDeletionError(error: unwrapDioError(e)));
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
    } catch (e) {
      emit(AccountDeletionError(error: unwrapDioError(e)));
    }
  }

  Future<void> _onConfirmImmediateDeletion(
    ConfirmImmediateDeletion event,
    Emitter<AccountDeletionState> emit,
  ) async {
    emit(const AccountDeletionLoading());
    try {
      await _repository.deleteImmediately();
      emit(const AccountDeletionImmediate());
    } on ValidationException catch (e) {
      emit(AccountDeletionError(
        error: ValidationException(
          'Vous avez un paiement en cours. La suppression sera possible une fois la livraison confirmée.',
          code: e.code ?? 'escrow-blocked',
        ),
        isEscrowBlocked: true,
      ));
    } catch (e) {
      emit(AccountDeletionError(error: unwrapDioError(e)));
    }
  }
}
