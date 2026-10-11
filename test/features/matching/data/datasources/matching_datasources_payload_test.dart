import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/traveler_bids_page.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/recording_dio.dart';

const _bidJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'weightKg': 5.0,
  'description': 'Vêtements',
  'status': 'PENDING',
  'voyageurConfirmed': false,
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

const _announcementJson = {
  'id': 'ann-001',
  'travelerId': 'trav-001',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01T00:00:00.000Z',
  'availableKg': 10.0,
  'totalKg': 10.0,
  'pricePerKg': 12.0,
  'status': 'OPEN',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

const _pickup = AddressData(label: 'CDG', lat: 49.0, lng: 2.5);
const _delivery = AddressData(label: 'AIBD', lat: 14.7, lng: -17.4);

void main() {
  late RecordingApi api;

  setUp(() => api = RecordingApi());

  group('BidRemoteDatasource', () {
    late BidRemoteDatasource ds;

    setUp(() => ds = BidRemoteDatasource(api.client));

    test(
      'uploadBidPhoto envoie le fichier en multipart et rend la clé',
      () async {
        final dir = Directory.systemTemp.createTempSync('bid_photo');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/c.jpg')..writeAsBytesSync([9, 9]);
        api.on('POST', '/bids/photos', {'key': 'bids/k1.jpg'});

        expect(await ds.uploadBidPhoto(file.path), 'bids/k1.jpg');
        final form = api.last.data as FormData;
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'colis.jpg');
      },
    );

    test('checkoutBid ajoute photoKeys et gridItems quand fournis', () async {
      api.on('POST', '/bids/checkout', {
        'bidId': 'bid-001',
        'clientSecret': 'pi_secret',
        'publishableKey': 'pk',
        'expiresAt': '2026-06-01T10:00:00Z',
      });
      final checkout = await ds.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 0,
        description: 'd',
        contentCategory: 'CLOTHING',
        recipientName: 'Awa',
        recipientPhone: '+221',
        photoKeys: const ['k1'],
        gridItems: const [
          {'size': 'S', 'qty': 1},
        ],
      );
      expect(checkout.bidId, 'bid-001');
      expect(checkout.currency, 'EUR');
      final body = api.last.data as Map<String, dynamic>;
      expect(body['photoKeys'], ['k1']);
      expect(body['gridItems'], [
        {'size': 'S', 'qty': 1},
      ]);
      expect(body.containsKey('weightKg'), isFalse);
      expect(body['disclaimerSigned'], isTrue);
    });

    test(
      'createBid normalise le code promo et ajoute les optionnels',
      () async {
        api.on('POST', '/announcements/ann-001/bids', _bidJson);
        final bid = await ds.createBid(
          announcementId: 'ann-001',
          weightKg: 2,
          description: 'd',
          contentCategory: 'FOOD',
          recipientName: 'Awa',
          recipientPhone: '+221',
          paymentMethod: BidPaymentMethod.wave,
          phoneNumber: '+221770000000',
          countryCode: 'SN',
          promoCode: ' bienvenue ',
          photoKeys: const ['k1', 'k2'],
          gridItems: const [
            {'size': 'M'},
          ],
        );
        expect(bid.id, 'bid-001');
        final body = api.last.data as Map<String, dynamic>;
        expect(body['paymentMethod'], 'WAVE');
        expect(body['weightKg'], 2);
        expect(body['phoneNumber'], '+221770000000');
        expect(body['countryCode'], 'SN');
        expect(body['promoCode'], 'BIENVENUE');
        expect(body['photoKeys'], ['k1', 'k2']);
        expect(body['gridItems'], [
          {'size': 'M'},
        ]);
      },
    );

    test('createBid omet les optionnels absents et le promo vide', () async {
      api.on('POST', '/announcements/ann-001/bids', _bidJson);
      await ds.createBid(
        announcementId: 'ann-001',
        weightKg: 0,
        description: 'd',
        contentCategory: 'FOOD',
        recipientName: 'Awa',
        recipientPhone: '+221',
        promoCode: '',
        photoKeys: const [],
      );
      final body = api.last.data as Map<String, dynamic>;
      expect(
        body.keys,
        isNot(
          anyOf(
            contains('weightKg'),
            contains('promoCode'),
            contains('photoKeys'),
            contains('phoneNumber'),
          ),
        ),
      );
      expect(body['paymentMethod'], 'STRIPE');
    });

    test('getCounterpartyPhone lit le numéro, null si absent', () async {
      api.on('GET', '/bids/bid-001/contact', {'phoneNumber': '+33600000000'});
      expect(await ds.getCounterpartyPhone('bid-001'), '+33600000000');
      api.on('GET', '/bids/bid-002/contact', <String, dynamic>{});
      expect(await ds.getCounterpartyPhone('bid-002'), isNull);
    });

    test('getTravelerBids envoie la pagination et lit la page', () async {
      api.on('GET', '/travelers/me/bids', {
        'content': [_bidJson],
        'number': 2,
        'last': false,
      });
      final page = await ds.getTravelerBids(page: 2, size: 5);
      expect(api.last.queryParameters, {'page': 2, 'size': 5});
      expect(page.content.single.id, 'bid-001');
      expect(page.page, 2);
      expect(page.isLast, isFalse);
    });

    test('TravelerBidsPage : valeurs par défaut et égalité', () {
      final empty = TravelerBidsPage.fromJson(const {});
      expect(empty.content, isEmpty);
      expect(empty.page, 0);
      expect(empty.isLast, isTrue);
      expect(empty, const TravelerBidsPage(content: [], page: 0, isLast: true));
    });

    test('cancelBeforePayment lit alreadyCancelled', () async {
      api.on('POST', '/bids/b1/cancel-before-payment', {
        'alreadyCancelled': true,
      });
      expect(await ds.cancelBeforePayment('b1'), isTrue);
      api.on('POST', '/bids/b2/cancel-before-payment', null, status: 204);
      expect(await ds.cancelBeforePayment('b2'), isFalse);
    });

    test('confirmCommissionAcceptance rend le corps d’un 422', () async {
      api.on('POST', '/bids/b1/confirm-acceptance', {
        'accepted': false,
        'error': 'card_declined',
      }, status: 422);
      final r = await ds.confirmCommissionAcceptance('b1');
      expect(r.accepted, isFalse);
      expect(r.error, 'card_declined');
    });

    test('confirmCommissionAcceptance relance les autres erreurs', () async {
      api.on('POST', '/bids/b1/confirm-acceptance', {'x': 1}, status: 500);
      await expectLater(
        ds.confirmCommissionAcceptance('b1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('AnnouncementRemoteDatasource', () {
    late AnnouncementRemoteDatasource ds;

    setUp(() => ds = AnnouncementRemoteDatasource(api.client));

    test('publishAnnouncement poste /publish', () async {
      api.on('POST', '/announcements/ann-001/publish', _announcementJson);
      final a = await ds.publishAnnouncement('ann-001');
      expect(a.id, 'ann-001');
      expect(api.last.method, 'POST');
    });

    test(
      'getTripsSummary envoie la période et lit les anciens champs',
      () async {
        api.on('GET', '/travelers/me/trips-summary', {
          'activeTrips': 2,
          'kgSoldThisMonth': 12,
          'revenueThisMonth': 96.5,
          'revenueConverted': true,
        });
        final s = await ds.getTripsSummary(period: '30d');
        expect(api.last.queryParameters, {'period': '30d'});
        expect(s.activeTrips, 2);
        expect(s.kgSold, 12.0);
        expect(s.revenue, 96.5);
        expect(s.isRevenueConverted, isTrue);
      },
    );

    test('searchAnnouncements envoie tous les filtres numériques', () async {
      api.on('GET', '/announcements', {
        'content': <dynamic>[],
        'totalElements': 0,
      });
      await ds.searchAnnouncements(
        maxAvailableKg: 30,
        maxPricePerKg: 15,
        minRating: 4,
        transportMode: TransportMode.car,
        contentType: 'FOOD',
      );
      final q = api.last.queryParameters;
      expect(q['maxAvailableKg'], 30.0);
      expect(q['maxPricePerKg'], 15.0);
      expect(q['minRating'], 4.0);
      expect(q['transportMode'], 'CAR');
      expect(q['contentType'], 'FOOD');
      expect(q['size'], 20);
    });

    test(
      'updateAnnouncement envoie arrivalDate, description et unité',
      () async {
        api.on('PUT', '/announcements/ann-001', _announcementJson);
        await ds.updateAnnouncement(
          id: 'ann-001',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 6),
          arrivalDate: '2026-06-02',
          pickupAddress: _pickup,
          deliveryAddress: _delivery,
          availableKg: 10,
          pricePerKg: 8,
          transportMode: TransportMode.plane,
          description: 'Vol direct',
          capacityUnit: 'PIECE',
          handoverDeadline: DateTime.utc(2026, 5, 31, 18),
        );
        final body = api.last.data as Map<String, dynamic>;
        expect(body['departureDate'], '2026-06-01');
        expect(body['arrivalDate'], '2026-06-02');
        expect(body['description'], 'Vol direct');
        expect(body['capacityUnit'], 'PIECE');
        expect(body['handoverDeadline'], '2026-05-31T18:00:00.000Z');
      },
    );

    test('updateAnnouncement omet une description vide', () async {
      api.on('PUT', '/announcements/ann-001', _announcementJson);
      await ds.updateAnnouncement(
        id: 'ann-001',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 6),
        pickupAddress: _pickup,
        deliveryAddress: _delivery,
        availableKg: 10,
        pricePerKg: 8,
        transportMode: TransportMode.plane,
        description: '',
        handoverDeadline: DateTime.utc(2026, 5, 31),
      );
      final body = api.last.data as Map<String, dynamic>;
      expect(body.containsKey('description'), isFalse);
      expect(body.containsKey('capacityUnit'), isFalse);
      expect(body.containsKey('arrivalDate'), isFalse);
    });

    test('rescheduleTrip envoie le report et lit le résultat', () async {
      api.on('POST', '/announcements/ann-001/reschedule', {
        'rescheduleId': 'rs-1',
        'rescheduleCount': 1,
        'remainingReschedules': 1,
        'parcelsAwaitingDecision': 3,
        'requestsInformed': 2,
      });
      final r = await ds.rescheduleTrip(
        announcementId: 'ann-001',
        departureDate: DateTime(2026, 6, 3),
        departureTime: '10:30',
        arrivalDate: '2026-06-03',
        arrivalTime: '18:00',
        handoverDeadline: DateTime.utc(2026, 6, 2, 20),
        reason: TripRescheduleReason.flightCancelled,
        note: '  Vol annulé  ',
      );
      expect(r.rescheduleId, 'rs-1');
      expect(r.parcelsAwaitingDecision, 3);
      expect(r.requestsInformed, 2);
      expect(api.last.data, {
        'departureDate': '2026-06-03',
        'departureTime': '10:30',
        'arrivalDate': '2026-06-03',
        'arrivalTime': '18:00',
        'handoverDeadline': '2026-06-02T20:00:00.000Z',
        'reason': 'FLIGHT_CANCELLED',
        'note': 'Vol annulé',
      });
    });

    test('rescheduleTrip omet une note blanche', () async {
      api.on('POST', '/announcements/ann-001/reschedule', {
        'rescheduleId': 'rs-2',
      });
      final r = await ds.rescheduleTrip(
        announcementId: 'ann-001',
        departureDate: DateTime(2026, 6, 3),
        departureTime: '10:30',
        handoverDeadline: DateTime.utc(2026, 6, 2),
        reason: TripRescheduleReason.other,
        note: '   ',
      );
      expect(r.rescheduleCount, 0);
      expect(r.remainingReschedules, 0);
      final body = api.last.data as Map<String, dynamic>;
      expect(body.containsKey('note'), isFalse);
      expect(body.containsKey('arrivalTime'), isFalse);
      expect(TripRescheduleReason.fromWire('POSTPONED'), isNotNull);
      expect(TripRescheduleReason.fromWire('???'), isNull);
    });
  });
}
