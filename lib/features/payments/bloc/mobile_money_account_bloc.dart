import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Compte de versement mobile money du voyageur (Wave / Orange Money via
/// pawaPay) : consultation, activation et désactivation.
///
/// Style identique à `BidNegotiationBloc` : le repository ne fait que
/// passer, c'est ici que les erreurs sont déballées (`unwrapDioError`) et
/// que les events analytics sont tirés, en `unawaited`.
class MobileMoneyAccountBloc
    extends Bloc<MobileMoneyAccountEvent, MobileMoneyAccountState> {
  MobileMoneyAccountBloc(this._repository, this._analytics)
    : super(const MobileMoneyAccountInitial()) {
    on<MobileMoneyAccountRequested>(_onRequested);
    on<MobileMoneyAccountActivateRequested>(_onActivateRequested);
    on<MobileMoneyAccountDisableRequested>(_onDisableRequested);
  }

  final MobileMoneyAccountRepository _repository;
  final AnalyticsService _analytics;

  /// Compte par défaut utilisé quand aucun compte n'a encore été chargé.
  static const _fallbackAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.notConfigured,
  );

  /// Compte porté par l'état courant, quand il y en a un (Loaded, Updating,
  /// ou Error avec compte conservé). Sert de base à Updating lors d'une
  /// activation/désactivation, pour que l'écran reste affichable.
  MobileMoneyAccount? get _currentAccount {
    final s = state;
    return switch (s) {
      MobileMoneyAccountLoaded() => s.account,
      MobileMoneyAccountUpdating() => s.account,
      MobileMoneyAccountError() => s.account,
      MobileMoneyAccountPhoneRequired() => s.account,
      _ => null,
    };
  }

  Future<void> _onRequested(
    MobileMoneyAccountRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    emit(const MobileMoneyAccountLoading());
    try {
      final account = await _repository.get();
      emit(MobileMoneyAccountLoaded(account));
    } catch (e) {
      emit(MobileMoneyAccountError(unwrapDioError(e)));
    }
  }

  Future<void> _onActivateRequested(
    MobileMoneyAccountActivateRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    final base = _currentAccount ?? _fallbackAccount;
    emit(MobileMoneyAccountUpdating(base));
    try {
      final account = await _repository.activate(
        phoneNumber: event.phoneNumber,
      );
      emit(MobileMoneyAccountLoaded(account));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyAccountActivated,
          properties: {
            'provider': account.providerLabel ?? 'inconnu',
            'currency': account.currency ?? '',
          },
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      // Aucun numéro disponible (compte Firebase sans téléphone, rien fourni
      // dans l'event) : un formulaire de saisie, jamais une snackbar
      // d'erreur — voir MobileMoneyAccountScreen.
      if (error.code == 'mobile-money-phone-required') {
        emit(MobileMoneyAccountPhoneRequired(base));
      } else {
        emit(MobileMoneyAccountError(error, account: base));
      }
    }
  }

  Future<void> _onDisableRequested(
    MobileMoneyAccountDisableRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    final base = _currentAccount ?? _fallbackAccount;
    emit(MobileMoneyAccountUpdating(base));
    try {
      final account = await _repository.disable();
      emit(MobileMoneyAccountLoaded(account));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyAccountDisabled,
          properties: {
            'provider': account.providerLabel ?? 'inconnu',
            'currency': account.currency ?? '',
          },
        ),
      );
    } catch (e) {
      emit(MobileMoneyAccountError(unwrapDioError(e), account: base));
    }
  }
}
