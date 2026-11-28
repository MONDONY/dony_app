import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tour/data/tour_progress_store.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Les bulles du petit tour, dans l'ordre où elles s'affichent.
///
/// Le nom de chaque valeur part dans `tour_step_*` (`step`) : ne pas le
/// renommer sans mapper l'historique PostHog.
enum TourStep { plus, modeTrips, modeParcels, activities }

class TourState extends Equatable {
  const TourState({this.step, this.loaded = false});

  /// Prochaine bulle à montrer, `null` quand le tour est fini ou pas encore lu.
  final TourStep? step;

  /// Le stockage a été lu pour le compte courant.
  final bool loaded;

  /// Tour terminé ou passé pour ce compte. Faux tant que rien n'est lu : la
  /// bulle de l'assistant attend aussi cette lecture avant de se montrer.
  bool get finished => loaded && step == null;

  @override
  List<Object?> get props => [step, loaded];
}

/// Avancée du petit tour de l'écran Rechercher : le +, les deux onglets,
/// Activités. Une seule instance pour l'app (le shell et la bulle de
/// l'assistant la lisent), relue à chaque changement de compte.
class TourCubit extends Cubit<TourState> {
  TourCubit(this._store, this._analytics) : super(const TourState());

  final TourProgressStore _store;
  final AnalyticsService _analytics;

  String? _uid;
  TourStep? _lastShown;

  /// Relit l'avancée du compte [uid]. Sans compte, le tour n'a pas lieu.
  void sync(String? uid) {
    if (uid == _uid && state.loaded) return;
    _uid = uid;
    _lastShown = null;
    if (uid == null || uid.isEmpty) {
      emit(const TourState());
      return;
    }
    emit(TourState(step: _stepAt(_store.read(uid)), loaded: true));
  }

  static TourStep? _stepAt(int index) =>
      index >= 0 && index < TourStep.values.length
      ? TourStep.values[index]
      : null;

  /// La bulle vient d'apparaître. Une fois par bulle et par instance.
  void shown() {
    final step = state.step;
    if (step == null || step == _lastShown) return;
    _lastShown = step;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tourStepShown,
        properties: {'step': step.name, 'position': step.index + 1},
      ),
    );
  }

  /// « Suivant » (ou « Terminer » sur la dernière bulle).
  Future<void> next() async {
    final step = state.step;
    final uid = _uid;
    if (step == null || uid == null) return;
    final nextIndex = step.index + 1;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tourStepNext,
        properties: {'step': step.name},
      ),
    );
    final following = _stepAt(nextIndex);
    emit(TourState(step: following, loaded: true));
    if (following == null) {
      unawaited(_analytics.logEvent(AnalyticsEvents.tourCompleted));
    }
    await _store.write(uid, nextIndex);
  }

  /// « Passer le tour » : toutes les bulles restantes sont écartées.
  Future<void> skip() async {
    final step = state.step;
    final uid = _uid;
    if (step == null || uid == null) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tourSkipped,
        properties: {'step': step.name, 'position': step.index + 1},
      ),
    );
    emit(const TourState(loaded: true));
    await _store.write(uid, TourStep.values.length);
  }
}
