import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyReviewsBloc extends Bloc<MyReviewsEvent, MyReviewsState> {
  MyReviewsBloc(this._repository) : super(const MyReviewsInitial()) {
    on<MyReviewsRequested>(_onRequested);
    on<MyReviewsNextPageRequested>(_onNextPage);
  }

  final RatingRepository _repository;

  Future<void> _onRequested(
    MyReviewsRequested event,
    Emitter<MyReviewsState> emit,
  ) async {
    emit(const MyReviewsLoading());
    try {
      final summary = await _repository.findMineReceived();
      emit(MyReviewsLoaded(summary: summary));
    } catch (e) {
      emit(MyReviewsError(message: e.toString()));
    }
  }

  Future<void> _onNextPage(
    MyReviewsNextPageRequested event,
    Emitter<MyReviewsState> emit,
  ) async {
    // Future pagination support — no-op for MVP
  }
}
