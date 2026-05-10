import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  RatingBloc(this._repository) : super(const RatingInitial()) {
    on<RatingSubmitRequested>(_onSubmit);
    on<TravelerRatingSubmitRequested>(_onTravelerSubmit);
    on<PendingRatingChecked>(_onPendingChecked);
    on<UserRatingsLoadRequested>(_onUserRatingsLoad);
  }

  final RatingRepository _repository;

  Future<void> _onSubmit(RatingSubmitRequested event, Emitter<RatingState> emit) async {
    emit(const RatingLoading());
    try {
      await _repository.submitRating(bidId: event.bidId, stars: event.stars, comment: event.comment);
      emit(const RatingSuccess());
    } catch (e) {
      emit(RatingError(unwrapDioError(e)));
    }
  }

  Future<void> _onTravelerSubmit(TravelerRatingSubmitRequested event, Emitter<RatingState> emit) async {
    emit(const RatingLoading());
    try {
      await _repository.submitTravelerRating(bidId: event.bidId, stars: event.stars, comment: event.comment);
      emit(const RatingSuccess());
    } catch (e) {
      emit(RatingError(unwrapDioError(e)));
    }
  }

  Future<void> _onPendingChecked(PendingRatingChecked event, Emitter<RatingState> emit) async {
    try {
      final pending = await _repository.getPendingRating();
      if (pending != null) {
        emit(PendingRatingFound(
          bidId: pending.bidId,
          otherPartyName: pending.otherPartyName,
          otherPartyId: pending.otherPartyId,
          isTravelerRating: pending.isTravelerRating,
        ));
      } else {
        emit(const PendingRatingNone());
      }
    } catch (_) {
      emit(const PendingRatingNone());
    }
  }

  Future<void> _onUserRatingsLoad(UserRatingsLoadRequested event, Emitter<RatingState> emit) async {
    try {
      final summary = await _repository.getUserRatings(event.userId, page: event.page);
      emit(UserRatingsLoaded(
        averageRating: summary.averageRating,
        ratingCount: summary.ratingCount,
        distribution: summary.distribution,
        ratings: summary.ratings,
        page: summary.page,
        totalPages: summary.totalPages,
      ));
    } catch (e) {
      emit(RatingError(unwrapDioError(e)));
    }
  }

}
