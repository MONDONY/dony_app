import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _senderJson() => {
  'id': 'am-1',
  'status': 'PROPOSED',
  'rail': 'STRIPE',
  'currency': 'EUR',
  'addedWeightKg': 2.5,
  'items': [
    {
      'label': 'Téléphone',
      'quantity': 2,
      'grossAmount': 20.5,
      'netAmount': null,
    },
  ],
  'grossAmount': 33.5,
  'netAmount': null,
  'commissionAmount': null,
  'expiresAt': '2026-10-25T10:30:00Z',
  'paymentExpiresAt': null,
  'closedReason': null,
  'blocksHandover': true,
  'commissionStatus': null,
  'commissionClientSecret': null,
};

void main() {
  test('bid_amendment_fromJson_senderHasNoNet', () {
    final amendment = BidAmendment.fromJson(_senderJson());

    expect(amendment.status, BidAmendmentStatus.proposed);
    expect(amendment.netAmount, isNull);
    expect(amendment.commissionAmount, isNull);
    expect(amendment.commissionStatus, isNull);
    expect(amendment.items.single.netAmount, isNull);
    expect(amendment.items.single.grossAmount, 20.5);
    expect(amendment.items.single.quantity, 2);
    expect(amendment.grossAmount, 33.5);
    expect(amendment.addedWeightKg, 2.5);
    expect(amendment.blocksHandover, isTrue);
  });

  test('les dates sont lues en UTC', () {
    final amendment = BidAmendment.fromJson({
      ..._senderJson(),
      'paymentExpiresAt': '2026-10-25T11:00:00+00:00',
    });

    expect(amendment.expiresAt, DateTime.utc(2026, 10, 25, 10, 30));
    expect(amendment.expiresAt!.isUtc, isTrue);
    expect(amendment.paymentExpiresAt, DateTime.utc(2026, 10, 25, 11));
    expect(amendment.paymentExpiresAt!.isUtc, isTrue);
  });

  test('traveler : net, commission et net des articles présents', () {
    final amendment = BidAmendment.fromJson({
      ..._senderJson(),
      'rail': 'CASH',
      'items': [
        {
          'label': 'Téléphone',
          'quantity': 1,
          'grossAmount': 10,
          'netAmount': 8.5,
        },
      ],
      'netAmount': 23.5,
      'commissionAmount': 3.3,
      'commissionStatus': 'REQUIRES_3DS',
      'status': 'COMMISSION_PENDING',
      'commissionClientSecret': 'pi_secret',
    });

    expect(amendment.netAmount, 23.5);
    expect(amendment.commissionAmount, 3.3);
    expect(amendment.items.single.netAmount, 8.5);
    expect(amendment.isCash, isTrue);
    expect(amendment.needsCommissionAuth, isTrue);
  });

  test('commissionClientSecret ne repart jamais en JSON', () {
    final amendment = BidAmendment.fromJson({
      ..._senderJson(),
      'commissionClientSecret': 'pi_secret',
    });

    expect(amendment.commissionClientSecret, 'pi_secret');
    expect(amendment.toJson().containsKey('commissionClientSecret'), isFalse);
  });

  test('withCommissionClientSecret pose le secret sans toucher au reste', () {
    final amendment = BidAmendment.fromJson(_senderJson());

    final withSecret = amendment.withCommissionClientSecret('pi_secret');

    expect(withSecret.commissionClientSecret, 'pi_secret');
    expect(withSecret.id, amendment.id);
    expect(withSecret.grossAmount, amendment.grossAmount);
    expect(withSecret.items.single.label, 'Téléphone');
  });

  test('unknown_status_maps_to_unknown', () {
    final amendment = BidAmendment.fromJson({
      ..._senderJson(),
      'status': 'SOMETHING_NEW',
    });

    expect(amendment.status, BidAmendmentStatus.unknown);
    expect(amendment.status.isOpen, isFalse);
    expect(amendment.status.isSecured, isFalse);
    expect(amendment.status.isClosedUnaccepted, isFalse);
  });

  test('chaque statut du back est reconnu et classé', () {
    const open = {
      'AUTHORIZATION_PENDING': BidAmendmentStatus.authorizationPending,
      'PROPOSED': BidAmendmentStatus.proposed,
      'COMMISSION_PENDING': BidAmendmentStatus.commissionPending,
      'PAYMENT_PENDING': BidAmendmentStatus.paymentPending,
    };
    const secured = {
      'ACCEPTED': BidAmendmentStatus.accepted,
      'PAYOUT_PENDING': BidAmendmentStatus.payoutPending,
      'PAID_OUT': BidAmendmentStatus.paidOut,
    };
    const closed = {
      'DECLINED': BidAmendmentStatus.declined,
      'EXPIRED': BidAmendmentStatus.expired,
      'CANCELLED': BidAmendmentStatus.cancelled,
      'REFUND_PENDING': BidAmendmentStatus.refundPending,
      'REFUNDED': BidAmendmentStatus.refunded,
    };
    BidAmendmentStatus parse(String raw) =>
        BidAmendment.fromJson({..._senderJson(), 'status': raw}).status;

    open.forEach((raw, status) {
      expect(parse(raw), status);
      expect(status.isOpen, isTrue, reason: raw);
      expect(status.isSecured, isFalse, reason: raw);
      expect(status.isClosedUnaccepted, isFalse, reason: raw);
    });
    secured.forEach((raw, status) {
      expect(parse(raw), status);
      expect(status.isOpen, isFalse, reason: raw);
      expect(status.isSecured, isTrue, reason: raw);
      expect(status.isClosedUnaccepted, isFalse, reason: raw);
    });
    closed.forEach((raw, status) {
      expect(parse(raw), status);
      expect(status.isOpen, isFalse, reason: raw);
      expect(status.isSecured, isFalse, reason: raw);
      expect(status.isClosedUnaccepted, isTrue, reason: raw);
    });
  });

  test('un JSON minimal reste lisible (devise EUR, aucun article)', () {
    final amendment = BidAmendment.fromJson({
      'id': 'am-9',
      'status': 'ACCEPTED',
      'grossAmount': 5,
    });

    expect(amendment.currency, 'EUR');
    expect(amendment.items, isEmpty);
    expect(amendment.addedWeightKg, 0);
    expect(amendment.blocksHandover, isFalse);
    expect(amendment.rail, isNull);
  });

  test('AmendmentOptions : kilos libres nuls quand la capacité est libre', () {
    final options = AmendmentOptions.fromJson({
      'currency': 'EUR',
      'availableKg': null,
      'pricePerKgDisplay': 12,
      'gridItems': [
        {'id': 'g-1', 'label': 'Téléphone', 'unitPriceDisplay': 10.5},
      ],
      'paymentMethods': ['STRIPE', 'MOBILE_MONEY', 'CASH', 'NOUVEAU'],
      'expiresAt': '2026-10-25T10:30:00Z',
      'minAmount': 1,
      'maxAmount': 300,
    });

    expect(options.availableKg, isNull);
    expect(options.pricePerKgDisplay, 12.0);
    expect(options.gridItems.single.id, 'g-1');
    expect(options.gridItems.single.unitPriceDisplay, 10.5);
    expect(options.paymentMethods, [
      BidPaymentMethod.stripe,
      BidPaymentMethod.mobileMoney,
      BidPaymentMethod.cash,
    ]);
    expect(options.expiresAt, DateTime.utc(2026, 10, 25, 10, 30));
    expect(options.minAmount, 1.0);
    expect(options.maxAmount, 300.0);
  });

  test('AmendmentOptions : sans prix au kilo ni article', () {
    final options = AmendmentOptions.fromJson({
      'currency': 'XOF',
      'availableKg': 4.5,
      'minAmount': 650,
      'maxAmount': 200000,
    });

    expect(options.availableKg, 4.5);
    expect(options.pricePerKgDisplay, isNull);
    expect(options.gridItems, isEmpty);
    expect(options.paymentMethods, isEmpty);
    expect(options.expiresAt, isNull);
  });

  test('AmendmentCheckout : PaymentSheet de l\'autorisation carte', () {
    final checkout = AmendmentCheckout.fromJson({
      'amendment': _senderJson(),
      'clientSecret': 'pi_secret',
      'paymentMethodTypes': ['card', 'paypal'],
      'publishableKey': 'pk_test',
    });

    expect(checkout.amendment.id, 'am-1');
    expect(checkout.clientSecret, 'pi_secret');
    expect(checkout.paymentMethodTypes, ['card', 'paypal']);
    expect(checkout.publishableKey, 'pk_test');
    expect(checkout.needsPaymentSheet, isTrue);
  });

  test('AmendmentCheckout : espèces et mobile money, sans PaymentSheet', () {
    final checkout = AmendmentCheckout.fromJson({
      'amendment': _senderJson(),
      'clientSecret': null,
      'paymentMethodTypes': null,
      'publishableKey': null,
    });

    expect(checkout.clientSecret, isNull);
    expect(checkout.paymentMethodTypes, isEmpty);
    expect(checkout.needsPaymentSheet, isFalse);
  });

  test('wire_isServerValue_forEveryStatus', () {
    expect(
      BidAmendmentStatus.authorizationPending.wire,
      'AUTHORIZATION_PENDING',
    );
    expect(BidAmendmentStatus.proposed.wire, 'PROPOSED');
    expect(BidAmendmentStatus.commissionPending.wire, 'COMMISSION_PENDING');
    expect(BidAmendmentStatus.paidOut.wire, 'PAID_OUT');
    expect(BidAmendmentStatus.unknown.wire, 'UNKNOWN');
  });
}
