import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

// `ARRIVED` (voyageur arrivé à destination, colis pas encore remis au
// destinataire) est un statut intermédiaire entre IN_TRANSIT et COMPLETED : il
// appartient à tous les groupes qui contiennent déjà IN_TRANSIT, sinon le colis
// disparaît du hub Scan & Suivi dès le marquage d'arrivée.
// Codes de statut backend — valeurs de donnée, jamais affichées (i18n-ignore).
const _confirmedStatuses = {
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
};
const _departedStatuses = {'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED', 'COMPLETED'};
const _transitStatuses = {'IN_TRANSIT', 'ARRIVED', 'COMPLETED'};
const _arrivedStatuses = {'COMPLETED'};

/// Tous les trajets scannables du voyageur : `IN_PROGRESS` triés par date de
/// départ en premier, puis `ACTIVE`/`FULL` triés par date de départ. Un
/// voyageur peut avoir plusieurs trajets actifs en même temps — contrairement
/// à l'ancien `selectScannableTrip` (singulier), rien n'est ici filtré à un
/// seul résultat.
List<AnnouncementModel> selectScannableTrips(List<AnnouncementModel> trips) {
  int byDate(AnnouncementModel a, AnnouncementModel b) =>
      a.departureDate.compareTo(b.departureDate);

  // Statuts backend comparés ici — valeurs de donnée (i18n-ignore).
  final inProgress = trips.where((t) => t.status == 'IN_PROGRESS').toList()
    ..sort(byDate);
  final upcoming =
      trips.where((t) => t.status == 'ACTIVE' || t.status == 'FULL').toList()
        ..sort(byDate);
  return [...inProgress, ...upcoming];
}

/// Trajet affiché par défaut dans « Valider une étape » : le premier de
/// [trips] (ordre de [selectScannableTrips]) dont au moins un colis confirmé
/// attend une étape, sinon le premier trajet. [trips] n'est jamais vide.
String defaultScanTripId(
  List<AnnouncementModel> trips,
  Map<String, List<BidModel>> bidsByTrip,
) {
  for (final trip in trips) {
    final bids = confirmedColis(bidsByTrip[trip.id] ?? const []);
    if (bids.any((b) => nextRequiredStep(b) != null)) return trip.id;
  }
  return trips.first.id;
}

/// Sous-ensemble de [bids] réellement confirmés/embarqués sur le trajet
/// (`_confirmedStatuses` : `ACCEPTED`/`HANDED_OVER`/`IN_TRANSIT`/`ARRIVED`/
/// `COMPLETED`).
/// Source unique de vérité pour « quels bids sont scannables » dans le hub
/// Scan & Suivi — exclut `PENDING`, `REJECTED` et tout `CANCELLED` (y compris
/// les auto-annulés, déjà hors de `_confirmedStatuses`).
List<BidModel> confirmedColis(List<BidModel> bids) => bids
    .where((b) => _confirmedStatuses.contains(b.status))
    .toList(growable: false);

/// Étape obligatoire suivante pour ce colis, dérivée de son statut. `null` si
/// le colis est déjà remis (statut `COMPLETED`).
///
/// Deux étapes seulement sont obligatoires : `DEPART` (récupération, photo)
/// puis `ARRIVEE` (remise au destinataire avec son code). `TRANSIT` est
/// facultatif : jamais proposé automatiquement, seulement quand le voyageur
/// le choisit (« Forcer une étape »).
///
/// Renvoie le code d'étape, une valeur de donnée réutilisée telle quelle par
/// les écrans de lecture, jamais affichée directement (voir
/// `trackingStepLabel`).
String? nextRequiredStep(BidModel bid) {
  if (_arrivedStatuses.contains(bid.status)) {
    return null;
  }
  // Transit facultatif : dès le départ scanné, l'étape suivante obligatoire
  // est la remise au destinataire.
  if (_departedStatuses.contains(bid.status)) {
    return 'ARRIVEE'; // i18n-ignore
  }
  return 'DEPART'; // i18n-ignore
}

/// Progression par étape d'un colis — pilote les 3 points affichés sur sa
/// ligne dans la liste du hub.
({bool depart, bool transit, bool arrivee}) colisStepProgress(BidModel bid) => (
  depart: _departedStatuses.contains(bid.status),
  transit: _transitStatuses.contains(bid.status),
  arrivee: _arrivedStatuses.contains(bid.status),
);

/// Trajet déjà marqué arrivé, transit fermé : au moins un colis `ARRIVED` et
/// plus aucun colis récupéré qui pourrait encore passer en transit
/// (`HANDED_OVER`). Le serveur refuse le scan Transit d'un colis `ARRIVED`
/// (422 « Ce colis n'est pas dans un état scannable », Sentry FLUTTER-D6) :
/// « Forcer une étape » ne le propose plus.
bool transitClosedByArrival(List<BidModel> bids) =>
    bids.any((b) => b.status == 'ARRIVED') &&
    !bids.any((b) => b.status == 'HANDED_OVER');
