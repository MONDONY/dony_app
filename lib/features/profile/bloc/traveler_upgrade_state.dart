import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:equatable/equatable.dart';

abstract class TravelerUpgradeState extends Equatable {
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

class TravelerUpgradeError extends TravelerUpgradeState {
  final AppException error;
  const TravelerUpgradeError(this.error);
  @override
  List<Object?> get props => [error];
}
