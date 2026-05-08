part of 'upgrade_to_pro_bloc.dart';

sealed class UpgradeToProState extends Equatable {
  const UpgradeToProState();

  @override
  List<Object?> get props => [];
}

class UpgradeToProInitial extends UpgradeToProState {}

class UpgradeToProLoading extends UpgradeToProState {}

class UpgradeToProSuccess extends UpgradeToProState {}

class UpgradeToProError extends UpgradeToProState {
  final String message;

  const UpgradeToProError(this.message);

  @override
  List<Object?> get props => [message];
}

class DowngradeSuccess extends UpgradeToProState {}

class DowngradeError extends UpgradeToProState {
  final String message;

  const DowngradeError(this.message);

  @override
  List<Object?> get props => [message];
}
