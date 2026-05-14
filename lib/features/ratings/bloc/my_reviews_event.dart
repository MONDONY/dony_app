abstract class MyReviewsEvent {
  const MyReviewsEvent();
}

class MyReviewsRequested extends MyReviewsEvent {
  const MyReviewsRequested();
}

class MyReviewsNextPageRequested extends MyReviewsEvent {
  const MyReviewsNextPageRequested();
}
