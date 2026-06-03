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
    on<WalletTopupRequested>(_onTopup);
  }

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
        case 'WAVE':
          final url = await _repository.topupWave(amount: event.amount);
          if (url != null) {
            emit(WalletTopupRedirectReady(url));
            unawaited(_analytics.logEvent(
              AnalyticsEvents.walletTopupCompleted,
              properties: {'amount': event.amount, 'method': event.paymentMethod},
            ));
          } else {
            emit(WalletError('Réponse vide du serveur'));
          }
        case 'ORANGE_MONEY':
          final url2 =
              await _repository.topupOrangeMoney(amount: event.amount);
          if (url2 != null) {
            emit(WalletTopupRedirectReady(url2));
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
