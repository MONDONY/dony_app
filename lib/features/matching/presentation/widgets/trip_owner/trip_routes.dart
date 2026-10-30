import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

// Routes ouvertes depuis l'écran du trajet vu par son voyageur (grille
// d'actions, tuiles « À traiter », cartes directes du corps).

/// Activité › Demandes, onglet « À traiter », restreint au trajet [tripId]
/// (`/demandes?filter=aTraiter&announcement=<id>`).
String tripRequestsLocation(String tripId) => Uri(
  path: '/demandes',
  queryParameters: {'filter': 'aTraiter', 'announcement': tripId},
).toString();

/// Ouvre les demandes à traiter du trajet [tripId] depuis [context] (l'écran
/// du trajet), puis relit ses colis et le trajet au retour : une demande
/// acceptée ou refusée là-bas change les compteurs de l'écran. `/demandes`
/// ne rend pas de résultat : la relecture est inconditionnelle.
Future<void> openTripRequests(BuildContext context, String tripId) =>
    _pushThenReload(context, tripId, tripRequestsLocation(tripId));

/// Ouvre la liste des colis du trajet [tripId] (`/announcements/:id/bids`,
/// titre « Colis »), puis relit ses colis et le trajet au retour : la liste
/// accepte, refuse et fait avancer les colis.
Future<void> openTripParcelsList(BuildContext context, String tripId) =>
    _pushThenReload(
      context,
      tripId,
      '/announcements/$tripId/bids',
      extra: <String, dynamic>{'title': context.l10n.tripOwnerParcelsTile},
    );

/// Ouvre la fiche du colis [bidId] du trajet [tripId], puis relit les colis
/// et le trajet au retour (remise, refus, arrivée faits sur la fiche).
Future<void> openTripParcel(
  BuildContext context, {
  required String tripId,
  required String bidId,
}) => _pushThenReload(context, tripId, '/bids/$bidId');

Future<void> _pushThenReload(
  BuildContext context,
  String tripId,
  String location, {
  Object? extra,
}) async {
  // Blocs lus avant la navigation : le contexte peut être démonté au retour.
  final bids = maybeRead<BidBloc>(context);
  final announcement = maybeRead<AnnouncementBloc>(context);
  await context.push<void>(location, extra: extra);
  // Écran quitté entre-temps : ses blocs sont fermés.
  if (!context.mounted) return;
  // Relecture silencieuse : l'écran garde ses colis affichés, ni indicateur
  // de chargement ni tuile qui disparaît le temps de la réponse.
  bids?.add(BidListRequested(tripId, silent: true));
  announcement?.add(AnnouncementDetailRequested(tripId));
}
