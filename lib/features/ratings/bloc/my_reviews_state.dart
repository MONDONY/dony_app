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
  const MyReviewsLoaded({required this.summary, this.selectedStars});

  final RatingSummary summary;

  /// Note (1–5) sélectionnée pour filtrer la liste. `null` = toutes les notes.
  final int? selectedStars;

  /// Avis affichés après application du filtre étoile courant.
  List<RatingItem> get visibleRatings => selectedStars == null
      ? summary.ratings
      : summary.ratings.where((r) => r.stars == selectedStars).toList();

  MyReviewsLoaded copyWith({RatingSummary? summary, int? selectedStars}) =>
      MyReviewsLoaded(
        summary: summary ?? this.summary,
        selectedStars: selectedStars,
      );
}

class MyReviewsError extends MyReviewsState {
  const MyReviewsError({required this.message});

  final String message;
}
