part of 'money_overview_bloc.dart';

sealed class MoneyOverviewState {
  const MoneyOverviewState();
}

final class MoneyOverviewInitial extends MoneyOverviewState {
  const MoneyOverviewInitial();
}

final class MoneyOverviewLoading extends MoneyOverviewState {
  const MoneyOverviewLoading();
}

final class MoneyOverviewLoaded extends MoneyOverviewState {
  const MoneyOverviewLoaded(this.overview, {this.upcomingAvailable = true});

  final MoneyOverviewModel overview;

  /// `false` sur un back antérieur à yadony-back #481 : seuls les soldes du
  /// portefeuille sont connus, la section « Quand mon argent arrive »
  /// annonce une arrivée prochaine au lieu d'un écran cassé.
  final bool upcomingAvailable;
}

final class MoneyOverviewError extends MoneyOverviewState {
  const MoneyOverviewError(this.error);

  final AppException error;
}
