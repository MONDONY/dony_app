part of 'favorite_traveler_bloc.dart';

enum FavoriteTravelerStatus { initial, loading, success, error }

class FavoriteTravelerState {
  const FavoriteTravelerState({
    this.status = FavoriteTravelerStatus.initial,
    this.travelers = const [],
    this.error,
  });

  final FavoriteTravelerStatus status;
  final List<FavoriteTraveler> travelers;
  final String? error;

  FavoriteTravelerState copyWith({
    FavoriteTravelerStatus? status,
    List<FavoriteTraveler>? travelers,
    String? error,
  }) =>
      FavoriteTravelerState(
        status: status ?? this.status,
        travelers: travelers ?? this.travelers,
        error: error,
      );
}
