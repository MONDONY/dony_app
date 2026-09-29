import 'dart:async';

import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:equatable/equatable.dart';

sealed class TravelerBidsEvent extends Equatable {
  const TravelerBidsEvent();

  @override
  List<Object?> get props => [];
}

/// Charge la première page. [force] ignore le TTL de fraîcheur.
///
/// [done] se termine quand ce chargement a abouti : avec `null` en cas de
/// succès, l'erreur sinon. Sert au pull-to-refresh, qui doit attendre la
/// réponse et signaler un échec (un refresh raté laisse la liste intacte, donc
/// aucun changement d'état visible). Un chargement doublé par un plus récent
/// se termine avec `null` sans rien émettre.
class TravelerBidsRequested extends TravelerBidsEvent {
  final bool force;
  final Completer<Object?>? done;

  const TravelerBidsRequested({this.force = false, this.done});

  @override
  List<Object?> get props => [force, done];
}

/// Charge la page suivante et l'ajoute à la liste courante.
class TravelerBidsNextPageRequested extends TravelerBidsEvent {
  const TravelerBidsNextPageRequested();
}

/// Change le filtre de vue. Recharge depuis la première page.
class TravelerBidsFilterChanged extends TravelerBidsEvent {
  final TravelerBidFilter filter;

  const TravelerBidsFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}
