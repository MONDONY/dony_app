import 'dart:async';

import 'package:dony/core/network/maintenance_signal.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/maintenance/bloc/maintenance_state.dart';
import 'package:dony/features/maintenance/data/repositories/maintenance_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mode maintenance piloté depuis le back-office.
///
/// Trois entrées font apparaître l'écran, la plus rapide gagne :
/// - le document Firestore `config/maintenance` ([MaintenanceRepository.watchEnabled]),
///   en une ou deux secondes, même si l'utilisateur ne touche à rien ;
/// - le 503 `maintenance` de n'importe quelle requête ([MaintenanceSignal]) ;
/// - une relecture de `GET /config/maintenance` ([check]) : au démarrage, au
///   retour au premier plan, puis toutes les [pollInterval] tant que l'écran
///   est affiché, pour le refermer seul à la réouverture.
///
/// `GET /config/maintenance` fait foi : un compte exempté (testeur) n'est
/// jamais bloqué, même quand Firestore annonce la maintenance. Une lecture qui
/// échoue garde l'état courant : un réseau coupé ne ferme ni n'ouvre l'écran.
class MaintenanceCubit extends Cubit<MaintenanceState> {
  MaintenanceCubit(
    this._repository,
    this._signal,
    this._analytics, {
    this.pollInterval = const Duration(seconds: 30),
  }) : super(const MaintenanceState());

  final MaintenanceRepository _repository;
  final MaintenanceSignal _signal;
  final AnalyticsService _analytics;
  final Duration pollInterval;

  StreamSubscription<bool>? _liveSub;
  StreamSubscription<MaintenanceNotice>? _signalSub;
  Timer? _pollTimer;
  DateTime? _shownAt;
  Future<void>? _inFlight;

  /// Branche les trois sources. Idempotent.
  void start() {
    _signalSub ??= _signal.notices.listen(_onNotice);
    _liveSub ??= _repository.watchEnabled().listen(
      (_) => unawaited(check()),
      // Firestore indisponible : le 503 et les relectures prennent le relais.
      onError: (Object _) {},
    );
    unawaited(check());
  }

  /// Relit l'état faisant foi. Deux appels simultanés partagent la requête.
  Future<void> check() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    try {
      final status = await _repository.fetchStatus();
      if (isClosed) return;
      if (status.blocksApp) {
        _show(status.message, status.estimatedEndAt, source: 'status');
      } else {
        _hide();
      }
    } catch (_) {
      // Hors ligne ou back injoignable : l'état courant reste.
    }
  }

  /// « Réessayer » sur l'écran de maintenance.
  Future<void> retry() async {
    unawaited(_analytics.logEvent(AnalyticsEvents.maintenanceRetryTapped));
    emit(state.copyWith(checking: true));
    await check();
    if (!isClosed) emit(state.copyWith(checking: false));
  }

  void _onNotice(MaintenanceNotice notice) {
    // Le message du 503 vaut le texte par défaut du SERVEUR quand l'admin
    // n'en a pas écrit : la relecture le remplace par celui de l'app.
    _show(notice.message, notice.estimatedEndAt, source: 'api');
    unawaited(check());
  }

  void _show(
    String? message,
    DateTime? estimatedEndAt, {
    required String source,
  }) {
    if (!state.active) {
      _shownAt = DateTime.now();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.maintenanceScreenShown,
          properties: {'source': source},
        ),
      );
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(check()));
    emit(
      MaintenanceState(
        active: true,
        message: message,
        estimatedEndAt: estimatedEndAt,
        checking: state.checking,
      ),
    );
  }

  void _hide() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!state.active) return;
    final shownAt = _shownAt;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.maintenanceEnded,
        properties: {
          'duration_s': shownAt == null
              ? 0
              : DateTime.now().difference(shownAt).inSeconds,
        },
      ),
    );
    _shownAt = null;
    emit(MaintenanceState(checking: state.checking));
  }

  @override
  Future<void> close() async {
    _pollTimer?.cancel();
    await _liveSub?.cancel();
    await _signalSub?.cancel();
    return super.close();
  }
}
