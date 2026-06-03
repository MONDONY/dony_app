import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/data/firebase_phone_reauth.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'account_deletion_event.dart';
part 'account_deletion_state.dart';

class AccountDeletionBloc
    extends Bloc<AccountDeletionEvent, AccountDeletionState> {
  final AccountDeletionRepository _repository;
  final FirebasePhoneReauth _reauth;
  final AnalyticsService _analytics;

  AccountDeletionBloc(this._repository, this._reauth, this._analytics)
      : super(const AccountDeletionInitial()) {
    on<RequestDeletion>(_onRequestDeletion);
    on<ReactivateAccount>(_onReactivateAccount);
    on<RequestOtpForImmediateDeletion>(_onRequestOtp);
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

  Future<void> _onRequestOtp(
    RequestOtpForImmediateDeletion event,
    Emitter<AccountDeletionState> emit,
  ) async {
    emit(const AccountDeletionLoading());
    try {
      final phone = _reauth.currentUserPhone ?? '';
      final verificationId = await _reauth.sendVerificationCode();
      emit(DeletionOtpSent(
        verificationId: verificationId,
        phoneHint: _maskPhone(phone),
      ));
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
      await _reauth.reauthenticate(event.verificationId, event.smsCode);
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
    } on UnauthorizedException catch (e) {
      emit(AccountDeletionError(
        error: UnauthorizedException(
          'Session expirée. Veuillez recommencer la procédure.',
          e.code,
        ),
        isReauthRequired: true,
      ));
    } catch (e) {
      emit(AccountDeletionError(error: unwrapDioError(e)));
    }
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    final prefix = phone.substring(0, 3); // country code e.g. "+33"
    final suffix = phone.substring(phone.length - 2); // last 2 digits
    return '$prefix ••••••• $suffix';
  }
}
