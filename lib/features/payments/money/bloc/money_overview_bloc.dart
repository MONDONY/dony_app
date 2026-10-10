import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/data/repositories/money_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'money_overview_event.dart';
part 'money_overview_state.dart';

/// Écran « Mon argent » et pastille de l'en-tête d'Activités (FLUTTER-HV,
/// déplacée de l'accueil par FLUTTER-J3).
///
/// [fallbackToWallet] : sur un back sans l'aperçu, l'écran retombe sur les
/// soldes de `/wallet/balance` ; la pastille, elle, n'en a pas besoin et
/// redevient une simple icône (`false`).
class MoneyOverviewBloc extends Bloc<MoneyOverviewEvent, MoneyOverviewState> {
  MoneyOverviewBloc(
    this._repository,
    this._walletRepository,
    this._analytics, {
    this.fallbackToWallet = true,
    this.trackViews = true,
    String? Function()? cachedActiveCurrency,
  }) : _cachedActiveCurrency =
           cachedActiveCurrency ?? (() => ActiveCurrency.current?.code),
       super(const MoneyOverviewInitial()) {
    on<MoneyOverviewLoadRequested>(_onLoad);
    on<MoneyOverviewRefreshRequested>(_onRefresh);
  }

  final MoneyRepository _repository;
  final WalletRepository _walletRepository;
  final AnalyticsService _analytics;
  final bool fallbackToWallet;

  /// `false` pour la pastille : seul l'écran compte comme une consultation.
  final bool trackViews;

  /// Devise active du cache local (préférence confirmée par le serveur),
  /// dernier repli quand ni l'aperçu ni le portefeuille ne la donnent.
  final String? Function() _cachedActiveCurrency;

  bool _viewTracked = false;

  Future<void> _onLoad(
    MoneyOverviewLoadRequested event,
    Emitter<MoneyOverviewState> emit,
  ) async {
    emit(const MoneyOverviewLoading());
    await _fetch(emit, keepOnError: false);
  }

  Future<void> _onRefresh(
    MoneyOverviewRefreshRequested event,
    Emitter<MoneyOverviewState> emit,
  ) async {
    try {
      await _fetch(emit, keepOnError: state is MoneyOverviewLoaded);
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  Future<void> _fetch(
    Emitter<MoneyOverviewState> emit, {
    required bool keepOnError,
  }) async {
    try {
      final overview = await _resolveActiveCurrency(
        await _repository.getOverview(),
      );
      if (emit.isDone) return;
      emit(MoneyOverviewLoaded(overview));
      _track(overview, legacy: false);
    } on MoneyOverviewUnavailable {
      if (!fallbackToWallet) {
        if (!emit.isDone) {
          emit(
            const MoneyOverviewLoaded(
              MoneyOverviewModel(),
              upcomingAvailable: false,
            ),
          );
        }
        return;
      }
      try {
        final wallet = await _walletRepository.getBalance();
        if (emit.isDone) return;
        final balances = wallet.heldBalances.isEmpty
            ? [MoneyAmount(wallet.currency, wallet.balance)]
            : [
                for (final b in wallet.heldBalances)
                  MoneyAmount(b.currency, b.balance),
              ];
        final overview = MoneyOverviewModel(
          wallet: balances,
          activeCurrency: wallet.currency.toUpperCase(),
        );
        emit(MoneyOverviewLoaded(overview, upcomingAvailable: false));
        _track(overview, legacy: true);
      } catch (e) {
        if (emit.isDone || keepOnError) return;
        emit(MoneyOverviewError(unwrapDioError(e)));
      }
    } catch (e) {
      // Rafraîchissement raté : on garde ce qui est affiché.
      if (emit.isDone || keepOnError) return;
      emit(MoneyOverviewError(unwrapDioError(e)));
    }
  }

  /// Devise active à mettre en grand sur la carte « Disponible »
  /// (FLUTTER-J4). Un back récent la donne dans l'aperçu (`activeCurrency`) ;
  /// sinon l'écran la lit comme le portefeuille (`/wallet/balance`), puis
  /// dans le cache local. Inutile pour la pastille, et tant qu'un seul solde
  /// existe : aucun appel de plus dans ces cas.
  Future<MoneyOverviewModel> _resolveActiveCurrency(
    MoneyOverviewModel overview,
  ) async {
    if (overview.activeCurrency != null ||
        !fallbackToWallet ||
        overview.wallet.length < 2) {
      return overview;
    }
    try {
      final wallet = await _walletRepository.getBalance();
      return overview.withActiveCurrency(wallet.currency.toUpperCase());
    } catch (_) {
      return overview.withActiveCurrency(_cachedActiveCurrency());
    }
  }

  void _track(MoneyOverviewModel overview, {required bool legacy}) {
    if (!trackViews || _viewTracked) return;
    _viewTracked = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.moneyOverviewViewed,
        properties: {
          'traveler_items': overview.travelerItems.length,
          'sender_items': overview.senderItems.length,
          'legacy_backend': legacy,
        },
      ),
    );
  }
}
