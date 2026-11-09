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
/// repoussée depuis moins de [kAppUpdatePromptSnooze].
///
/// Évalué au lancement ([check]) et à chaque retour au premier plan
/// ([onForeground]). Le modal ne se montre jamais deux fois d'affilée sans que
/// l'app ait quitté puis repris le premier plan, ni par-dessus lui-même.
/// « Mettre à jour » ne mémorise rien : le modal reviendra à la prochaine
/// réouverture tant que l'application n'est pas à jour.
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
  bool _armed = true;
  bool _checking = false;

  /// Évalue s'il faut montrer le modal. Relit `recommended_build` déjà connu
  /// localement : aucun appel réseau.
  Future<void> check() async {
    if (!_armed || state || _checking) return;
    _checking = true;
    try {
      final recommended = await _service.isUpdateRecommended();
      if (isClosed || !recommended) return;
      final snoozedAt = await _store.lastSnoozedAt();
      if (isClosed || state || !_isSnoozeOver(snoozedAt)) return;
      _armed = false;
      emit(true);
      unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerShown));
    } finally {
      _checking = false;
    }
  }

  /// Retour au premier plan : réarme puis réévalue.
  Future<void> onForeground() {
    _armed = true;
    return check();
  }

  /// Le modal ne peut pas s'ouvrir (un autre écran plein recouvre le shell) :
  /// on le retire sans rien mémoriser ni mesurer, il pourra revenir.
  void skip() {
    _armed = true;
    if (state) emit(false);
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
