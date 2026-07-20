import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:equatable/equatable.dart';

sealed class TravelerBidsEvent extends Equatable {
  const TravelerBidsEvent();

  @override
  List<Object?> get props => [];
}

/// Charge la première page. [force] ignore le TTL de fraîcheur.
class TravelerBidsRequested extends TravelerBidsEvent {
  final bool force;

  const TravelerBidsRequested({this.force = false});

  @override
  List<Object?> get props => [force];
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
