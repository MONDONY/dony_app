import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:flutter/widgets.dart';

/// Le trajet engage-t-il quelqu'un ? Demandes comptées par le back
/// (`bidsCount`), demandes à traiter et colis embarqués : ceux des colis
/// chargés par l'écran ([loadedBids], `BidListLoaded`), à défaut les
/// compteurs du modèle (`pendingBidCount`, `confirmedParcelCount`).
///
/// `bidsCount` du back ne compte que les demandes en attente : un trajet dont
/// tous les colis sont acceptés y vaut 0 et passait pour vide (« Modifier » et
/// « Supprimer » ouverts, refusés ensuite par le back ; « Reporter » caché).
/// Les colis acceptés comptent donc aussi.
bool tripHasBids(AnnouncementModel trip, List<BidModel>? loadedBids) {
  final pending = tripPendingRequestCount(trip, loadedBids);
  final colis = loadedBids != null
      ? loadedBids.where(isAcceptedTabBid).length
      : trip.confirmedParcelCount;
  return (trip.bidsCount ?? 0) > 0 || pending > 0 || colis > 0;
}

/// Le trajet est-il modifiable ? Un brouillon (DRAFT) l'est au même titre
/// qu'un trajet ACTIVE, tant que personne n'y est engagé ([hasBids], voir
/// [tripHasBids]). Règle unique de l'écran du trajet : bouton « Modifier »
/// des sheets « Votre trajet », pied et menu.
bool canEditTrip(AnnouncementModel trip, bool hasBids) =>
    (trip.status == 'ACTIVE' || trip.status == 'DRAFT') && !hasBids;

/// Ouvre l'édition de [trip] depuis [context] (l'écran du trajet), une
/// seule fois même sur un double appui ([pushOncePerScreen]), puis relit le
/// détail si l'édition a enregistré (`pop(true)`), par l'`AnnouncementBloc`
/// de l'écran quand il y en a un.
Future<void> openTripEdit(BuildContext context, AnnouncementModel trip) async {
  final bloc = maybeRead<AnnouncementBloc>(context);
  final pushed = await pushOncePerScreen<bool>(
    context,
    '/trips/create',
    extra: CreateTripArgs(announcement: trip),
  );
  if ((pushed?.result ?? false) && context.mounted) {
    bloc?.add(AnnouncementDetailRequested(trip.id));
  }
}
