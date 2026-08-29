import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/apple_token_revoker.dart';
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
  final AppleTokenRevoker _appleTokenRevoker;

  AccountDeletionBloc(
    this._repository,
    this._analytics,
    this._appleTokenRevoker,
  ) : super(const AccountDeletionInitial()) {
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
      // Contrairement aux deux autres chemins (ConfirmImmediateDeletion,
      // AuthBloc._onDeleteAccountRequested), celui-ci n'est pas irréversible :
      // c'est la « Pause 30 jours », et requestDeletion() peut échouer
      // (séquestre actif → ValidationException, serveur, réseau). Révoquer
      // AVANT ferait ré-authentifier l'utilisateur avec Apple pour un compte
      // dont la suppression n'a finalement pas eu lieu. On révoque donc APRÈS
      // un requestDeletion() qui a réussi, dans le même try : un échec saute
      // directement au catch, sans révocation.
      //
      // La session Firebase reste utilisable ici : côté backend,
      // UserService.requestDeletion() se limite à passer le statut à
      // PENDING_DELETION en base, il ne touche jamais Firebase (la
      // suppression du compte Firebase n'a lieu qu'à la finalisation, en
      // AccountFinalizationService.finalize(), déclenchée par le scheduler
      // après les 30 jours ou par le chemin HARD_IMMEDIATE — jamais ici).
      await _repository.requestDeletion();
      // Apple impose de révoquer le jeton Sign in with Apple au moment de la
      // suppression. L'appel est sans effet pour un compte non Apple et
      // n'échoue jamais, donc il ne peut pas bloquer la suppression
      // (cf. AppleTokenRevoker.revokeIfAppleUser).
      await _appleTokenRevoker.revokeIfAppleUser();
      emit(const AccountDeletionRequested());
      unawaited(_analytics.logEvent(AnalyticsEvents.accountDeletionRequested));
    } on ValidationException catch (e) {
      emit(
        AccountDeletionError(
          error: ValidationException(
            'Vous avez un paiement en cours. La suppression sera possible une fois la livraison confirmée.',
            code: e.code ?? 'escrow-blocked',
          ),
          isEscrowBlocked: true,
        ),
      );
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
      // Apple impose de révoquer le jeton Sign in with Apple au moment de la
      // suppression. L'appel est sans effet pour un compte non Apple et
      // n'échoue jamais, donc il ne peut pas bloquer la suppression
      // (cf. AppleTokenRevoker.revokeIfAppleUser).
      await _appleTokenRevoker.revokeIfAppleUser();
      await _repository.deleteImmediately();
      emit(const AccountDeletionImmediate());
    } on ValidationException catch (e) {
      emit(
        AccountDeletionError(
          error: ValidationException(
            'Vous avez un paiement en cours. La suppression sera possible une fois la livraison confirmée.',
            code: e.code ?? 'escrow-blocked',
          ),
          isEscrowBlocked: true,
        ),
      );
    } catch (e) {
      emit(AccountDeletionError(error: unwrapDioError(e)));
    }
  }
}
