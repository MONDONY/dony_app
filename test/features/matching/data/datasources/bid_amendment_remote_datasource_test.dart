import 'package:dony/features/matching/data/datasources/bid_amendment_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/recording_dio.dart';

const _bidId = '550e8400-e29b-41d4-a716-446655440000';
const _amId = '6f9619ff-8b86-d011-b42d-00c04fc964ff';
const _base = '/bids/$_bidId/amendments';

Map<String, dynamic> _amendment(String status) => {
  'id': _amId,
  'status': status,
  'rail': 'STRIPE',
  'currency': 'EUR',
  'addedWeightKg': 2,
  'items': <Map<String, dynamic>>[],
  'grossAmount': 22.4,
  'blocksHandover': true,
};

void main() {
  late RecordingApi api;
  late BidAmendmentRemoteDatasource datasource;

  setUp(() {
    api = RecordingApi();
    datasource = BidAmendmentRemoteDatasource(api.client);
  });

  test('options : GET /bids/{id}/amendments/options', () async {
    api.on('GET', '$_base/options', {
      'currency': 'EUR',
      'availableKg': 6,
      'pricePerKgDisplay': 12,
      'gridItems': <Object>[],
      'paymentMethods': ['STRIPE', 'CASH'],
      'minAmount': 1,
      'maxAmount': 300,
    });

    final options = await datasource.options(_bidId);

    expect(api.last.method, 'GET');
    expect(options.availableKg, 6.0);
    expect(options.paymentMethods, [
      BidPaymentMethod.stripe,
      BidPaymentMethod.cash,
    ]);
  });

  test('quote_postsItemsAsList : kilos et articles, rend le brut', () async {
    api.on('POST', '$_base/quote', {'grossAmount': 22.4, 'currency': 'EUR'});

    final gross = await datasource.quote(
      _bidId,
      addedKg: 2,
      items: {'g-1': 2, 'g-2': 1},
    );

    expect(gross, 22.4);
    expect(api.last.method, 'POST');
    expect(api.last.data, {
      'addedKg': 2.0,
      'items': [
        {'gridItemId': 'g-1', 'quantity': 2},
        {'gridItemId': 'g-2', 'quantity': 1},
      ],
    });
  });

  test('quote : une quantité nulle n\'est pas envoyée', () async {
    api.on('POST', '$_base/quote', {'grossAmount': 5, 'currency': 'EUR'});

    await datasource.quote(_bidId, addedKg: 0, items: {'g-1': 0, 'g-2': 3});

    expect(api.last.data, {
      'addedKg': 0.0,
      'items': [
        {'gridItemId': 'g-2', 'quantity': 3},
      ],
    });
  });

  test(
    'create_postsItemsAsList : POST /amendments, 201 avec PaymentSheet',
    () async {
      api.on('POST', _base, {
        'amendment': _amendment('AUTHORIZATION_PENDING'),
        'clientSecret': 'pi_secret',
        'paymentMethodTypes': ['card'],
        'publishableKey': 'pk_test',
      }, status: 201);

      final checkout = await datasource.create(
        _bidId,
        addedKg: 1.5,
        items: {'g-1': 2},
        method: BidPaymentMethod.stripe,
      );

      expect(api.last.method, 'POST');
      expect(api.last.data, {
        'addedKg': 1.5,
        'items': [
          {'gridItemId': 'g-1', 'quantity': 2},
        ],
        'paymentMethod': 'STRIPE',
      });
      expect(
        checkout.amendment.status,
        BidAmendmentStatus.authorizationPending,
      );
      expect(checkout.clientSecret, 'pi_secret');
      expect(checkout.publishableKey, 'pk_test');
    },
  );

  test('create : mobile money, pas de PaymentSheet', () async {
    api.on('POST', _base, {
      'amendment': _amendment('PROPOSED'),
      'clientSecret': null,
      'paymentMethodTypes': null,
      'publishableKey': null,
    }, status: 201);

    final checkout = await datasource.create(
      _bidId,
      addedKg: 2,
      items: const {},
      method: BidPaymentMethod.mobileMoney,
    );

    expect(api.last.data, {
      'addedKg': 2.0,
      'items': <Object>[],
      'paymentMethod': 'MOBILE_MONEY',
    });
    expect(checkout.needsPaymentSheet, isFalse);
  });

  test('confirmAuthorization : POST …/{id}/confirm-authorization', () async {
    api.on(
      'POST',
      '$_base/$_amId/confirm-authorization',
      _amendment('PROPOSED'),
    );

    final result = await datasource.confirmAuthorization(_bidId, _amId);

    expect(api.last.method, 'POST');
    expect(result.status, BidAmendmentStatus.proposed);
  });

  test('cancel : DELETE …/{id}', () async {
    api.on('DELETE', '$_base/$_amId', _amendment('CANCELLED'));

    final result = await datasource.cancel(_bidId, _amId);

    expect(api.last.method, 'DELETE');
    expect(result.status, BidAmendmentStatus.cancelled);
  });

  test('decline : POST …/{id}/decline', () async {
    api.on('POST', '$_base/$_amId/decline', _amendment('DECLINED'));

    final result = await datasource.decline(_bidId, _amId);

    expect(api.last.method, 'POST');
    expect(result.status, BidAmendmentStatus.declined);
  });

  test('notBrought : POST …/{id}/not-brought', () async {
    api.on('POST', '$_base/$_amId/not-brought', _amendment('REFUND_PENDING'));

    final result = await datasource.notBrought(_bidId, _amId);

    expect(api.last.method, 'POST');
    expect(result.status, BidAmendmentStatus.refundPending);
  });

  test(
    'accept_sendsCommissionSource : source et devise dans le corps',
    () async {
      api.on('POST', '$_base/$_amId/accept', {
        'amendment': _amendment('COMMISSION_PENDING'),
        'commissionClientSecret': 'pi_comm_secret',
      });

      final result = await datasource.accept(
        _bidId,
        _amId,
        commissionSource: SupplementCommissionSource.card,
        fundingCurrency: ' xof ',
      );

      expect(api.last.method, 'POST');
      expect(api.last.data, {
        'commissionSource': 'CARD',
        'fundingCurrency': 'XOF',
      });
      expect(result.status, BidAmendmentStatus.commissionPending);
      expect(result.commissionClientSecret, 'pi_comm_secret');
      expect(result.needsCommissionAuth, isTrue);
    },
  );

  test(
    'accept : sans option, aucun corps (rails carte et mobile money)',
    () async {
      api.on('POST', '$_base/$_amId/accept', {
        'amendment': _amendment('ACCEPTED'),
        'commissionClientSecret': null,
      });

      final result = await datasource.accept(_bidId, _amId);

      expect(api.last.data, isNull);
      expect(result.status, BidAmendmentStatus.accepted);
      expect(result.commissionClientSecret, isNull);
    },
  );

  test('confirmCommission : POST …/{id}/commission/confirm', () async {
    api.on('POST', '$_base/$_amId/commission/confirm', _amendment('ACCEPTED'));

    final result = await datasource.confirmCommission(_bidId, _amId);

    expect(api.last.method, 'POST');
    expect(result.status, BidAmendmentStatus.accepted);
  });
}
