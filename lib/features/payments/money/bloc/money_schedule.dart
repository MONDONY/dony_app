/// Échéancier de « Mon argent » (FLUTTER-HV, écrans F et D) : l'argent des
/// colis groupé par échéance de versement et par trajet. Fonction pure, sans
/// accès réseau ni horloge : `now` est fourni par le BLoC.
///
/// Règles (voir aussi la PR) :
/// - « À venir » = colis voyageur dont l'argent est encore attendu
///   ([MoneyItemModel.isUpcoming]) : séquestre, garde, litige, vérification,
///   versement en cours. Jamais le solde du portefeuille Yadony.
/// - Échéance d'un colis :
///   - versement en cours → maintenant (tuile « Cette semaine ») ;
///   - versement daté (`releaseAt`, fin de garde) → ce jour-là ;
///   - séquestre versé à la confirmation de livraison → arrivée du trajet
///     (`arrivalDate`, sinon `departureDate` d'un ancien back) ; une arrivée
///     passée compte pour cette semaine ;
///   - litige ou vérification → tuile « Litige », sans date.
/// - Semaines du lundi au dimanche, en heure locale. « Cette semaine » couvre
///   aussi les échéances dépassées ; sans aucune date, « Plus tard ».
/// - Les montants ne s'additionnent jamais entre devises : chaque total est
///   une liste par devise, devise active d'abord puis ordre alphabétique.
library;

import 'package:dony/features/payments/money/data/models/money_overview_model.dart';

/// Tuile d'échéance de la carte de tête.
enum MoneyBucket { thisWeek, nextWeek, later, dispute }

/// Nature d'un groupe de « Prochains versements », dans l'ordre d'affichage.
enum PayoutGroupKind {
  /// Livré, versement en cours chez le prestataire.
  inProgress,

  /// Versement automatique daté (fin de garde), un groupe par jour.
  dated,

  /// Séquestres d'un trajet, versés à la confirmation de livraison.
  trip,

  /// Bloqué par un litige.
  dispute,

  /// Versement retenu, en vérification par l'équipe.
  review,
}

/// Un groupe de « Prochains versements ».
class PayoutGroup {
  const PayoutGroup({
    required this.kind,
    required this.items,
    required this.totals,
    this.date,
    this.trip,
  });

  final PayoutGroupKind kind;
  final List<MoneyItemModel> items;

  /// Total du groupe, une ligne par devise.
  final List<MoneyAmount> totals;

  /// Jour du versement ([PayoutGroupKind.dated]) ou arrivée du trajet
  /// ([PayoutGroupKind.trip]).
  final DateTime? date;

  /// Trajet du groupe ([PayoutGroupKind.trip]).
  final MoneyTrip? trip;
}

/// Catégorie d'un colis sur la barre d'avancement d'un trajet (écran D).
enum TripSegment {
  /// Versé (vert).
  paid,

  /// Livré, versement en cours (bleu).
  delivered,

  /// En séquestre, garde comprise (gris).
  escrow,

  /// En litige ou en vérification (orange).
  dispute,

  /// Hors séquestre : espèces, remboursement, état inconnu (neutre).
  other,
}

TripSegment segmentOf(MoneyItemModel item) => switch (item.state) {
  MoneyState.releasedRecently => TripSegment.paid,
  MoneyState.payoutInProgress => TripSegment.delivered,
  MoneyState.escrowed ||
  MoneyState.awaitingDeliveryConfirmation ||
  MoneyState.releaseScheduled => TripSegment.escrow,
  MoneyState.inDispute || MoneyState.onHold => TripSegment.dispute,
  MoneyState.cash ||
  MoneyState.refundPending ||
  MoneyState.refundedRecently ||
  MoneyState.unknown => TripSegment.other,
};

/// Un trajet du voyageur et ses colis (écran D).
class MoneyTrip {
  const MoneyTrip({
    required this.key,
    required this.items,
    required this.totals,
    required this.counts,
    this.announcementId,
    this.departureCity,
    this.arrivalCity,
    this.date,
  });

  /// Identifiant stable : l'annonce, sinon villes + date de départ.
  final String key;
  final String? announcementId;
  final String? departureCity;
  final String? arrivalCity;

  /// Arrivée du trajet, sinon jour du départ.
  final DateTime? date;
  final List<MoneyItemModel> items;

  /// Total des montants connus du trajet (versés et à venir), par devise.
  final List<MoneyAmount> totals;

  /// Nombre de colis par catégorie de la barre.
  final Map<TripSegment, int> counts;

  int count(TripSegment s) => counts[s] ?? 0;

  /// Au moins un colis dont l'argent est encore attendu.
  bool get isActive => items.any((i) => i.isUpcoming);
}

/// Échéancier complet, calculé à partir de l'aperçu.
class MoneySchedule {
  const MoneySchedule({
    required this.upcoming,
    required this.upcomingCount,
    required this.buckets,
    required this.groups,
    required this.trips,
    required this.recentlyPaid,
  });

  /// Total à venir du voyageur, par devise.
  final List<MoneyAmount> upcoming;
  final int upcomingCount;

  /// Montant de chaque tuile, par devise (liste vide = rien).
  final Map<MoneyBucket, List<MoneyAmount>> buckets;

  /// « Prochains versements », dans l'ordre d'affichage.
  final List<PayoutGroup> groups;

  /// Trajets du voyageur, actifs d'abord (arrivée la plus proche en tête),
  /// puis terminés (le plus récent en tête).
  final List<MoneyTrip> trips;

  /// Colis versés récemment, le plus récent en tête.
  final List<MoneyItemModel> recentlyPaid;

  MoneyTrip? tripFor(String announcementId) {
    for (final t in trips) {
      if (t.announcementId == announcementId) return t;
    }
    return null;
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lundi de la semaine de [d], à minuit (heure locale).
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

MoneyBucket bucketFor(DateTime? due, DateTime now) {
  if (due == null) return MoneyBucket.later;
  final week = startOfWeek(now);
  final next = DateTime(week.year, week.month, week.day + 7);
  final after = DateTime(week.year, week.month, week.day + 14);
  final day = _day(due);
  if (day.isBefore(next)) return MoneyBucket.thisWeek;
  if (day.isBefore(after)) return MoneyBucket.nextWeek;
  return MoneyBucket.later;
}

/// Somme par devise des montants connus (les colis en espèces n'en ont pas).
List<MoneyAmount> sumByCurrency(
  Iterable<MoneyItemModel> items, {
  String? activeCurrency,
}) {
  final sums = <String, double>{};
  for (final i in items) {
    final amount = i.amount;
    final currency = i.currency?.toUpperCase();
    if (amount == null || currency == null) continue;
    sums[currency] = (sums[currency] ?? 0) + amount;
  }
  final active = activeCurrency?.toUpperCase();
  final codes = sums.keys.toList()
    ..sort((a, b) {
      if (a == active) return -1;
      if (b == active) return 1;
      return a.compareTo(b);
    });
  return [for (final c in codes) MoneyAmount(c, sums[c]!)];
}

String tripKeyOf(MoneyItemModel i) =>
    i.announcementId ??
    '${i.departureCity}|${i.arrivalCity}|${i.departureDate?.toIso8601String()}';

/// Le colis attend la confirmation de livraison, sans date de versement.
bool _onDelivery(MoneyItemModel i) =>
    i.state == MoneyState.escrowed ||
    i.state == MoneyState.awaitingDeliveryConfirmation ||
    (i.state == MoneyState.releaseScheduled && i.releaseAt == null);

int _compareDates(DateTime? a, DateTime? b, {bool descending = false}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return descending ? b.compareTo(a) : a.compareTo(b);
}

MoneySchedule buildMoneySchedule(
  MoneyOverviewModel overview, {
  required DateTime now,
}) {
  final active = overview.activeCurrency;
  List<MoneyAmount> sum(Iterable<MoneyItemModel> items) =>
      sumByCurrency(items, activeCurrency: active);

  final traveler = overview.travelerItems;
  final upcoming = traveler.where((i) => i.isUpcoming).toList();

  // Trajets (écran D) : tous les colis voyageur, groupés par annonce.
  final byTrip = <String, List<MoneyItemModel>>{};
  for (final i in traveler) {
    byTrip.putIfAbsent(tripKeyOf(i), () => []).add(i);
  }
  final trips = [
    for (final entry in byTrip.entries)
      MoneyTrip(
        key: entry.key,
        announcementId: entry.value.first.announcementId,
        departureCity: entry.value.first.departureCity,
        arrivalCity: entry.value.first.arrivalCity,
        date: entry.value.first.tripDate,
        items: entry.value,
        totals: sum(entry.value),
        counts: {
          for (final s in TripSegment.values)
            s: entry.value.where((i) => segmentOf(i) == s).length,
        },
      ),
  ];
  trips.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return _compareDates(a.date, b.date, descending: !a.isActive);
  });
  final tripsByKey = {for (final t in trips) t.key: t};

  // Échéance de chaque colis à venir.
  final buckets = <MoneyBucket, List<MoneyItemModel>>{
    for (final b in MoneyBucket.values) b: [],
  };
  for (final i in upcoming) {
    final MoneyBucket bucket;
    if (i.state == MoneyState.inDispute || i.state == MoneyState.onHold) {
      bucket = MoneyBucket.dispute;
    } else if (i.state == MoneyState.payoutInProgress) {
      bucket = MoneyBucket.thisWeek;
    } else if (i.releaseAt != null) {
      bucket = bucketFor(i.releaseAt, now);
    } else {
      bucket = bucketFor(i.tripDate, now);
    }
    buckets[bucket]!.add(i);
  }

  // Groupes de « Prochains versements ».
  final groups = <PayoutGroup>[];
  final inProgress = upcoming
      .where((i) => i.state == MoneyState.payoutInProgress)
      .toList();
  if (inProgress.isNotEmpty) {
    groups.add(
      PayoutGroup(
        kind: PayoutGroupKind.inProgress,
        items: inProgress,
        totals: sum(inProgress),
      ),
    );
  }

  final dated = <DateTime, List<MoneyItemModel>>{};
  for (final i in upcoming) {
    final at = i.releaseAt;
    if (i.state == MoneyState.releaseScheduled && at != null) {
      dated.putIfAbsent(_day(at), () => []).add(i);
    }
  }
  final days = dated.keys.toList()..sort();
  for (final d in days) {
    final items = dated[d]!
      ..sort((a, b) => a.releaseAt!.compareTo(b.releaseAt!));
    groups.add(
      PayoutGroup(
        kind: PayoutGroupKind.dated,
        items: items,
        totals: sum(items),
        date: d,
      ),
    );
  }

  final onDelivery = <String, List<MoneyItemModel>>{};
  for (final i in upcoming.where(_onDelivery)) {
    onDelivery.putIfAbsent(tripKeyOf(i), () => []).add(i);
  }
  final tripGroups = [
    for (final entry in onDelivery.entries)
      PayoutGroup(
        kind: PayoutGroupKind.trip,
        items: entry.value,
        totals: sum(entry.value),
        date: entry.value.first.tripDate,
        trip: tripsByKey[entry.key],
      ),
  ]..sort((a, b) => _compareDates(a.date, b.date));
  groups.addAll(tripGroups);

  for (final (kind, state) in [
    (PayoutGroupKind.dispute, MoneyState.inDispute),
    (PayoutGroupKind.review, MoneyState.onHold),
  ]) {
    final items = upcoming.where((i) => i.state == state).toList();
    if (items.isNotEmpty) {
      groups.add(PayoutGroup(kind: kind, items: items, totals: sum(items)));
    }
  }

  final recentlyPaid =
      traveler.where((i) => i.state == MoneyState.releasedRecently).toList()
        ..sort(
          (a, b) => _compareDates(a.settledAt, b.settledAt, descending: true),
        );

  return MoneySchedule(
    upcoming: sum(upcoming),
    upcomingCount: upcoming.length,
    buckets: {for (final e in buckets.entries) e.key: sum(e.value)},
    groups: groups,
    trips: trips,
    recentlyPaid: recentlyPaid,
  );
}
