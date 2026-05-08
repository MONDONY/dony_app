abstract class RatingEvent {
  const RatingEvent();
}

class RatingSubmitRequested extends RatingEvent {
  const RatingSubmitRequested({
    required this.bidId,
    required this.stars,
    this.comment,
  });

  final String bidId;
  final int stars;
  final String? comment;
}
