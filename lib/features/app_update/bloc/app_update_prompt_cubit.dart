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
       _lastRecommended = _service.recommendedBuild,
       super(false) {
    _changesSub = _service.configChanges.listen(
      (_) => unawaited(_onConfigChanged()),
      onError: (Object _) {},
    );
  }

  final AppUpdateService _service;
  final AppUpdateSnoozeStore _store;
  final AnalyticsService _analytics;
  final Future<void> Function() _openStore;
  final DateTime Function() _now;
  bool _armed = true;
  bool _checking = false;
  bool _reevaluate = false;
  int _lastRecommended;
  StreamSubscription<void>? _changesSub;

  /// Évalue s'il faut montrer le modal. Relit `recommended_build` déjà connu
  /// localement : aucun appel réseau.
  Future<void> check() => _evaluate();

  Future<void> _evaluate({bool ignoreSnooze = false}) async {
    if (!_armed || state) return;
    if (_checking) {
      // Une mise à jour peut arriver pendant une évaluation : la refaire.
      _reevaluate = true;
      return;
    }
    _checking = true;
    try {
      final recommended = await _service.isUpdateRecommended();
      if (isClosed || !recommended) return;
      if (!ignoreSnooze) {
        final snoozedAt = await _store.lastSnoozedAt();
        if (isClosed || state || !_isSnoozeOver(snoozedAt)) return;
      }
      if (isClosed || state) return;
      _armed = false;
      emit(true);
      unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerShown));
    } finally {
      _checking = false;
      if (_reevaluate && !isClosed) {
        _reevaluate = false;
        unawaited(_onConfigChanged());
      }
    }
  }

  /// Mise à jour temps réel de Remote Config (clé changée dans l'admin) :
  /// - plus de mise à jour à proposer (valeur baissée, build à jour) : le modal
  ///   se retire ;
  /// - `recommended_build` a monté : nouvelle version à proposer, on réarme et
  ///   on ignore le « Plus tard » (il portait sur une version plus ancienne) ;
  /// - sinon, évaluation habituelle (une fois par lancement et par valeur).
  Future<void> _onConfigChanged() async {
    if (isClosed) return;
    final previous = _lastRecommended;
    final current = _service.recommendedBuild;
    _lastRecommended = current;
    if (_checking) {
      _reevaluate = true;
      return;
    }
    final recommended = await _service.isUpdateRecommended();
    if (isClosed) return;
    if (!recommended) {
      _armed = true;
      if (state) emit(false);
      return;
    }
    if (current > previous) {
      _armed = true;
      await _evaluate(ignoreSnooze: true);
    } else {
      await _evaluate();
    }
  }

  /// Retour au premier plan : réarme puis réévalue.
  Future<void> onForeground() {
    _armed = true;
    return check();
  }

  @override
  Future<void> close() async {
    await _changesSub?.cancel();
    return super.close();
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
