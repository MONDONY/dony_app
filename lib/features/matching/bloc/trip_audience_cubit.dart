import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TripAudienceStatus { initial, loading, loaded, hidden }

class TripAudienceState extends Equatable {
  const TripAudienceState._(this.status, [this.audience]);

  const TripAudienceState.initial() : this._(TripAudienceStatus.initial);
  const TripAudienceState.loading() : this._(TripAudienceStatus.loading);
  const TripAudienceState.loaded(TripAudienceModel audience)
    : this._(TripAudienceStatus.loaded, audience);

  /// Échec réseau, ou back qui n'a pas encore la route : la carte disparaît.
  /// Jamais un faux « 0 personne » qui ferait croire que personne ne regarde.
  const TripAudienceState.hidden() : this._(TripAudienceStatus.hidden);

  final TripAudienceStatus status;
  final TripAudienceModel? audience;

  @override
  List<Object?> get props => [status, audience];
}

/// Combien de personnes ont vu un trajet, pour son voyageur.
class TripAudienceCubit extends Cubit<TripAudienceState> {
  TripAudienceCubit(this._repository, this._analytics)
    : super(const TripAudienceState.initial());

  final AnnouncementRepository _repository;
  final AnalyticsService _analytics;

  Future<void> load(String announcementId) async {
    emit(const TripAudienceState.loading());
    try {
      final audience = await _repository.getTripAudience(announcementId);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripAudienceLoaded,
          properties: {
            'unique_viewers': audience.uniqueViewerCount,
            'share_views': audience.shareViewCount,
          },
        ),
      );
      emit(TripAudienceState.loaded(audience));
    } catch (_) {
      emit(const TripAudienceState.hidden());
    }
  }
}
