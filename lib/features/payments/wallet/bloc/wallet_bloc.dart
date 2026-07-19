import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletRepository _repository;
  final AnalyticsService _analytics;

  WalletBloc(this._repository, this._analytics) : super(WalletInitial()) {
    on<WalletLoadRequested>(_onLoad);
    on<WalletRefreshRequested>(_onRefresh);
    on<WalletRefreshAfterTopupRequested>(_onRefreshAfterTopup);
    on<WalletTopupRequested>(_onTopup);
  }

  Future<void> _onRefresh(
    WalletRefreshRequested event,
    Emitter<WalletState> emit,
  ) async {
    // Pas de WalletLoading : on garde la liste affichée pendant le pull-to-refresh.
    try {
      final wallet = await _repository.getBalance();
      if (emit.isDone) return;
      emit(WalletLoaded(wallet));
    } catch (e) {
      if (emit.isDone) return;
      emit(WalletError(unwrapDioError(e).message));
    }
  }

  // Polling post-recharge : le crédit Stripe arrive via webhook (asynchrone),
  // souvent 1-3 s après la fermeture de la PaymentSheet. On retente jusqu'à ce
  // que le solde augmente, sur ~10 s.
  static const _pollAttempts = 6;
  static const _pollInterval = Duration(seconds: 2);

  Future<void> _onLoad(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final wallet = await _repository.getBalance();
      emit(WalletLoaded(wallet));
    } catch (e) {
      emit(WalletError(unwrapDioError(e).message));
    }
  }

  Future<void> _onRefreshAfterTopup(
    WalletRefreshAfterTopupRequested event,
    Emitter<WalletState> emit,
  ) async {
    // Pas de WalletLoading ici : on garde le solde courant affiché pendant le
    // polling pour éviter un flicker, on met à jour dès qu'une réponse arrive.
    for (var attempt = 0; attempt < _pollAttempts; attempt++) {
      try {
        final wallet = await _repository.getBalance();
        if (emit.isDone) return;
        emit(WalletLoaded(wallet));
        // Crédit arrivé (solde augmenté) → inutile de continuer à poller.
        if (wallet.balance > event.previousBalance) return;
      } catch (_) {
        // Erreur transitoire pendant le polling : on garde l'affichage courant
        // et on retentera au tick suivant.
      }
      if (attempt < _pollAttempts - 1) {
        await Future.delayed(_pollInterval);
        if (emit.isDone) return;
      }
    }
  }

  Future<void> _onTopup(
    WalletTopupRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      switch (event.paymentMethod) {
        case 'STRIPE':
          final clientSecret =
              await _repository.topupStripe(amount: event.amount);
          if (clientSecret != null) {
            emit(WalletTopupStripeReady(clientSecret));
            unawaited(_analytics.logEvent(
              AnalyticsEvents.walletTopupCompleted,
              properties: {'amount': event.amount, 'method': event.paymentMethod},
            ));
          } else {
            emit(WalletError('Réponse vide du serveur'));
          }
      }
    } catch (e) {
      emit(WalletError(unwrapDioError(e).message));
    }
  }
}
