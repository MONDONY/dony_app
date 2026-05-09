abstract class RatingEvent {
  const RatingEvent();
}

class RatingSubmitRequested extends RatingEvent {
  const RatingSubmitRequested({required this.bidId, required this.stars, this.comment});
  final String bidId;
  final int stars;
  final String? comment;
}

class TravelerRatingSubmitRequested extends RatingEvent {
  const TravelerRatingSubmitRequested({required this.bidId, required this.stars, this.comment});
  final String bidId;
  final int stars;
  final String? comment;
}

class PendingRatingChecked extends RatingEvent {
  const PendingRatingChecked();
}

class UserRatingsLoadRequested extends RatingEvent {
  const UserRatingsLoadRequested({required this.userId, this.page = 0});
  final String userId;
  final int page;
}
