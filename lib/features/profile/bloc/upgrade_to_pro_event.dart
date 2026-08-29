part of 'upgrade_to_pro_bloc.dart';

sealed class UpgradeToProEvent extends Equatable {
  const UpgradeToProEvent();

  @override
  List<Object?> get props => [];
}

class DowngradeRequested extends UpgradeToProEvent {
  const DowngradeRequested();
}
