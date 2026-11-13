// Réservation au m³ (lot 3, A4) : dimensions du colis, requêtes devis /
// checkout / offre, règle « versé au dépôt ».

import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_volume_input.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/payout_wording.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

const _bidJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'status': 'PENDING',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

const _quoteJson = {
  'netEur': 100.0,
  'rate': 0.05,
  'commissionEur': 5.0,
  'totalEur': 105.0,
  'promoApplied': false,
};

void main() {
  tearDown(resetTransportModesForTest);

  group('BidVolumeInput', () {
    test('trois dimensions valides : volume du serveur (L × l × h / 10^6)', () {
      final v = BidVolumeInput.tryCreate(100, 50, 40)!;
      expect(v.volumeM3, 0.2);
      expect(BidVolumeInput.tryCreate(30, 30, 30)!.volumeM3, 0.027);
    });

    test('minimum 0,001 m³', () {
      expect(BidVolumeInput.tryCreate(1, 1, 1)!.volumeM3, 0.001);
    });

    test('une dimension manquante ou hors bornes : aucune entrée', () {
      expect(BidVolumeInput.tryCreate(null, 50, 40), isNull);
      expect(BidVolumeInput.tryCreate(100, 0, 40), isNull);
      expect(BidVolumeInput.tryCreate(100, 50, 401), isNull);
      expect(BidVolumeInput.tryCreate(400, 400, 400)!.volumeM3, 64);
    });

    test('égalité par valeur', () {
      expect(
        BidVolumeInput.tryCreate(1, 2, 3),
        BidVolumeInput.tryCreate(1, 2, 3),
      );
    });
  });

  group('requêtes (contrat BB2)', () {
    late RecordingApi api;
    late BidRepository bids;
    const volume = BidVolumeInput(lengthCm: 100, widthCm: 50, heightCm: 40);

    setUp(() {
      api = RecordingApi();
      bids = BidRepository(BidRemoteDatasource(api.client));
    });

    Map<String, dynamic> body() => api.last.data as Map<String, dynamic>;

    test('volumeRequestEntries : trois dimensions, jamais le volume', () {
      expect(volumeRequestEntries(volume), {
        'lengthCm': 100,
        'widthCm': 50,
        'heightCm': 40,
      });
      expect(volumeRequestEntries(null), isEmpty);
    });

    test('checkout : dimensions envoyées, aucun poids', () async {
      api.on('POST', '/bids/checkout', {
        'bidId': 'bid-001',
        'clientSecret': 'pi_secret',
        'publishableKey': 'pk',
        'expiresAt': '2026-06-01T10:00:00Z',
      });
      await bids.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 0,
        description: 'd',
        contentCategory: 'CLOTHING',
        recipientName: 'Awa',
        recipientPhone: '+221',
        volume: volume,
      );
      expect(body()['lengthCm'], 100);
      expect(body()['widthCm'], 50);
      expect(body()['heightCm'], 40);
      expect(body().containsKey('weightKg'), isFalse);
      expect(body().containsKey('volumeM3'), isFalse);
    });

    test('devis : dimensions envoyées', () async {
      api.on('POST', '/bids/quote', _quoteJson);
      await bids.quoteBid(announcementId: 'ann-001', volume: volume);
      expect(body()['lengthCm'], 100);
      expect(body()['heightCm'], 40);
      expect(body().containsKey('weightKg'), isFalse);
    });

    test('offre : dimensions envoyées', () async {
      api.on('POST', '/announcements/ann-001/bids', _bidJson, status: 201);
      await bids.createBid(
        announcementId: 'ann-001',
        weightKg: 0,
        description: 'd',
        contentCategory: 'CLOTHING',
        recipientName: 'Awa',
        recipientPhone: '+221',
        volume: volume,
      );
      expect(body()['widthCm'], 50);
      expect(body().containsKey('weightKg'), isFalse);
    });

    test('sans volume (avion, route, bateau au kilo) : aucune clé', () async {
      api.on('POST', '/bids/quote', _quoteJson);
      await bids.quoteBid(announcementId: 'ann-001', weightKg: 5);
      expect(body().containsKey('lengthCm'), isFalse);
      expect(body().containsKey('widthCm'), isFalse);
      expect(body().containsKey('heightCm'), isFalse);
      expect(body()['weightKg'], 5);
    });
  });

  group('paidAtDeposit', () {
    test('bateau allumé : versé au dépôt, seulement pour le bateau', () {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      expect(paidAtDeposit(TransportMode.boat), isTrue);
      expect(paidAtDeposit(TransportMode.plane), isFalse);
      expect(paidAtDeposit(TransportMode.car), isFalse);
      expect(paidAtDeposit(null), isFalse);
    });

    test('bateau éteint : jamais', () {
      expect(paidAtDeposit(TransportMode.boat), isFalse);
    });
  });
}
