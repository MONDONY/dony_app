import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'money_fixtures.dart';

/// Mercredi 8 octobre 2026 : semaine du lundi 5 au dimanche 11, semaine
/// prochaine du 12 au 18, plus tard à partir du 19.
final _now = DateTime(2026, 10, 8, 15);

MoneySchedule _schedule(
  List<MoneyItemModel> traveler, {
  String? activeCurrency,
  List<MoneyItemModel> sender = const [],
}) => buildMoneySchedule(
  MoneyOverviewModel(
    travelerItems: traveler,
    senderItems: sender,
    activeCurrency: activeCurrency,
  ),
  now: _now,
);

void main() {
  group('semaines', () {
    test('startOfWeek rend le lundi à minuit, même un dimanche', () {
      expect(startOfWeek(DateTime(2026, 10, 8, 15)), DateTime(2026, 10, 5));
      expect(startOfWeek(DateTime(2026, 10, 11, 23)), DateTime(2026, 10, 5));
      expect(startOfWeek(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    });

    test('bucketFor : retard et semaine en cours, prochaine, plus tard', () {
      expect(bucketFor(DateTime(2026, 9, 30), _now), MoneyBucket.thisWeek);
      expect(bucketFor(DateTime(2026, 10, 11, 23), _now), MoneyBucket.thisWeek);
      expect(bucketFor(DateTime(2026, 10, 12), _now), MoneyBucket.nextWeek);
      expect(bucketFor(DateTime(2026, 10, 18, 22), _now), MoneyBucket.nextWeek);
      expect(bucketFor(DateTime(2026, 10, 19), _now), MoneyBucket.later);
      expect(bucketFor(null, _now), MoneyBucket.later);
    });
  });

  test('échéances : daté, arrivée du trajet (repli départ), en cours, '
      'litige et vérification', () {
    final s = _schedule([
      item(
        bidId: 'auto',
        state: MoneyState.releaseScheduled,
        releaseAt: DateTime(2026, 10, 13, 9),
        amount: 31,
      ),
      item(
        bidId: 'arrival',
        announcementId: 'ann-2',
        arrivalDate: DateTime(2026, 10, 9),
        departureDate: DateTime(2026, 10, 8),
        amount: 20,
      ),
      // Ancien back sans arrivalDate : le départ sert d'échéance.
      item(
        bidId: 'legacy',
        announcementId: 'ann-3',
        departureDate: DateTime(2026, 10, 25),
        state: MoneyState.awaitingDeliveryConfirmation,
        amount: 40,
      ),
      item(bidId: 'payout', state: MoneyState.payoutInProgress, amount: 15),
      item(bidId: 'dispute', state: MoneyState.inDispute, amount: 32),
      item(bidId: 'hold', state: MoneyState.onHold, amount: 8),
      item(bidId: 'paid', state: MoneyState.releasedRecently, amount: 50),
      item(bidId: 'cash', state: MoneyState.cash, amount: null),
    ]);
    double total(MoneyBucket b) => s.buckets[b]!.single.amount;
    expect(total(MoneyBucket.thisWeek), 35); // arrivée 9 + versement en cours
    expect(total(MoneyBucket.nextWeek), 31); // versement auto le 13
    expect(total(MoneyBucket.later), 40); // départ du 25
    expect(total(MoneyBucket.dispute), 40); // litige + vérification
    expect(s.upcomingCount, 6);
    expect(s.upcoming.single.amount, 146);
    expect(s.recentlyPaid.single.bidId, 'paid');
  });

  test('groupes : en cours, datés par jour, trajets par arrivée, litige, '
      'vérification', () {
    final s = _schedule([
      item(bidId: 'hold', state: MoneyState.onHold),
      item(bidId: 'dispute', state: MoneyState.inDispute),
      item(
        bidId: 'far',
        announcementId: 'far-trip',
        arrivalDate: DateTime(2026, 10, 24),
      ),
      item(
        bidId: 'near-1',
        announcementId: 'near-trip',
        arrivalDate: DateTime(2026, 10, 18),
      ),
      item(
        bidId: 'near-2',
        announcementId: 'near-trip',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.awaitingDeliveryConfirmation,
      ),
      // Garde sans date : versé à la livraison, groupé avec son trajet.
      item(
        bidId: 'near-3',
        announcementId: 'near-trip',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.releaseScheduled,
      ),
      item(
        bidId: 'auto-12b',
        state: MoneyState.releaseScheduled,
        releaseAt: DateTime(2026, 10, 12, 18),
      ),
      item(
        bidId: 'auto-11',
        state: MoneyState.releaseScheduled,
        releaseAt: DateTime(2026, 10, 11, 8),
      ),
      item(
        bidId: 'auto-12a',
        state: MoneyState.releaseScheduled,
        releaseAt: DateTime(2026, 10, 12, 7),
      ),
      item(bidId: 'payout', state: MoneyState.payoutInProgress),
    ]);
    expect(s.groups.map((g) => g.kind), [
      PayoutGroupKind.inProgress,
      PayoutGroupKind.dated,
      PayoutGroupKind.dated,
      PayoutGroupKind.trip,
      PayoutGroupKind.trip,
      PayoutGroupKind.dispute,
      PayoutGroupKind.review,
    ]);
    expect(s.groups[1].date, DateTime(2026, 10, 11));
    expect(s.groups[2].date, DateTime(2026, 10, 12));
    expect(s.groups[2].items.map((i) => i.bidId), ['auto-12a', 'auto-12b']);
    final near = s.groups[3];
    expect(near.date, DateTime(2026, 10, 18));
    expect(near.items.map((i) => i.bidId), ['near-1', 'near-2', 'near-3']);
    expect(near.totals.single.amount, 300);
    expect(near.trip?.announcementId, 'near-trip');
    expect(s.groups[4].trip?.announcementId, 'far-trip');
  });

  test('multi-devises : jamais additionnées, devise active en tête', () {
    final s = _schedule([
      item(bidId: 'eur', announcementId: 't', amount: 20),
      item(bidId: 'xof', announcementId: 't', currency: 'XOF', amount: 9000),
      item(bidId: 'eur2', announcementId: 't', amount: 5),
      item(bidId: 'cad', announcementId: 't', currency: 'cad', amount: 7),
    ], activeCurrency: 'XOF');
    final trip = s.groups.single;
    expect(trip.totals.map((a) => a.currency), ['XOF', 'CAD', 'EUR']);
    expect(trip.totals.map((a) => a.amount), [9000, 7, 25]);
    expect(s.upcoming.map((a) => a.currency), ['XOF', 'CAD', 'EUR']);
    expect(s.buckets[MoneyBucket.later]!.map((a) => a.currency), [
      'XOF',
      'CAD',
      'EUR',
    ]);
    expect(s.buckets[MoneyBucket.thisWeek], isEmpty);
  });

  test('trajets (écran D) : actifs par arrivée croissante, terminés du plus '
      'récent au plus ancien, compteurs par catégorie', () {
    final s = _schedule([
      item(
        bidId: 'old-paid',
        announcementId: 'old',
        departureDate: DateTime(2026, 9),
        state: MoneyState.releasedRecently,
      ),
      item(
        bidId: 'recent-paid',
        announcementId: 'recent',
        departureDate: DateTime(2026, 9, 20),
        state: MoneyState.releasedRecently,
      ),
      item(
        bidId: 'later',
        announcementId: 'later',
        arrivalDate: DateTime(2026, 11, 2),
      ),
      item(
        bidId: 'soon-1',
        announcementId: 'soon',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.releasedRecently,
      ),
      item(
        bidId: 'soon-2',
        announcementId: 'soon',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.payoutInProgress,
      ),
      item(
        bidId: 'soon-3',
        announcementId: 'soon',
        arrivalDate: DateTime(2026, 10, 18),
      ),
      item(
        bidId: 'soon-4',
        announcementId: 'soon',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.inDispute,
      ),
      item(
        bidId: 'soon-5',
        announcementId: 'soon',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.cash,
        amount: null,
      ),
      item(
        bidId: 'soon-6',
        announcementId: 'soon',
        arrivalDate: DateTime(2026, 10, 18),
        state: MoneyState.refundPending,
      ),
    ]);
    expect(s.trips.map((t) => t.key), ['soon', 'later', 'recent', 'old']);
    final soon = s.tripFor('soon')!;
    expect(soon.isActive, isTrue);
    expect(soon.count(TripSegment.paid), 1);
    expect(soon.count(TripSegment.delivered), 1);
    expect(soon.count(TripSegment.escrow), 1);
    expect(soon.count(TripSegment.dispute), 1);
    expect(soon.count(TripSegment.other), 2);
    expect(soon.totals.single.amount, 500);
    expect(soon.date, DateTime(2026, 10, 18));
    expect(s.tripFor('old')!.isActive, isFalse);
    expect(s.tripFor('missing'), isNull);
  });

  test('trajet sans annonce : clé villes + départ, côté expéditeur ignoré', () {
    final s = _schedule(
      [
        item(
          bidId: 'x',
          announcementId: null,
          departureDate: DateTime(2026, 10, 9),
        ),
      ],
      sender: [item(bidId: 'sent', role: MoneyRole.sender)],
    );
    expect(s.trips.single.key, startsWith('Paris|Dakar|2026-10-09'));
    expect(s.trips.single.announcementId, isNull);
    expect(s.upcomingCount, 1);
  });

  test('états hors séquestre : segment « other », jamais à venir', () {
    for (final state in [
      MoneyState.cash,
      MoneyState.refundPending,
      MoneyState.refundedRecently,
      MoneyState.unknown,
    ]) {
      expect(segmentOf(item(state: state)), TripSegment.other);
    }
    final s = _schedule([item(state: MoneyState.unknown)]);
    expect(s.groups, isEmpty);
    expect(s.upcoming, isEmpty);
  });

  test('versés récemment : le plus récent en tête, sans date à la fin', () {
    final s = _schedule([
      item(
        bidId: 'a',
        state: MoneyState.releasedRecently,
        settledAt: DateTime(2026, 10),
      ),
      item(bidId: 'b', state: MoneyState.releasedRecently),
      item(
        bidId: 'c',
        state: MoneyState.releasedRecently,
        settledAt: DateTime(2026, 10, 5),
      ),
    ]);
    expect(s.recentlyPaid.map((i) => i.bidId), ['c', 'a', 'b']);
  });
}
