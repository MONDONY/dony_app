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
  MoneyOverviewLoaded(
    this.overview, {
    this.upcomingAvailable = true,
    DateTime? now,
  }) : schedule = buildMoneySchedule(overview, now: now ?? DateTime.now());

  final MoneyOverviewModel overview;

  /// `false` sur un back antérieur à yadony-back #481 : l'écran annonce une
  /// arrivée prochaine du suivi au lieu d'un écran cassé.
  final bool upcomingAvailable;

  /// Échéancier calculé une fois au chargement (groupes, tuiles, trajets).
  final MoneySchedule schedule;
}

final class MoneyOverviewError extends MoneyOverviewState {
  const MoneyOverviewError(this.error);

  final AppException error;
}
