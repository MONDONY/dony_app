import 'package:dony/core/error/app_exception.dart';
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

  AccountDeletionBloc(this._repository, this._reauth)
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
    } on AppException catch (e) {
      emit(AccountDeletionError(message: e.message));
    } catch (_) {
      emit(const AccountDeletionError(
          message: 'Impossible d\'envoyer le code SMS. Veuillez réessayer.'));
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
    } on ValidationException {
      emit(const AccountDeletionError(
        message:
            'Vous avez un paiement en cours. La suppression sera possible une fois la livraison confirmée.',
        isEscrowBlocked: true,
      ));
    } on UnauthorizedException {
      emit(const AccountDeletionError(
        message: 'Session expirée. Veuillez recommencer la procédure.',
        isReauthRequired: true,
      ));
    } on AppException catch (e) {
      emit(AccountDeletionError(message: e.message));
    } catch (_) {
      emit(const AccountDeletionError(
          message: 'Une erreur est survenue lors de la suppression.'));
    }
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    final start = phone.substring(0, phone.length - 4);
    final end = phone.substring(phone.length - 2);
    return '$start•••• $end';
  }
}
