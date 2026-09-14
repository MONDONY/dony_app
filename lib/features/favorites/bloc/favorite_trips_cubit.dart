import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

sealed class FavoriteTripsState {}

class FavoriteTripsLoading extends FavoriteTripsState {}

class FavoriteTripsLoaded extends FavoriteTripsState {
  FavoriteTripsLoaded(this.trips);
  final List<AnnouncementModel> trips;
}

class FavoriteTripsEmpty extends FavoriteTripsState {}

class FavoriteTripsError extends FavoriteTripsState {
  FavoriteTripsError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class FavoriteTripsCubit extends Cubit<FavoriteTripsState> {
  FavoriteTripsCubit(this._repo) : super(FavoriteTripsLoading());

  final FavoriteRepository _repo;

  Future<void> load() async {
    emit(FavoriteTripsLoading());
    final List<AnnouncementModel> trips;
    try {
      trips = await _repo.trips();
    } catch (e) {
      // L'écran Favoris est souvent quitté avant la réponse : émettre sur un
      // cubit fermé lève un StateError (Sentry FLUTTER-1G / FLUTTER-1F).
      if (isClosed) return;
      emit(FavoriteTripsError(e.toString()));
      return;
    }
    if (isClosed) return;
    if (trips.isEmpty) {
      emit(FavoriteTripsEmpty());
    } else {
      emit(FavoriteTripsLoaded(trips));
    }
  }

  Future<void> refresh() => load();
}
