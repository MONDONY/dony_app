part of 'upgrade_to_pro_bloc.dart';

sealed class UpgradeToProState extends Equatable {
  const UpgradeToProState();

  @override
  List<Object?> get props => [];
}

class UpgradeToProInitial extends UpgradeToProState {}

class UpgradeToProLoading extends UpgradeToProState {}

class DowngradeSuccess extends UpgradeToProState {}

class DowngradeError extends UpgradeToProState {
  final AppException error;

  const DowngradeError(this.error);

  @override
  List<Object?> get props => [error];
}
