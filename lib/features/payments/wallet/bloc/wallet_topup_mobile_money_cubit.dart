import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recharge du portefeuille par mobile money (Wave / Orange Money via
/// pawaPay) : chargement des opérateurs utilisables sur le numéro payeur,
/// initiation du dépôt, puis sondage du statut jusqu'à confirmation, échec
/// ou expiration (15 min sans réponse opérateur).
///
/// Le timer de sondage vit ici, jamais côté écran : [close] l'annule, et
/// aucun `emit` n'a lieu après fermeture du cubit (garde [isClosed]).
class WalletTopupMobileMoneyCubit extends Cubit<WalletTopupMobileMoneyState> {
  WalletTopupMobileMoneyCubit(
    this._repository,
    this._analytics, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const WalletTopupMobileMoneyIdle());

  static const pollInterval = Duration(seconds: 3);
  static const expiry = Duration(minutes: 15);

  static const _expiredMessage = "Le paiement n'a pas été validé à temps.";
  static const _genericFailureMessage =
      "Le paiement a été refusé par l'opérateur.";

  final WalletRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  Timer? _pollTimer;
  bool _pollInFlight = false;

  /// Catalogue des opérateurs utilisables sur [phoneNumber], pré-sélectionne
  /// celui détecté par pawaPay pour ce numéro.
  Future<void> loadProviders(String phoneNumber) async {
    emit(const WalletTopupMobileMoneyProvidersLoading());
    try {
      final catalog = await _repository.topupProviders(phoneNumber);
      if (isClosed) return;
      emit(
        WalletTopupMobileMoneyProvidersReady(
          catalog: catalog,
          selectedProvider: catalog.detected,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(WalletTopupMobileMoneyError(unwrapDioError(e)));
    }
  }

  /// Change l'opérateur choisi. Sans effet hors de [WalletTopupMobileMoneyProvidersReady].
  void selectProvider(String code) {
    final current = state;
    if (current is WalletTopupMobileMoneyProvidersReady) {
      emit(current.copyWith(selectedProvider: code));
    }
  }

  /// Initie la recharge avec l'opérateur sélectionné (`null` si
  /// [loadProviders] n'a jamais été appelé : le back retient alors celui
  /// qu'il détecte lui-même), puis démarre le sondage du statut.
  Future<void> initiate({
    required double amount,
    required String phoneNumber,
  }) async {
    stopPolling();
    final current = state;
    final provider = current is WalletTopupMobileMoneyProvidersReady
        ? current.selectedProvider
        : null;
    emit(const WalletTopupMobileMoneyInitiating());
    try {
      final topup = await _repository.topupMobileMoney(
        amount: amount,
        phoneNumber: phoneNumber,
        provider: provider,
      );
      if (isClosed) return;
      emit(WalletTopupMobileMoneyAwaiting(topup: topup, startedAt: _now()));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletTopupMobileMoneyInitiated,
          properties: {'provider': topup.provider, 'currency': topup.currency},
        ),
      );
      startPolling();
    } catch (e) {
      if (isClosed) return;
      emit(WalletTopupMobileMoneyError(unwrapDioError(e)));
    }
  }

  /// Démarre le sondage périodique du statut. Sans effet hors de
  /// [WalletTopupMobileMoneyAwaiting].
  void startPolling() {
    stopPolling();
    if (state is! WalletTopupMobileMoneyAwaiting) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (_pollInFlight || isClosed) return;
    final current = state;
    if (current is! WalletTopupMobileMoneyAwaiting) {
      stopPolling();
      return;
    }
    if (_now().difference(current.startedAt) >= expiry) {
      stopPolling();
      if (!isClosed) emit(const WalletTopupMobileMoneyFailed(_expiredMessage));
      return;
    }
    _pollInFlight = true;
    try {
      final status = await _repository.topupStatus(current.topup.topupId);
      if (isClosed) return;
      switch (status.status) {
        case 'CONFIRMED':
          stopPolling();
          emit(WalletTopupMobileMoneyConfirmed(status));
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.walletTopupMobileMoneyConfirmed,
              properties: {
                'provider': status.provider,
                'currency': status.currency,
              },
            ),
          );
        case 'FAILED':
          stopPolling();
          emit(
            WalletTopupMobileMoneyFailed(
              _presentableFailure(status.failureReason),
            ),
          );
        default:
        // PENDING : rien à faire, le prochain tick relira le statut.
      }
    } catch (_) {
      // Sondage silencieux : une erreur réseau transitoire ne casse pas
      // l'écran, le prochain sondage réessaiera.
    } finally {
      _pollInFlight = false;
    }
  }

  String _presentableFailure(String? reason) =>
      (reason == null || reason.trim().isEmpty)
      ? _genericFailureMessage
      : reason;

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
