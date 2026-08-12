import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyReviewsBloc extends Bloc<MyReviewsEvent, MyReviewsState> {
  MyReviewsBloc(this._repository, this._analytics)
      : super(const MyReviewsInitial()) {
    on<MyReviewsRequested>(_onRequested);
    on<MyReviewsNextPageRequested>(_onNextPage);
    on<MyReviewsStarFilterToggled>(_onStarFilterToggled);
  }

  final RatingRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onRequested(
    MyReviewsRequested event,
    Emitter<MyReviewsState> emit,
  ) async {
    if (state is! MyReviewsLoaded) emit(const MyReviewsLoading());
    try {
      final summary = await _repository.findMineReceived();
      emit(MyReviewsLoaded(summary: summary));
    } catch (e) {
      emit(MyReviewsError(message: e.toString()));
    }
  }

  Future<void> _onNextPage(
    MyReviewsNextPageRequested event,
    Emitter<MyReviewsState> emit,
  ) async {
    // Future pagination support — no-op for MVP
  }

  void _onStarFilterToggled(
    MyReviewsStarFilterToggled event,
    Emitter<MyReviewsState> emit,
  ) {
    final current = state;
    if (current is! MyReviewsLoaded) return;
    // Re-tap sur la note active → on retire le filtre.
    final next =
        current.selectedStars == event.stars ? null : event.stars;
    unawaited(_analytics.logEvent(
      AnalyticsEvents.reviewsFiltered,
      properties: {'stars': next ?? 'all'},
    ));
    emit(current.copyWith(selectedStars: next));
  }
}
