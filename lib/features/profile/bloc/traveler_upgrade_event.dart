import 'package:equatable/equatable.dart';

abstract class TravelerUpgradeEvent extends Equatable {
  const TravelerUpgradeEvent();
  @override
  List<Object?> get props => [];
}

class TravelerUpgradeActivateRequested extends TravelerUpgradeEvent {
  const TravelerUpgradeActivateRequested();
}
