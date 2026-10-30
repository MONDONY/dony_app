import 'dart:async';

import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

// Routes ouvertes depuis l'écran du trajet vu par son voyageur (pied collant,
// tuiles « À traiter », cartes directes du corps, menu ⋮). Chacune ignore un
// second appui tant qu'une page ouverte depuis l'écran n'est pas refermée
// ([pushOncePerScreen]) ; celles qui peuvent changer le trajet ou ses colis
// relisent l'écran en silence au retour.

/// `true` si le trajet peut être partagé par son affiche : uniquement tant
/// qu'il reste de la place (ACTIVE). Une affiche postée sur un trajet complet
/// ferait venir des expéditeurs pour rien. Même règle pour l'icône de partage
/// de la barre d'application, la tuile « Affiche », le pied, le menu ⋮ et la
/// feuille du trajet vue par un expéditeur.
bool canShareTripPoster(AnnouncementModel a) => a.status == 'ACTIVE';

/// Ouvre l'affiche partageable du trajet (lien, légende, image), une seule
/// fois même sur un double appui ([pushOncePerScreen]). Elle ne modifie
/// rien : pas de relecture au retour.
void openTripPoster(BuildContext context, AnnouncementModel a) {
  unawaited(
    pushOncePerScreen<void>(
      context,
      '/announcements/${a.id}/affiche',
      extra: a,
    ),
  );
}

/// Activité › Demandes, onglet « À traiter », restreint au trajet [tripId]
/// (`/demandes?filter=aTraiter&announcement=<id>`).
String tripRequestsLocation(String tripId) => Uri(
  path: '/demandes',
  queryParameters: {'filter': 'aTraiter', 'announcement': tripId},
).toString();

/// Ouvre les demandes à traiter du trajet [tripId] depuis [context] (sous
/// l'écran du trajet), puis relit ses colis et le trajet au retour : une
/// demande acceptée ou refusée là-bas change les compteurs de l'écran.
/// `/demandes` ne rend pas de résultat : la relecture est inconditionnelle.
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

/// Écrans (routes) qui ont déjà une page ouverte par [pushOncePerScreen] et
/// pas encore refermée : un second appui avant que la page ne couvre l'écran
/// (double appui, `push` de GoRouter appliqué à l'image suivante) n'en
/// empile pas une deuxième. La clé est la route de l'écran : si elle
/// disparaît sans que la page ne rende la main, l'entrée part avec elle.
final _pushInFlight = Expando<bool>('tripPushInFlight');

/// Pousse [location] depuis [context] (sous l'écran du trajet) et rend le
/// résultat de la page dans `result` une fois refermée. Rend `null` sans
/// rien pousser quand une page ouverte depuis le même écran n'est pas encore
/// refermée : le pied, le menu, les sheets et les cartes partagent ce verrou
/// (Modifier, affiche, demandes, colis).
Future<({T? result})?> pushOncePerScreen<T>(
  BuildContext context,
  String location, {
  Object? extra,
}) async {
  final route = ModalRoute.of(context);
  if (route != null) {
    if (_pushInFlight[route] ?? false) return null;
    _pushInFlight[route] = true;
  }
  try {
    return (result: await context.push<T>(location, extra: extra));
  } finally {
    if (route != null) _pushInFlight[route] = null;
  }
}

Future<void> _pushThenReload(
  BuildContext context,
  String tripId,
  String location, {
  Object? extra,
}) async {
  final route = ModalRoute.of(context);
  // Blocs lus avant la navigation : le contexte peut être démonté au retour.
  final bids = maybeRead<BidBloc>(context);
  final announcement = maybeRead<AnnouncementBloc>(context);
  final pushed = await pushOncePerScreen<void>(context, location, extra: extra);
  if (pushed == null) return;
  // La relecture suit l'écran (sa route), pas le widget touché : une ligne de
  // colis ou une carte démontée pendant l'absence (liste relue, carte
  // masquée) n'empêche pas de relire l'écran resté ouvert. Écran quitté
  // entre-temps : ses blocs sont fermés, rien n'est relu.
  final screenAlive = route != null ? route.isActive : context.mounted;
  if (!screenAlive) return;
  // Relecture silencieuse : l'écran garde ses colis et son trajet affichés,
  // ni indicateur de chargement, ni tuile qui disparaît le temps de la
  // réponse, ni message d'erreur ou sortie de l'écran si elle échoue.
  bids?.add(BidListRequested(tripId, silent: true));
  announcement?.add(AnnouncementDetailRequested(tripId, silent: true));
}
