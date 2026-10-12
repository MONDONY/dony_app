import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/data/trip_space_alert_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TripSpaceAlertStatus {
  /// Abonnement pas encore lu.
  unknown,
  notSubscribed,
  subscribed,

  /// Le trajet n'est plus complet (409 `trip-not-full`) : la demande se fait
  /// directement, il n'y a plus rien à attendre.
  spaceAvailable,
}

/// Pied de la feuille d'un trajet complet (FLUTTER-JH).
class TripSpaceAlertState extends Equatable {
  const TripSpaceAlertState({
    this.status = TripSpaceAlertStatus.unknown,
    this.isSubmitting = false,
    this.failed = false,
  });

  final TripSpaceAlertStatus status;

  /// Abonnement ou désabonnement en cours : le bouton attend.
  final bool isSubmitting;

  /// La dernière action a échoué : la vue affiche un message, l'état reste.
  final bool failed;

  bool get isSubscribed => status == TripSpaceAlertStatus.subscribed;

  TripSpaceAlertState copyWith({
    TripSpaceAlertStatus? status,
    bool? isSubmitting,
    bool? failed,
  }) => TripSpaceAlertState(
    status: status ?? this.status,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failed: failed ?? false,
  );

  @override
  List<Object?> get props => [status, isSubmitting, failed];
}

class TripSpaceAlertCubit extends Cubit<TripSpaceAlertState> {
  TripSpaceAlertCubit(
    this._repository,
    this._analytics, {
    required this.announcementId,
  }) : super(const TripSpaceAlertState());

  final TripSpaceAlertRepository _repository;
  final AnalyticsService _analytics;
  final String announcementId;

  /// Lit l'abonnement. Un échec (réseau, back antérieur sans l'endpoint)
  /// retombe sur « pas abonné » : le bouton reste proposé.
  Future<void> load() async {
    try {
      final ids = await _repository.getSubscribedTripIds();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ids.contains(announcementId)
              ? TripSpaceAlertStatus.subscribed
              : TripSpaceAlertStatus.notSubscribed,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(status: TripSpaceAlertStatus.notSubscribed));
    }
  }

  Future<void> subscribe() async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.subscribe(announcementId);
      unawaited(_analytics.logEvent(AnalyticsEvents.tripSpaceAlertSubscribed));
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripSpaceAlertStatus.subscribed,
          isSubmitting: false,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      if (error.code == 'trip-not-full') {
        emit(
          state.copyWith(
            status: TripSpaceAlertStatus.spaceAvailable,
            isSubmitting: false,
          ),
        );
        return;
      }
      emit(state.copyWith(isSubmitting: false, failed: true));
    }
  }

  Future<void> unsubscribe() async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.unsubscribe(announcementId);
      unawaited(
        _analytics.logEvent(AnalyticsEvents.tripSpaceAlertUnsubscribed),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripSpaceAlertStatus.notSubscribed,
          isSubmitting: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(isSubmitting: false, failed: true));
    }
  }
}
