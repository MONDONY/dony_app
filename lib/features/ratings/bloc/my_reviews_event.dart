abstract class MyReviewsEvent {
  const MyReviewsEvent();
}

class MyReviewsRequested extends MyReviewsEvent {
  const MyReviewsRequested();
}

class MyReviewsNextPageRequested extends MyReviewsEvent {
  const MyReviewsNextPageRequested();
}

/// Tap sur une ligne de distribution (n★). Bascule le filtre :
/// re-tap sur la même note → filtre annulé (toutes les notes).
class MyReviewsStarFilterToggled extends MyReviewsEvent {
  const MyReviewsStarFilterToggled(this.stars);

  final int stars;
}
