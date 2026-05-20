part of 'traveler_upgrade_bloc.dart';

sealed class TravelerUpgradeState extends Equatable {
  const TravelerUpgradeState();

  @override
  List<Object?> get props => [];
}

class TravelerUpgradeInitial extends TravelerUpgradeState {
  const TravelerUpgradeInitial();
}

class TravelerUpgradeLoading extends TravelerUpgradeState {
  const TravelerUpgradeLoading();
}

class TravelerUpgradeSuccess extends TravelerUpgradeState {
  final UserModel user;

  const TravelerUpgradeSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

class TravelerUpgradeDeactivated extends TravelerUpgradeState {
  final UserModel user;

  const TravelerUpgradeDeactivated(this.user);

  @override
  List<Object?> get props => [user];
}

class TravelerUpgradeError extends TravelerUpgradeState {
  final AppException error;

  const TravelerUpgradeError(this.error);

  @override
  List<Object?> get props => [error];
}
