import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  RatingBloc(this._repository) : super(const RatingInitial()) {
    on<RatingSubmitRequested>(_onSubmit);
  }

  final RatingRepository _repository;

  Future<void> _onSubmit(
    RatingSubmitRequested event,
    Emitter<RatingState> emit,
  ) async {
    emit(const RatingLoading());
    try {
      await _repository.submitRating(
        bidId: event.bidId,
        stars: event.stars,
        comment: event.comment,
      );
      emit(const RatingSuccess());
    } catch (e) {
      final inner = e is DioException ? e.error : e;
      final message = inner is AppException
          ? inner.message
          : 'Impossible d\'envoyer l\'évaluation. Réessayez.';
      emit(RatingError(message));
    }
  }
}
