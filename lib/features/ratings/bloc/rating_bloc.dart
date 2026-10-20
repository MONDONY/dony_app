import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/rating_events_service.dart';
import 'package:dony/core/services/store_review_service.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_prompt_tracker.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  RatingBloc(
    this._repository,
    this._analytics, {
    RatingEventsService? ratingEvents,
    RatingPromptTracker? promptTracker,
    StoreReviewService? storeReview,
  }) : _ratingEvents = ratingEvents,
       _promptTracker = promptTracker,
       _storeReview = storeReview,
       super(const RatingInitial()) {
    on<RatingSubmitRequested>(_onSubmit);
    on<TravelerRatingSubmitRequested>(_onTravelerSubmit);
    on<PendingRatingChecked>(_onPendingChecked);
    on<UserRatingsLoadRequested>(_onUserRatingsLoad);
  }

  final RatingRepository _repository;
  final AnalyticsService _analytics;

  /// Signal global « note envoyée (bidId) » : le détail d'un colis ouvert
  /// avec sa propre instance se relit (FLUTTER-HQ).
  final RatingEventsService? _ratingEvents;

  /// Colis déjà proposés automatiquement (FLUTTER-P2). Absent : chaque
  /// vérification propose la note en attente (comportement historique).
  final RatingPromptTracker? _promptTracker;

  /// Avis sur la fiche du Store proposé après une note de 4 ou 5 étoiles.
  /// Absent : aucune fenêtre de notation du Store.
  final StoreReviewService? _storeReview;

  void _offerStoreReview(int stars, String roleRated) {
    final storeReview = _storeReview;
    if (storeReview == null) return;
    unawaited(
      storeReview.requestAfterRating(stars: stars, roleRated: roleRated),
    );
  }

  /// Échec d'un envoi de note. Un 409 `already-rated` signifie que la note
  /// existe déjà côté serveur : l'écran du colis doit se relire pour retirer
  /// le bouton « Noter », l'erreur reste affichée (« Déjà noté »).
  void _emitSubmitError(String bidId, Object e, Emitter<RatingState> emit) {
    final error = unwrapDioError(e);
    if (error is ConflictException && error.code == 'already-rated') {
      _ratingEvents?.notifyRated(bidId);
    }
    emit(RatingError(error));
  }

  Future<void> _onSubmit(
    RatingSubmitRequested event,
    Emitter<RatingState> emit,
  ) async {
    emit(const RatingLoading());
    try {
      await _repository.submitRating(
        bidId: event.bidId,
        stars: event.stars,
        comment: event.comment,
      );
      emit(const RatingSuccess());
      _ratingEvents?.notifyRated(event.bidId);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.ratingSubmitted,
          properties: {'score': event.stars, 'role_rated': 'traveler'},
        ),
      );
      _offerStoreReview(event.stars, 'traveler');
    } catch (e) {
      _emitSubmitError(event.bidId, e, emit);
    }
  }

  Future<void> _onTravelerSubmit(
    TravelerRatingSubmitRequested event,
    Emitter<RatingState> emit,
  ) async {
    emit(const RatingLoading());
    try {
      await _repository.submitTravelerRating(
        bidId: event.bidId,
        stars: event.stars,
        comment: event.comment,
      );
      emit(const RatingSuccess());
      _ratingEvents?.notifyRated(event.bidId);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.ratingSubmitted,
          properties: {'score': event.stars, 'role_rated': 'sender'},
        ),
      );
      _offerStoreReview(event.stars, 'sender');
    } catch (e) {
      _emitSubmitError(event.bidId, e, emit);
    }
  }

  Future<void> _onPendingChecked(
    PendingRatingChecked event,
    Emitter<RatingState> emit,
  ) async {
    try {
      final pending = await _repository.getPendingRating();
      // Ouverture automatique une seule fois par colis (FLUTTER-P2) : un colis
      // déjà proposé n'est plus rappelé que par sa pastille et le détail.
      final tracker = _promptTracker;
      if (pending != null &&
          (tracker == null || await tracker.claim(pending.bidId))) {
        emit(
          PendingRatingFound(
            bidId: pending.bidId,
            otherPartyName: pending.otherPartyName,
            otherPartyId: pending.otherPartyId,
            isTravelerRating: pending.isTravelerRating,
          ),
        );
      } else {
        emit(const PendingRatingNone());
      }
    } catch (_) {
      emit(const PendingRatingNone());
    }
  }

  Future<void> _onUserRatingsLoad(
    UserRatingsLoadRequested event,
    Emitter<RatingState> emit,
  ) async {
    try {
      final summary = await _repository.getUserRatings(
        event.userId,
        page: event.page,
      );
      emit(
        UserRatingsLoaded(
          averageRating: summary.averageRating,
          ratingCount: summary.ratingCount,
          distribution: summary.distribution,
          ratings: summary.ratings,
          page: summary.page,
          totalPages: summary.totalPages,
        ),
      );
    } catch (e) {
      emit(RatingError(unwrapDioError(e)));
    }
  }
}
