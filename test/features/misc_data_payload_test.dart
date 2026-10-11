import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_dio.dart';

const _userJson = {
  'id': 'user-123',
  'phoneNumber': '+33612345678',
  'roles': ['SENDER'],
  'kycStatus': 'PENDING',
  'status': 'ACTIVE',
};

const _threadJson = <String, dynamic>{
  'id': 'th-1',
  'packageRequestId': 'pr-1',
  'travelerId': 'trav-1',
  'travelerTravelDate': '2026-06-14T00:00:00Z',
  'travelerAvailableKg': 10,
  'status': 'OPEN',
  'currentPriceEur': 40,
  'roundsCount': 1,
  'lastActivityAt': '2026-05-11T10:00:00Z',
  'createdAt': '2026-05-11T09:00:00Z',
};

void main() {
  late RecordingApi api;

  setUp(() => api = RecordingApi());

  group('AuthRemoteDatasource', () {
    test('updateProfile envoie téléphone, bio et langues', () async {
      api.on('PATCH', '/auth/me', _userJson);
      final user = await AuthRemoteDatasource(api.client).updateProfile(
        phoneNumber: '+33600000000',
        bio: 'Voyageur régulier',
        languages: const ['fr', 'wo'],
      );
      expect(user.id, 'user-123');
      expect(api.last.data, {
        'phoneNumber': '+33600000000',
        'bio': 'Voyageur régulier',
        'languages': ['fr', 'wo'],
      });
    });

    test('uploadAvatar envoie avatar.jpg en multipart', () async {
      final dir = Directory.systemTemp.createTempSync('avatar');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2]);
      api.on('POST', '/auth/me/avatar', {
        ..._userJson,
        'avatarUrl': 'https://cdn/a.jpg',
      });

      final user = await AuthRemoteDatasource(
        api.client,
      ).uploadAvatar(file.path);

      expect(user.id, 'user-123');
      final form = api.last.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'avatar.jpg');
    });
  });

  group('BidRepository (délégation au datasource)', () {
    late BidRepository repo;

    setUp(() => repo = BidRepository(BidRemoteDatasource(api.client)));

    test('quoteBid normalise le promo et omet un poids nul', () async {
      api.on('POST', '/bids/quote', {
        'netEur': 40,
        'rate': 0.12,
        'commissionEur': 4.8,
        'totalEur': 44.8,
        'promoApplied': true,
        'promoLabel': '-10 %',
      });
      final quote = await repo.quoteBid(
        announcementId: 'ann-1',
        weightKg: 0,
        promoCode: ' noel ',
      );
      expect(quote.totalEur, 44.8);
      expect(quote.promoApplied, isTrue);
      expect(api.last.data, {'announcementId': 'ann-1', 'promoCode': 'NOEL'});
    });

    test(
      'getCounterpartyPhone, getTravelerBids et cancelBeforePayment',
      () async {
        api.on('GET', '/bids/b1/contact', {'phoneNumber': '+221'});
        api.on('GET', '/travelers/me/bids', {'content': <dynamic>[]});
        api.on('POST', '/bids/b1/cancel-before-payment', {
          'alreadyCancelled': false,
        });

        expect(await repo.getCounterpartyPhone('b1'), '+221');
        final page = await repo.getTravelerBids(page: 1);
        expect(page.content, isEmpty);
        expect(api.last.queryParameters, {'page': 1, 'size': 20});
        expect(await repo.cancelBeforePayment('b1'), isFalse);
      },
    );
  });

  group('CancellationRemoteDatasource', () {
    late CancellationRemoteDatasource ds;

    setUp(() => ds = CancellationRemoteDatasource(api.client));

    test('reportTravelerNoShow poste le signalement', () async {
      await ds.reportTravelerNoShow('b1');
      expect(api.last.method, 'POST');
      expect(api.last.path, '/cancellations/bids/b1/report-traveler-noshow');
    });

    test('decideReschedule envoie KEEP ou WITHDRAW', () async {
      await ds.decideReschedule('b1', keep: true);
      expect(api.last.path, '/cancellations/bids/b1/reschedule-decision');
      expect(api.last.data, {'decision': 'KEEP'});
      await ds.decideReschedule('b1', keep: false);
      expect(api.last.data, {'decision': 'WITHDRAW'});
    });
  });

  group('SupportRepository', () {
    late SupportRepository repo;

    setUp(() => repo = SupportRepository(api.client));

    test('loadReplies lit le catalogue', () async {
      api.on('GET', '/support/replies', [
        {'code': 'C1', 'category': 'PAY', 'question': 'Q', 'answer': 'R'},
      ]);
      final replies = await repo.loadReplies();
      expect(replies.single.code, 'C1');
      expect(replies.single.answer, 'R');
    });

    test('hideTicket appelle DELETE', () async {
      await repo.hideTicket('t1');
      expect(api.last.method, 'DELETE');
      expect(api.last.path, '/support/tickets/t1');
    });
  });

  group('NegotiationRepository', () {
    late NegotiationRepository repo;

    setUp(() => repo = NegotiationRepository(api.client));

    test('start envoie le trajet existant et le message', () async {
      api.on('POST', '/negotiations', _threadJson);
      final thread = await repo.start(
        packageRequestId: 'pr-1',
        proposedPriceEur: 40,
        travelerTravelDate: DateTime(2026, 6, 14),
        travelerAvailableKg: 10,
        travelerAnnouncementId: 'ann-9',
        body: 'Je pars samedi',
      );
      expect(thread.id, 'th-1');
      final body = api.last.data as Map<String, dynamic>;
      expect(body['travelerTravelDate'], '2026-06-14');
      expect(body['travelerAnnouncementId'], 'ann-9');
      expect(body['body'], 'Je pars samedi');
      expect(body.containsKey('dedicatedTrip'), isFalse);
    });

    test('createDedicatedTrip envoie les champs optionnels', () async {
      api.on('POST', '/negotiations/th-1/create-dedicated-trip', _threadJson);
      await repo.createDedicatedTrip(
        'th-1',
        departureDate: DateTime(2026, 6, 14),
        departureTime: '08:00',
        arrivalTime: '14:00',
        arrivalDate: '2026-06-14',
        pickupAddress: const {'label': 'CDG'},
        deliveryAddress: const {'label': 'AIBD'},
        description: 'Vol direct',
        acceptedContentTypes: const ['CLOTHING'],
        refusedTypes: const ['LIQUIDS'],
        paymentMethod: PaymentMethod.cash,
      );
      final body = api.last.data as Map<String, dynamic>;
      expect(body['departureDate'], '2026-06-14');
      expect(body['departureTime'], '08:00');
      expect(body['arrivalTime'], '14:00');
      expect(body['arrivalDate'], '2026-06-14');
      expect(body['description'], 'Vol direct');
      expect(body['acceptedContentTypes'], ['CLOTHING']);
      expect(body['refusedTypes'], ['LIQUIDS']);
      expect(body['paymentMethod'], 'CASH');
      expect(body['useCardForCommission'], isFalse);
    });

    test('changeTrip remplace le trajet lié', () async {
      api.on('PATCH', '/negotiations/th-1/trip', _threadJson);
      final thread = await repo.changeTrip(
        'th-1',
        travelerAnnouncementId: 'ann-2',
      );
      expect(thread.packageRequestId, 'pr-1');
      expect(api.last.data, {'travelerAnnouncementId': 'ann-2'});
    });
  });
}
