import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Comptes de versement mobile money du voyageur (un par code opérateur
/// pawaPay) : consultation, ajout, changement de numéro, retrait.
///
/// Style identique à `BidNegotiationBloc` : le repository ne fait que
/// passer, c'est ici que les erreurs sont déballées (`unwrapDioError`) et
/// que les events analytics sont tirés, en `unawaited`, sans jamais de
/// numéro.
///
/// Toute écriture suppose la liste lue : c'est `accounts()` qui apprend au
/// repository si le back est ancien (repli sur l'ancien contrat). Une
/// écriture partie sans cette lecture (après un échec de chargement, par
/// exemple) viserait donc la mauvaise route : la liste est relue d'abord.
class MobileMoneyAccountBloc
    extends Bloc<MobileMoneyAccountEvent, MobileMoneyAccountState> {
  MobileMoneyAccountBloc(this._repository, this._analytics)
    : super(const MobileMoneyAccountInitial()) {
    on<MobileMoneyAccountsRequested>(_onRequested);
    on<MobileMoneyAccountAddRequested>(
      (event, emit) => _write(
        emit,
        action: MobileMoneyAccountAction.added,
        provider: event.provider,
        call: () => _repository.addAccount(
          phoneNumber: event.phoneNumber,
          provider: event.provider,
        ),
      ),
    );
    on<MobileMoneyAccountNumberChangeRequested>(
      (event, emit) => _write(
        emit,
        action: MobileMoneyAccountAction.numberChanged,
        provider: event.account.provider,
        call: () => _repository.changeNumber(
          account: event.account,
          phoneNumber: event.phoneNumber,
        ),
      ),
    );
    on<MobileMoneyAccountRemoveRequested>(
      (event, emit) => _write(
        emit,
        action: MobileMoneyAccountAction.removed,
        provider: event.account.provider,
        call: () => _repository.removeAccount(event.account),
      ),
    );
  }

  final MobileMoneyAccountRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onRequested(
    MobileMoneyAccountsRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    emit(const MobileMoneyAccountLoading());
    try {
      emit(MobileMoneyAccountLoaded(await _repository.accounts()));
    } catch (e) {
      emit(MobileMoneyAccountError(unwrapDioError(e)));
    }
  }

  Future<void> _write(
    Emitter<MobileMoneyAccountState> emit, {
    required MobileMoneyAccountAction action,
    required String provider,
    required Future<void> Function() call,
  }) async {
    final current = state;
    // Une écriture à la fois : le second appui pendant l'envoi est ignoré.
    if (current is MobileMoneyAccountLoaded && current.submitting) return;

    var before = current.data;
    if (before == null) {
      try {
        before = await _repository.accounts();
      } catch (e) {
        emit(MobileMoneyAccountError(unwrapDioError(e)));
        return;
      }
    }

    emit(MobileMoneyAccountLoaded(before, submitting: true));
    try {
      await call();
    } catch (e) {
      final error = unwrapDioError(e);
      emit(MobileMoneyAccountActionFailed(before, error));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyPayoutAccountActionFailed,
          properties: {
            'action': action.analyticsName,
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
      return;
    }

    // Écriture passée : la liste est relue, c'est elle que l'écran affiche.
    try {
      final after = await _repository.accounts();
      emit(MobileMoneyAccountActionDone(after, action));
      unawaited(
        _logDone(action, provider, accountsCount: after.accounts.length),
      );
    } catch (e) {
      emit(MobileMoneyAccountError(unwrapDioError(e)));
      unawaited(_logDone(action, provider));
    }
  }

  Future<void> _logDone(
    MobileMoneyAccountAction action,
    String provider, {
    int? accountsCount,
  }) => _analytics.logEvent(
    switch (action) {
      MobileMoneyAccountAction.added =>
        AnalyticsEvents.mobileMoneyPayoutAccountAdded,
      MobileMoneyAccountAction.numberChanged =>
        AnalyticsEvents.mobileMoneyPayoutAccountNumberChanged,
      MobileMoneyAccountAction.removed =>
        AnalyticsEvents.mobileMoneyPayoutAccountRemoved,
    },
    properties: {'provider': provider, 'accounts_count': ?accountsCount},
  );
}

extension on MobileMoneyAccountAction {
  String get analyticsName => switch (this) {
    MobileMoneyAccountAction.added => 'added',
    MobileMoneyAccountAction.numberChanged => 'number_changed',
    MobileMoneyAccountAction.removed => 'removed',
  };
}
