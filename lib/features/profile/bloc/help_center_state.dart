part of 'help_center_bloc.dart';

sealed class HelpCenterState extends Equatable {
  const HelpCenterState();
}

final class HelpCenterInitial extends HelpCenterState {
  const HelpCenterInitial();

  @override
  List<Object?> get props => const [];
}

final class HelpCenterLoading extends HelpCenterState {
  const HelpCenterLoading();

  @override
  List<Object?> get props => const [];
}

final class HelpCenterSuccess extends HelpCenterState {
  const HelpCenterSuccess(this.config, {this.isRefreshing = false});

  final HelpCenterConfig config;
  final bool isRefreshing;

  @override
  List<Object?> get props => [config, isRefreshing];
}

final class HelpCenterError extends HelpCenterState {
  const HelpCenterError(this.reason, {required this.config});

  final String reason;
  final HelpCenterConfig config;

  @override
  List<Object?> get props => [reason, config];
}
