import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// État du changement de portefeuille actif depuis l'écran Portefeuille
/// (FLUTTER-8F).
///
/// [switchCount] augmente à chaque changement réussi : deux changements
/// successifs vers la même devise restent deux succès distincts pour un
/// `listenWhen`.
class WalletActiveCurrencyState {
  const WalletActiveCurrencyState({
    this.pendingCurrency,
    this.switchedTo,
    this.switchCount = 0,
    this.error,
  });

  /// Devise en cours d'enregistrement, `null` au repos.
  final String? pendingCurrency;

  /// Devise active confirmée par le serveur au dernier changement réussi.
  final String? switchedTo;
  final int switchCount;
  final AppException? error;

  bool get isSwitching => pendingCurrency != null;
}

/// Change la devise active, c'est-à-dire le portefeuille courant : aucun
/// solde n'est converti, chaque portefeuille garde sa devise.
///
/// Les préférences sont relues sur le serveur juste avant l'écriture : le
/// `PUT` envoie l'objet complet, et repartir de l'état local (Hive) pourrait
/// réécrire une préférence modifiée ailleurs. Sur un serveur antérieur à
/// FLUTTER-8F, un portefeuille non vide renvoie 422 `currency-locked`,
/// exposé tel quel dans [WalletActiveCurrencyState.error].
class WalletActiveCurrencyCubit extends Cubit<WalletActiveCurrencyState> {
  WalletActiveCurrencyCubit(this._prefs, this._analytics)
    : super(const WalletActiveCurrencyState());

  final BusinessPrefsRepository _prefs;
  final AnalyticsService _analytics;

  Future<void> switchTo(String currency) async {
    if (state.isSwitching) return;
    final target = currency.toUpperCase();
    emit(
      WalletActiveCurrencyState(
        pendingCurrency: target,
        switchedTo: state.switchedTo,
        switchCount: state.switchCount,
      ),
    );
    try {
      final current = await _prefs.fetchPrefs();
      if (isClosed) return;
      final previous = current.currencyCode.toUpperCase();
      final saved = previous == target
          ? current
          : await _prefs.updatePrefs(current.copyWith(currencyCode: target));
      if (isClosed) return;
      emit(
        WalletActiveCurrencyState(
          switchedTo: saved.currencyCode.toUpperCase(),
          switchCount: state.switchCount + 1,
        ),
      );
      if (previous != target) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.walletActiveCurrencySwitched,
            properties: {'from': previous, 'to': target},
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      emit(
        WalletActiveCurrencyState(
          switchedTo: state.switchedTo,
          switchCount: state.switchCount,
          error: unwrapDioError(e),
        ),
      );
    }
  }
}
