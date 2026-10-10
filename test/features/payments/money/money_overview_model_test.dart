import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'money_fixtures.dart';

void main() {
  test('lit le contrat complet du back', () {
    final m = overviewModel();
    expect(m.activeCurrency, 'XOF');
    expect(m.truncated, isFalse);
    expect(m.recentWindowDays, 30);
    expect(m.travelerItems, hasLength(4));
    final held = m.travelerItems.first;
    expect(held.state, MoneyState.releaseScheduled);
    expect(
      held.releaseCondition,
      ReleaseCondition.autoReleaseAfterHoldIfNoDispute,
    );
    expect(held.channel, MoneyChannel.mobileMoney);
    expect(held.role, MoneyRole.traveler);
    expect(held.releaseAt, DateTime.utc(2026, 10, 11, 8).toLocal());
    expect(held.departureDate, DateTime(2026, 10, 14));
    // Ancien back sans arrivalDate : l'échéance retombe sur le départ.
    expect(held.arrivalDate, isNull);
    expect(held.tripDate, DateTime(2026, 10, 14));
    final escrow = m.travelerItems[1];
    expect(escrow.arrivalDate, DateTime(2026, 10, 19));
    expect(escrow.tripDate, DateTime(2026, 10, 19));
    expect(held.weightKg, 10);
    expect(held.amount, 7950);
    expect(held.counterpartyName, 'Awa K.');
    final cash = m.travelerItems[2];
    expect(cash.state, MoneyState.cash);
    expect(cash.channel, MoneyChannel.cash);
    expect(cash.amount, isNull);
    expect(cash.cashCommissionStatus, 'CHARGED');
    expect(m.travelerItems.last.settledAt, isNotNull);
    expect(m.senderItems.single.role, MoneyRole.sender);
    expect(m.senderItems.single.state, MoneyState.inDispute);
    expect(m.senderTotals.single.blocked, 150);
    expect(m.senderTotals.single.refundedRecently, 40);
  });

  test('montants à venir et compteurs par rôle', () {
    final m = overviewModel();
    expect(m.travelerUpcoming.map((a) => a.currency), ['XOF']);
    expect(m.travelerUpcoming.single.amount, 17400);
    expect(m.travelerUpcomingCount, 2);
    expect(m.senderBlocked.single.amount, 150);
    expect(m.senderBlockedCount, 1);
    expect(m.isEmpty, isFalse);
  });

  test('tolère un corps minimal et des valeurs inconnues', () {
    final m = MoneyOverviewModel.fromJson({
      'traveler': {
        'items': [
          {'bidId': 'x', 'state': 'FUTURE_STATE', 'releaseCondition': 'NEW'},
        ],
      },
    });
    expect(m.activeCurrency, isNull);
    expect(m.truncated, isFalse);
    expect(m.recentWindowDays, 30);
    expect(m.senderItems, isEmpty);
    final i = m.travelerItems.single;
    expect(i.state, MoneyState.unknown);
    expect(i.releaseCondition, ReleaseCondition.unknown);
    expect(i.channel, MoneyChannel.card);
    expect(i.isUpcoming, isFalse);
    expect(MoneyOverviewModel.fromJson({}).isEmpty, isTrue);
  });

  test('lit truncated et ignore une devise active vide', () {
    final m = MoneyOverviewModel.fromJson({
      'truncated': true,
      'activeCurrency': '  ',
    });
    expect(m.truncated, isTrue);
    expect(m.activeCurrency, isNull);
  });

  test('parse chaque code serveur', () {
    const states = {
      'ESCROWED': MoneyState.escrowed,
      'AWAITING_DELIVERY_CONFIRMATION': MoneyState.awaitingDeliveryConfirmation,
      'RELEASE_SCHEDULED': MoneyState.releaseScheduled,
      'IN_DISPUTE': MoneyState.inDispute,
      'ON_HOLD': MoneyState.onHold,
      'PAYOUT_IN_PROGRESS': MoneyState.payoutInProgress,
      'RELEASED_RECENTLY': MoneyState.releasedRecently,
      'REFUND_PENDING': MoneyState.refundPending,
      'REFUNDED_RECENTLY': MoneyState.refundedRecently,
      'CASH': MoneyState.cash,
    };
    states.forEach((k, v) => expect(MoneyState.parse(k), v));
    const conditions = {
      'ON_DELIVERY_CONFIRMATION': ReleaseCondition.onDeliveryConfirmation,
      'AUTO_RELEASE_AFTER_HOLD_IF_NO_DISPUTE':
          ReleaseCondition.autoReleaseAfterHoldIfNoDispute,
      'ADMIN_DECISION': ReleaseCondition.adminDecision,
      'ADMIN_REVIEW': ReleaseCondition.adminReview,
      'PAYOUT_PROCESSING': ReleaseCondition.payoutProcessing,
      'RELEASED': ReleaseCondition.released,
      'REFUND_PROCESSING': ReleaseCondition.refundProcessing,
      'REFUNDED': ReleaseCondition.refunded,
      'CASH_IN_PERSON': ReleaseCondition.cashInPerson,
    };
    conditions.forEach((k, v) => expect(ReleaseCondition.parse(k), v));
    expect(MoneyChannel.parse('CARD'), MoneyChannel.card);
    expect(MoneyRole.parse(null), MoneyRole.traveler);
  });

  test('isUpcoming couvre les états en attente du voyageur', () {
    for (final s in [
      MoneyState.escrowed,
      MoneyState.awaitingDeliveryConfirmation,
      MoneyState.releaseScheduled,
      MoneyState.inDispute,
      MoneyState.onHold,
      MoneyState.payoutInProgress,
    ]) {
      expect(item(state: s).isUpcoming, isTrue, reason: s.name);
    }
    for (final s in [
      MoneyState.releasedRecently,
      MoneyState.refundPending,
      MoneyState.refundedRecently,
      MoneyState.cash,
    ]) {
      expect(item(state: s).isUpcoming, isFalse, reason: s.name);
    }
  });

  test('activeCurrency optionnelle (FLUTTER-J4)', () {
    expect(overviewModel().activeCurrency, 'XOF');
    expect(
      MoneyOverviewModel.fromJson({'activeCurrency': 'xof'}).activeCurrency,
      'XOF',
    );
    expect(
      MoneyOverviewModel.fromJson({'activeCurrency': ''}).activeCurrency,
      isNull,
    );
    expect(
      MoneyOverviewModel.fromJson({'activeCurrency': 42}).activeCurrency,
      isNull,
    );
  });
}
