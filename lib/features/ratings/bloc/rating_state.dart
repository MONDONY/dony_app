import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';

abstract class RatingState {
  const RatingState();
}

class RatingInitial extends RatingState {
  const RatingInitial();
}

class RatingLoading extends RatingState {
  const RatingLoading();
}

class RatingSuccess extends RatingState {
  const RatingSuccess();
}

class RatingError extends RatingState {
  const RatingError(this.error);
  final AppException error;
}

class PendingRatingFound extends RatingState {
  const PendingRatingFound({
    required this.bidId,
    required this.otherPartyName,
    required this.otherPartyId,
    required this.isTravelerRating,
  });
  final String bidId;
  final String otherPartyName;
  final String otherPartyId;
  final bool isTravelerRating;
}

class PendingRatingNone extends RatingState {
  const PendingRatingNone();
}

class UserRatingsLoaded extends RatingState {
  const UserRatingsLoaded({
    required this.averageRating,
    required this.ratingCount,
    required this.distribution,
    required this.ratings,
    required this.page,
    required this.totalPages,
  });
  final double averageRating;
  final int ratingCount;
  final Map<int, int> distribution;
  final List<RatingItem> ratings;
  final int page;
  final int totalPages;
}
