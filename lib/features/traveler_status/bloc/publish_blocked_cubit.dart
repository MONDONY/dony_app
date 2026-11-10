import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PublishBlockedState extends Equatable {
  const PublishBlockedState(this.eligibility, {this.refreshing = false});

  final PublishingEligibility eligibility;
  final bool refreshing;

  /// Plus rien ne bloque : l'écran rend la main à la publication.
  bool get canPublish => eligibility.allowed;

  @override
  List<Object?> get props => [eligibility, refreshing];
}

/// Écran de blocage d'une création de trajet (limite mensuelle atteinte).
///
/// Porte la raison affichée et la fait évoluer avec les réponses du voyageur :
/// « Particulier » transforme « statut requis » en « limite atteinte », une
/// demande GP Pro envoyée le fait passer en « en cours d'examen ».
class PublishBlockedCubit extends Cubit<PublishBlockedState> {
  PublishBlockedCubit(
    PublishingEligibility initial,
    this._repository,
    this._analytics, {
    this.source = 'gate',
  }) : super(PublishBlockedState(initial));

  final TravelerStatusRepository _repository;
  final AnalyticsService _analytics;

  /// D'où vient le blocage : `gate` (point d'entrée « Créer un trajet ») ou
  /// `publish_error` (publication refusée par le back).
  final String source;

  /// L'écran est vu : raison et origine, rien d'autre.
  void start() {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.publishBlockedShown,
        properties: {'reason': state.eligibility.reason.wire, 'source': source},
      ),
    );
  }

  /// Le voyageur vient de se déclarer particulier : sa limite est atteinte, il
  /// n'a plus qu'à attendre le mois prochain ou à devenir GP Pro.
  void individualDeclared() {
    final current = state.eligibility;
    if (current.reason != PublishingReason.statusRequired) return;
    emit(
      PublishBlockedState(
        PublishingEligibility(
          allowed: false,
          reason: PublishingReason.limitReached,
          limit: current.limit,
          used: current.used,
          resetsOn: current.resetsOn,
          travelerStatus: TravelerStatus.individual,
        ),
      ),
    );
  }

  /// Relit le droit de publier (retour du formulaire GP Pro). Une lecture qui
  /// échoue ne débloque jamais l'écran : le voyageur reste là où il est.
  Future<void> refresh() async {
    if (state.refreshing) return;
    emit(PublishBlockedState(state.eligibility, refreshing: true));
    final result = await _repository.checkEligibility();
    if (isClosed) return;
    final failure = result.failureCode;
    if (failure != null) {
      emit(PublishBlockedState(state.eligibility));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.publishEligibilityFailed,
          properties: {'error_code': failure},
        ),
      );
      return;
    }
    emit(PublishBlockedState(result.eligibility));
  }
}
