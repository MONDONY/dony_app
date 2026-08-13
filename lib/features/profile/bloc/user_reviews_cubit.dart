import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class UserReviewsState {
  const UserReviewsState();
}

class UserReviewsInitial extends UserReviewsState {
  const UserReviewsInitial();
}

class UserReviewsLoading extends UserReviewsState {
  const UserReviewsLoading();
}

/// First page loaded (or pre-seeded from the public profile bloc).
class UserReviewsLoaded extends UserReviewsState {
  const UserReviewsLoaded({
    required this.summary,
    required this.allRatings,
    this.isLoadingMore = false,
  });

  final RatingSummary summary;

  /// Accumulated list across all loaded pages.
  final List<RatingItem> allRatings;

  /// True while the next page is being fetched.
  final bool isLoadingMore;

  UserReviewsLoaded copyWith({
    RatingSummary? summary,
    List<RatingItem>? allRatings,
    bool? isLoadingMore,
  }) => UserReviewsLoaded(
    summary: summary ?? this.summary,
    allRatings: allRatings ?? this.allRatings,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class UserReviewsError extends UserReviewsState {
  const UserReviewsError({required this.message});

  final String message;
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

class UserReviewsCubit extends Cubit<UserReviewsState> {
  UserReviewsCubit(this._repository, this._analytics)
    : super(const UserReviewsInitial());

  final RatingRepository _repository;
  final AnalyticsService _analytics;

  bool _openedEventFired = false;

  void _fireOpenedEvent(int ratingCount) {
    if (_openedEventFired) return;
    _openedEventFired = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.publicReviewsOpened,
        properties: {'rating_count': ratingCount},
      ),
    );
  }

  /// Load page 0 for [userId].  If [seed] is provided it is used immediately
  /// as the first page (so the sheet renders without a network round-trip).
  Future<void> load(String userId, {RatingSummary? seed}) async {
    if (seed != null) {
      emit(
        UserReviewsLoaded(
          summary: seed,
          allRatings: List<RatingItem>.of(seed.ratings),
        ),
      );
      _fireOpenedEvent(seed.ratingCount);
      return;
    }

    emit(const UserReviewsLoading());
    try {
      final summary = await _repository.getUserRatings(userId);
      emit(
        UserReviewsLoaded(
          summary: summary,
          allRatings: List<RatingItem>.of(summary.ratings),
        ),
      );
      _fireOpenedEvent(summary.ratingCount);
    } catch (e) {
      emit(UserReviewsError(message: e.toString()));
    }
  }

  /// Load the next page and append its items to [allRatings].
  Future<void> loadNextPage(String userId) async {
    final current = state;
    if (current is! UserReviewsLoaded) {
      return;
    }
    if (current.isLoadingMore) {
      return;
    }

    final nextPage = current.summary.page + 1;
    if (nextPage >= current.summary.totalPages) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      final next = await _repository.getUserRatings(userId, page: nextPage);
      emit(
        current.copyWith(
          summary: next,
          allRatings: [...current.allRatings, ...next.ratings],
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // On pagination error just hide the spinner; the user can scroll again.
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}
