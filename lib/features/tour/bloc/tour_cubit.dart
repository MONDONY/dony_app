import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tour/data/tour_progress_store.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Les bulles d'explication, dans l'ordre de la maquette.
///
/// Les quatre premières forment le tour, posé d'affilée. Les trois suivantes
/// attendent leur moment : [urgent] et [favorites] qu'on touche un filtre ou
/// qu'on aime un trajet, [support] quelques jours après l'arrivée. La huitième
/// bulle de la maquette est celle de l'assistant, qui n'est pas ici.
///
/// Le nom de chaque valeur part dans `tour_step_*` (`step`) : ne pas le
/// renommer sans mapper l'historique PostHog.
enum TourStep {
  plus,
  modeTrips,
  modeParcels,
  activities,
  urgent,
  favorites,
  support;

  /// Bulles du tour, posées d'affilée.
  static const sequential = [plus, modeTrips, modeParcels, activities];

  /// Bulles qui attendent leur moment.
  static const contextual = [urgent, favorites, support];

  bool get isContextual => contextual.contains(this);
}

/// Rang de l'assistant dans la suite de la maquette : il passe en dernier, après
/// les sept bulles ci-dessus. Sert au compteur « N sur 8 ».
const kTourTotalSteps = 8;

/// Délai après la fin du tour avant la bulle du support.
const kTourSupportDelay = Duration(days: 3);

/// Délai après lequel l'assistant n'attend plus les bulles qui ne se sont pas
/// déclenchées (filtre jamais touché, trajet jamais aimé).
const kTourAssistantDelay = Duration(days: 7);

class TourState extends Equatable {
  const TourState({
    this.step,
    this.loaded = false,
    this.assistantReady = false,
  });

  /// Bulle à montrer maintenant, `null` quand il n'y en a aucune.
  final TourStep? step;

  /// Le stockage a été lu pour le compte courant.
  final bool loaded;

  /// L'assistant peut se manifester : le tour est fini et les autres bulles
  /// sont vues, ou le délai prévu est écoulé.
  final bool assistantReady;

  /// Alias lu par la bulle de l'assistant.
  bool get finished => loaded && assistantReady;

  @override
  List<Object?> get props => [step, loaded, assistantReady];
}

/// Avancée des bulles d'explication de l'app. Une seule instance (le shell et
/// la bulle de l'assistant la lisent), relue à chaque changement de compte.
class TourCubit extends Cubit<TourState> {
  TourCubit(this._store, this._analytics, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const TourState());

  final TourProgressStore _store;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  String? _uid;
  int _seen = 0;
  DateTime? _doneAt;
  String? _lastContextualDay;
  final Set<TourStep> _triggered = {};
  TourStep? _lastShown;

  /// Bulle « au moment utile » affichée en ce moment : elle reste jusqu'à ce
  /// qu'on la ferme, même si le jour change ou qu'une autre devient éligible.
  TourStep? _activeContextual;

  bool _isSeen(TourStep s) => _seen & (1 << s.index) != 0;
  bool get _sequentialDone => TourStep.sequential.every(_isSeen);

  String _today() {
    final n = _now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Relit l'avancée du compte [uid]. Sans compte, rien ne s'affiche.
  void sync(String? uid) {
    if (uid == _uid && state.loaded) return;
    _uid = uid;
    _triggered.clear();
    _lastShown = null;
    _activeContextual = null;
    if (uid == null || uid.isEmpty) {
      _seen = 0;
      _doneAt = null;
      _lastContextualDay = null;
      emit(const TourState());
      return;
    }
    _seen = _store.readSeen(uid);
    _doneAt = _store.readDoneAt(uid);
    _lastContextualDay = _store.readLastContextualDay(uid);
    if (_sequentialDone && _doneAt == null) {
      _doneAt = _now();
      unawaited(_store.writeDoneAt(uid, _doneAt!));
    }
    _recompute();
  }

  /// Une bulle « au moment utile » devient possible (filtre touché, trajet
  /// aimé). Sans effet si elle a déjà été vue ou si le tour n'a pas été lu.
  void trigger(TourStep step) {
    if (!step.isContextual || !state.loaded || _isSeen(step)) return;
    if (_triggered.add(step)) _recompute();
  }

  /// Le bouton expliqué par [step] vient d'être utilisé : inutile de
  /// l'expliquer.
  Future<void> markSeen(TourStep step) async {
    if (!state.loaded || _isSeen(step)) return;
    await _markSeen(step);
    _recompute();
  }

  bool _contextualEligible(TourStep step) => switch (step) {
    TourStep.support =>
      _doneAt != null && !_now().isBefore(_doneAt!.add(kTourSupportDelay)),
    _ => _triggered.contains(step),
  };

  bool _assistantReady() {
    if (!_sequentialDone) return false;
    if (TourStep.contextual.every(_isSeen)) return true;
    final done = _doneAt;
    return done != null && !_now().isBefore(done.add(kTourAssistantDelay));
  }

  void _recompute() {
    TourStep? step;
    for (final s in TourStep.sequential) {
      if (!_isSeen(s)) {
        step = s;
        break;
      }
    }
    if (step == null) {
      final active = _activeContextual;
      if (active != null && !_isSeen(active)) {
        step = active;
      } else if (_lastContextualDay != _today()) {
        // Une seule bulle « au moment utile » par jour.
        for (final s in TourStep.contextual) {
          if (!_isSeen(s) && _contextualEligible(s)) {
            step = s;
            break;
          }
        }
      }
    }
    emit(
      TourState(step: step, loaded: true, assistantReady: _assistantReady()),
    );
  }

  /// La bulle vient d'apparaître. Une fois par bulle et par instance.
  void shown() {
    final step = state.step;
    if (step == null || step == _lastShown) return;
    _lastShown = step;
    final uid = _uid;
    if (step.isContextual && uid != null) {
      _activeContextual = step;
      _lastContextualDay = _today();
      unawaited(_store.writeLastContextualDay(uid, _lastContextualDay!));
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tourStepShown,
        properties: {'step': step.name, 'position': step.index + 1},
      ),
    );
  }

  Future<void> _markSeen(TourStep step) async {
    final uid = _uid;
    if (uid == null) return;
    _seen |= 1 << step.index;
    if (_activeContextual == step) _activeContextual = null;
    await _store.writeSeen(uid, _seen);
    if (_sequentialDone && _doneAt == null) {
      _doneAt = _now();
      await _store.writeDoneAt(uid, _doneAt!);
    }
  }

  /// « Suivant », « Terminer » ou « Compris » selon la bulle.
  Future<void> next() async {
    final step = state.step;
    if (step == null || _uid == null) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tourStepNext,
        properties: {'step': step.name},
      ),
    );
    final wasDone = _sequentialDone;
    await _markSeen(step);
    if (!wasDone && _sequentialDone) {
      unawaited(_analytics.logEvent(AnalyticsEvents.tourCompleted));
    }
    _recompute();
  }

  /// « Passer le tour » : les bulles du tour qui restent sont écartées. Sur une
  /// bulle « au moment utile », se comporte comme « Compris ».
  Future<void> skip() async {
    final step = state.step;
    final uid = _uid;
    if (step == null || uid == null) return;
    if (step.isContextual) {
      await next();
      return;
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tourSkipped,
        properties: {'step': step.name, 'position': step.index + 1},
      ),
    );
    for (final s in TourStep.sequential) {
      _seen |= 1 << s.index;
    }
    await _store.writeSeen(uid, _seen);
    if (_doneAt == null) {
      _doneAt = _now();
      await _store.writeDoneAt(uid, _doneAt!);
    }
    _recompute();
  }
}
