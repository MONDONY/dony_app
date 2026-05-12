import 'package:dony/features/ratings/data/models/rating_summary.dart';

abstract class MyReviewsState {
  const MyReviewsState();
}

class MyReviewsInitial extends MyReviewsState {
  const MyReviewsInitial();
}

class MyReviewsLoading extends MyReviewsState {
  const MyReviewsLoading();
}

class MyReviewsLoaded extends MyReviewsState {
  const MyReviewsLoaded({required this.summary});

  final RatingSummary summary;
}

class MyReviewsError extends MyReviewsState {
  const MyReviewsError({required this.message});

  final String message;
}
