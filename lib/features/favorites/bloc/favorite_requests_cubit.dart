import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

sealed class FavoriteRequestsState {}

class FavoriteRequestsLoading extends FavoriteRequestsState {}

class FavoriteRequestsLoaded extends FavoriteRequestsState {
  FavoriteRequestsLoaded(this.requests);
  final List<PackageRequestSearchItem> requests;
}

class FavoriteRequestsEmpty extends FavoriteRequestsState {}

class FavoriteRequestsError extends FavoriteRequestsState {
  FavoriteRequestsError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class FavoriteRequestsCubit extends Cubit<FavoriteRequestsState> {
  FavoriteRequestsCubit(this._repo) : super(FavoriteRequestsLoading());

  final FavoriteRepository _repo;

  Future<void> load() async {
    emit(FavoriteRequestsLoading());
    try {
      final requests = await _repo.packageRequests();
      if (requests.isEmpty) {
        emit(FavoriteRequestsEmpty());
      } else {
        emit(FavoriteRequestsLoaded(requests));
      }
    } catch (e) {
      emit(FavoriteRequestsError(e.toString()));
    }
  }

  Future<void> refresh() => load();
}
