part of 'favorite_traveler_bloc.dart';

abstract class FavoriteTravelerEvent {
  const FavoriteTravelerEvent();
}

class FavoriteTravelerLoaded extends FavoriteTravelerEvent {
  const FavoriteTravelerLoaded();
}

class FavoriteTravelerRemoved extends FavoriteTravelerEvent {
  const FavoriteTravelerRemoved(this.travelerId);
  final String travelerId;
}
