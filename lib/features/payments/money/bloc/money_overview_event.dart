part of 'money_overview_bloc.dart';

sealed class MoneyOverviewEvent {
  const MoneyOverviewEvent();
}

/// Premier chargement (affiche le chargement).
final class MoneyOverviewLoadRequested extends MoneyOverviewEvent {
  const MoneyOverviewLoadRequested();
}

/// Pull-to-refresh ou retour d'un écran fils : garde l'affichage courant.
///
/// [completer] se termine quand la requête aboutit ou échoue : c'est lui que
/// le pull-to-refresh attend (un rafraîchissement raté n'émet aucun état).
final class MoneyOverviewRefreshRequested extends MoneyOverviewEvent {
  const MoneyOverviewRefreshRequested({this.completer});

  final Completer<void>? completer;
}
