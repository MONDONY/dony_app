part of 'traveler_upgrade_bloc.dart';

sealed class TravelerUpgradeEvent extends Equatable {
  const TravelerUpgradeEvent();

  @override
  List<Object?> get props => [];
}

class TravelerUpgradeActivateRequested extends TravelerUpgradeEvent {
  const TravelerUpgradeActivateRequested();
}
