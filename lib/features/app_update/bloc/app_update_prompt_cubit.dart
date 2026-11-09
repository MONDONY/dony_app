import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/app_update/data/services/app_store_launcher.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:dony/features/app_update/data/services/app_update_snooze_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Délai avant que le modal de mise à jour recommandée revienne après un
/// « Plus tard ».
const Duration kAppUpdatePromptSnooze = Duration(hours: 12);

/// Faut-il montrer le modal de mise à jour recommandée : `true` quand une
/// version recommandée plus récente existe, que l'utilisateur ne l'a pas
/// repoussée depuis moins de [kAppUpdatePromptSnooze] et que le modal n'a pas
/// déjà été montré pendant cette session.
///
/// « Mettre à jour » ne mémorise rien : le modal reviendra au prochain
/// lancement tant que l'application n'est pas à jour.
class AppUpdatePromptCubit extends Cubit<bool> {
  AppUpdatePromptCubit(
    this._service,
    this._store,
    this._analytics, {
    Future<void> Function()? openStore,
    DateTime Function()? now,
  }) : _openStore = openStore ?? AppStoreLauncher.open,
       _now = now ?? DateTime.now,
       super(false);

  final AppUpdateService _service;
  final AppUpdateSnoozeStore _store;
  final AnalyticsService _analytics;
  final Future<void> Function() _openStore;
  final DateTime Function() _now;
  bool _shownThisSession = false;

  Future<void> check() async {
    if (_shownThisSession) return;
    final recommended = await _service.isUpdateRecommended();
    if (isClosed || !recommended || _shownThisSession) return;
    final snoozedAt = await _store.lastSnoozedAt();
    if (isClosed || _shownThisSession || !_isSnoozeOver(snoozedAt)) return;
    _shownThisSession = true;
    emit(true);
    unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerShown));
  }

  /// Un horodatage absent ou dans le futur (horloge déréglée) vaut « jamais
  /// repoussé » : il ne doit jamais bloquer le modal.
  bool _isSnoozeOver(DateTime? snoozedAt) {
    if (snoozedAt == null) return true;
    final elapsed = _now().difference(snoozedAt);
    return elapsed.isNegative || elapsed >= kAppUpdatePromptSnooze;
  }

  /// « Mettre à jour » : ouvre le store, sans rien mémoriser.
  Future<void> update() {
    if (state) emit(false);
    unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerTapped));
    return _openStore();
  }

  /// « Plus tard », tap à côté ou geste retour : repousse le modal.
  Future<void> later() async {
    if (state) emit(false);
    unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerDismissed));
    await _store.snooze(_now());
  }
}
