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
  const RatingError(this.message);

  final String message;
}
