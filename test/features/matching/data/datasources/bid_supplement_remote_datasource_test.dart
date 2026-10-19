import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/features/matching/data/datasources/bid_supplement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/recording_dio.dart';

const _bidId = '550e8400-e29b-41d4-a716-446655440000';

Map<String, dynamic> _supplement(String status) => {
  'id': 'sup-1',
  'status': status,
  'currency': 'EUR',
  'grossAmount': 16.8,
  'blocksHandover': status == 'PROPOSED',
};

void main() {
  late RecordingApi api;
  late BidSupplementRemoteDatasource datasource;

  setUp(() {
    api = RecordingApi();
    datasource = BidSupplementRemoteDatasource(api.client);
  });

  test('options : GET /bids/{id}/supplements/options', () async {
    api.on('GET', '/bids/$_bidId/supplements/options', {
      'currency': 'EUR',
      'minNet': 1,
      'maxNet': 300,
      'suggestions': [
        {'kind': 'KG', 'unitNet': 8},
      ],
      'rail': 'STRIPE',
    });

    final options = await datasource.options(_bidId);

    expect(api.last.method, 'GET');
    expect(options.maxNet, 300);
    expect(options.suggestions.single.unitNet, 8);
  });

  test('quote : POST /bids/{id}/supplements/quote avec le net', () async {
    api.on('POST', '/bids/$_bidId/supplements/quote', {
      'netAmount': 20,
      'commissionAmount': 2.4,
      'grossAmount': 22.4,
      'currency': 'EUR',
    });

    final quote = await datasource.quote(_bidId, 20);

    expect(api.last.data, {'netAmount': 20.0});
    expect(quote.grossAmount, 22.4);
  });

  test('create : corps complet, texte et article rognés', () async {
    api.on(
      'POST',
      '/bids/$_bidId/supplements',
      _supplement('PROPOSED'),
      status: 201,
    );

    final created = await datasource.create(
      _bidId,
      netAmount: 15,
      reason: BidSupplementReason.gridItem,
      reasonText: '  Un téléphone  ',
      gridItemLabel: ' Téléphone ',
      photoKey: 'tracking/$_bidId/x.jpg',
    );

    expect(api.last.method, 'POST');
    expect(api.last.data, {
      'netAmount': 15.0,
      'reasonCode': 'GRID_ITEM',
      'reasonText': 'Un téléphone',
      'gridItemLabel': 'Téléphone',
      'photoKey': 'tracking/$_bidId/x.jpg',
    });
    expect(created.status, BidSupplementStatus.proposed);
    expect(created.blocksHandover, isTrue);
  });

  test('create : texte et article vides omis', () async {
    api.on('POST', '/bids/$_bidId/supplements', _supplement('PROPOSED'));

    await datasource.create(
      _bidId,
      netAmount: 5,
      reason: BidSupplementReason.extraWeight,
      reasonText: '   ',
      photoKey: 'tracking/$_bidId/y.jpg',
    );

    expect(api.last.data, {
      'netAmount': 5.0,
      'reasonCode': 'EXTRA_WEIGHT',
      'photoKey': 'tracking/$_bidId/y.jpg',
    });
  });

  test(
    'create espèces : source de commission et devise de complément',
    () async {
      api.on('POST', '/bids/$_bidId/supplements', {
        ..._supplement('COMMISSION_PENDING'),
        'rail': 'CASH',
        'commissionStatus': 'REQUIRES_3DS',
        'commissionClientSecret': 'pi_c_secret_1',
      }, status: 201);

      final created = await datasource.create(
        _bidId,
        netAmount: 5,
        reason: BidSupplementReason.extraWeight,
        photoKey: 'tracking/$_bidId/y.jpg',
        commissionSource: SupplementCommissionSource.card,
        fundingCurrency: ' xof ',
      );

      expect(api.last.data, {
        'netAmount': 5.0,
        'reasonCode': 'EXTRA_WEIGHT',
        'photoKey': 'tracking/$_bidId/y.jpg',
        'commissionSource': 'CARD',
        'fundingCurrency': 'XOF',
      });
      expect(created.status, BidSupplementStatus.commissionPending);
      expect(created.isCash, isTrue);
      expect(created.commissionClientSecret, 'pi_c_secret_1');
      expect(created.needsCommissionAuth, isTrue);
    },
  );

  test('create : devise de complément vide omise', () async {
    api.on('POST', '/bids/$_bidId/supplements', _supplement('PROPOSED'));

    await datasource.create(
      _bidId,
      netAmount: 5,
      reason: BidSupplementReason.extraWeight,
      photoKey: 'k',
      commissionSource: SupplementCommissionSource.wallet,
      fundingCurrency: '  ',
    );

    expect(api.last.data, {
      'netAmount': 5.0,
      'reasonCode': 'EXTRA_WEIGHT',
      'photoKey': 'k',
      'commissionSource': 'WALLET_FIRST',
    });
  });

  test(
    'confirmCommission : POST …/{supplementId}/commission/confirm',
    () async {
      api.on('POST', '/bids/$_bidId/supplements/sup-1/commission/confirm', {
        ..._supplement('PROPOSED'),
        'rail': 'CASH',
        'commissionStatus': 'CHARGED',
      });

      final s = await datasource.confirmCommission(_bidId, 'sup-1');

      expect(api.last.method, 'POST');
      expect(s.status, BidSupplementStatus.proposed);
      expect(s.commissionCharged, isTrue);
      expect(s.commissionClientSecret, isNull);
    },
  );

  test('current : supplément de la fiche du colis, ou null', () async {
    api.on('GET', '/bids/$_bidId', {
      'id': _bidId,
      'supplement': _supplement('COMMISSION_PENDING'),
    });
    final s = await datasource.current(_bidId);
    expect(api.last.method, 'GET');
    expect(s?.status, BidSupplementStatus.commissionPending);

    api.on('GET', '/bids/$_bidId', {'id': _bidId});
    expect(await datasource.current(_bidId), isNull);
  });

  test('withdraw : DELETE /bids/{id}/supplements/{supplementId}', () async {
    api.on(
      'DELETE',
      '/bids/$_bidId/supplements/sup-1',
      _supplement('WITHDRAWN'),
    );

    final s = await datasource.withdraw(_bidId, 'sup-1');

    expect(api.last.method, 'DELETE');
    expect(s.status, BidSupplementStatus.withdrawn);
  });

  test(
    'decline : POST /bids/{id}/supplements/{supplementId}/decline',
    () async {
      api.on(
        'POST',
        '/bids/$_bidId/supplements/sup-1/decline',
        _supplement('DECLINED'),
      );

      final s = await datasource.decline(_bidId, 'sup-1');

      expect(api.last.method, 'POST');
      expect(s.status, BidSupplementStatus.declined);
    },
  );

  test('uploadPhoto : multipart vers /storage/upload/tracking', () async {
    final dir = await Directory.systemTemp.createTemp('supplement');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    api.on('POST', '/storage/upload/tracking', {
      'key': 'tracking/$_bidId/supplement.jpg',
    });

    final key = await datasource.uploadPhoto(_bidId, file.path);

    expect(key, 'tracking/$_bidId/supplement.jpg');
    final form = api.last.data as FormData;
    expect(
      form.fields.map((f) => '${f.key}=${f.value}'),
      contains('bidId=$_bidId'),
    );
    expect(form.files.single.value.filename, 'supplement.jpg');
  });

  test('accept : POST …/accept, contrat de checkout carte', () async {
    api.on('POST', '/bids/$_bidId/supplements/sup-1/accept', {
      'supplement': _supplement('PAYMENT_PENDING'),
      'rail': 'STRIPE',
      'clientSecret': 'pi_1_secret_2',
      'paymentMethodTypes': ['card', 'paypal'],
      'amount': 16.8,
      'currency': 'EUR',
      'publishableKey': 'pk_test',
    });

    final checkout = await datasource.accept(_bidId, 'sup-1');

    expect(api.last.method, 'POST');
    expect(api.last.data, isNull);
    expect(checkout.isCard, isTrue);
    expect(checkout.needsPayment, isTrue);
    expect(checkout.clientSecret, 'pi_1_secret_2');
    expect(checkout.paymentMethodTypes, ['card', 'paypal']);
    expect(checkout.amount, 16.8);
    expect(checkout.currency, 'EUR');
    expect(checkout.publishableKey, 'pk_test');
    expect(checkout.supplement!.status, BidSupplementStatus.paymentPending);
  });

  test(
    'accept : déjà payé, clientSecret nul, montant repris du supplément',
    () async {
      api.on('POST', '/bids/$_bidId/supplements/sup-1/accept', {
        'supplement': {..._supplement('PAID'), 'currency': 'XOF'},
        'rail': 'STRIPE',
        'clientSecret': null,
      });

      final checkout = await datasource.accept(_bidId, 'sup-1');

      expect(checkout.needsPayment, isFalse);
      expect(checkout.paymentMethodTypes, isEmpty);
      expect(checkout.amount, 16.8);
      expect(checkout.currency, 'XOF');
      expect(checkout.publishableKey, isNull);
    },
  );

  test('accept : réponse minimale sans supplément', () {
    final checkout = SupplementCheckout.fromJson({
      'rail': 'PAWAPAY',
      'clientSecret': '',
    });
    expect(checkout.supplement, isNull);
    expect(checkout.isCard, isFalse);
    expect(checkout.needsPayment, isFalse);
    expect(checkout.amount, 0);
    expect(checkout.currency, 'EUR');
  });

  test('confirmPayment : POST …/confirm-payment', () async {
    api.on(
      'POST',
      '/bids/$_bidId/supplements/sup-1/confirm-payment',
      _supplement('PAID'),
    );

    final s = await datasource.confirmPayment(_bidId, 'sup-1');

    expect(api.last.method, 'POST');
    expect(s.status, BidSupplementStatus.paid);
  });
}
