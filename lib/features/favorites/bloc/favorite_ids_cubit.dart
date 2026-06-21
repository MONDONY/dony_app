import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class FavoriteIdsState {
  final Set<String> tripIds;
  final Set<String> requestIds;

  const FavoriteIdsState(this.tripIds, this.requestIds);

  int get count => tripIds.length + requestIds.length;

  FavoriteIdsState copyWith({
    Set<String>? tripIds,
    Set<String>? requestIds,
  }) =>
      FavoriteIdsState(
        tripIds ?? this.tripIds,
        requestIds ?? this.requestIds,
      );
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class FavoriteIdsCubit extends Cubit<FavoriteIdsState> {
  final FavoriteRepository _repo;

  FavoriteIdsCubit(this._repo)
      : super(const FavoriteIdsState({}, {}));

  // ---- Queries -------------------------------------------------------

  bool isTripFav(String id) => state.tripIds.contains(id);
  bool isRequestFav(String id) => state.requestIds.contains(id);
  int get count => state.count;

  // ---- Load ----------------------------------------------------------

  /// Fetches the current user's favorite IDs from the backend.
  /// Silently ignores errors (keeps current state).
  Future<void> load() async {
    try {
      final ids = await _repo.ids();
      emit(FavoriteIdsState(ids.trips, ids.packageRequests));
    } catch (_) {
      // keep current state — don't crash the app on network failure
    }
  }

  // ---- Toggle --------------------------------------------------------

  /// Optimistically toggles a trip favorite.
  /// Rolls back and rethrows on backend error so the UI can show a snackbar.
  Future<void> toggleTrip(String id) => _toggle(
        id,
        () => state.tripIds,
        (s) => state.copyWith(tripIds: s),
        'trip',
      );

  /// Optimistically toggles a package-request favorite.
  /// Rolls back and rethrows on backend error so the UI can show a snackbar.
  Future<void> toggleRequest(String id) => _toggle(
        id,
        () => state.requestIds,
        (s) => state.copyWith(requestIds: s),
        'package-request',
      );

  // ---- Private helpers -----------------------------------------------

  Future<void> _toggle(
    String id,
    Set<String> Function() getCurrent,
    FavoriteIdsState Function(Set<String>) buildState,
    String type,
  ) async {
    final current = getCurrent();
    final adding = !current.contains(id);

    // Optimistic emit
    final optimistic = Set<String>.from(current);
    adding ? optimistic.add(id) : optimistic.remove(id);
    emit(buildState(optimistic));

    try {
      if (adding) {
        await _repo.add(type, id);
      } else {
        await _repo.remove(type, id);
      }
    } catch (_) {
      // Rollback
      emit(buildState(current));
      rethrow;
    }
  }

  // ---- Test helper ---------------------------------------------------

  /// Seeds the cubit with known IDs without hitting the network.
  /// Use only in tests.
  @visibleForTesting
  void emitSeed({
    required Set<String> trips,
    required Set<String> requests,
  }) {
    emit(FavoriteIdsState(Set<String>.from(trips), Set<String>.from(requests)));
  }
}
