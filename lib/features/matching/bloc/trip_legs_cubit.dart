import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TripLegsState extends Equatable {
  const TripLegsState({this.legs = const []});

  /// Étapes ajoutées après le premier trajet, dans l'ordre du voyage.
  final List<TripLegDraft> legs;

  /// Une étape de plus est-elle encore possible (première comprise) ?
  bool get canAdd => legs.length + 1 < TripLegChain.maxLegs;

  @override
  List<Object?> get props => [legs];
}

/// Étapes supplémentaires du formulaire de publication (FLUTTER-4D).
///
/// Retirer une étape retire aussi les suivantes : chacune part de la ville
/// d'arrivée de la précédente, une étape orpheline n'aurait plus de départ.
class TripLegsCubit extends Cubit<TripLegsState> {
  TripLegsCubit(this._analytics) : super(const TripLegsState());

  final AnalyticsService _analytics;

  void add(TripLegDraft leg) {
    if (!state.canAdd) return;
    final legs = [...state.legs, leg];
    emit(TripLegsState(legs: legs));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripLegAdded,
        properties: {'leg_count': legs.length + 1},
      ),
    );
  }

  void replace(int index, TripLegDraft leg) {
    if (index < 0 || index >= state.legs.length) return;
    final legs = [...state.legs]..[index] = leg;
    emit(TripLegsState(legs: legs));
  }

  void removeFrom(int index) {
    if (index < 0 || index >= state.legs.length) return;
    emit(TripLegsState(legs: state.legs.sublist(0, index)));
  }
}
