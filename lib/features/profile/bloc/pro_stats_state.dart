part of 'pro_stats_bloc.dart';

sealed class ProStatsState {}

class ProStatsInitial extends ProStatsState {}

class ProStatsLoading extends ProStatsState {}

class ProStatsLoaded extends ProStatsState {
  final ProStatsModel stats;
  ProStatsLoaded(this.stats);
}

class ProStatsError extends ProStatsState {
  final AppException error;
  ProStatsError(this.error);
}
