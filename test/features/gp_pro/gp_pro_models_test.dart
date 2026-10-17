import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lecture des champs GP Pro : clé `gpPro` seule, les anciennes clés Kilo Pro
/// ne sont plus lues (les titulaires de Kilo Pro perdent le badge).
void main() {
  group('TravelerProfile.gpPro', () {
    const base = {'id': 'tp-1'};
    test('lu, absent = false, ancienne clé ignorée', () {
      expect(TravelerProfile.fromJson({...base, 'gpPro': true}).gpPro, isTrue);
      expect(TravelerProfile.fromJson(base).gpPro, isFalse);
      expect(
        TravelerProfile.fromJson({...base, 'kiloPro': true}).gpPro,
        isFalse,
      );
    });
    test('toJson écrit gpPro', () {
      final out = TravelerProfile.fromJson({...base, 'gpPro': true}).toJson();
      expect(out['gpPro'], isTrue);
      expect(out.containsKey('kiloPro'), isFalse);
    });
  });

  group('BidModel.senderGpPro / travelerGpPro', () {
    const base = {
      'id': 'b',
      'announcementId': 'a',
      'senderId': 's',
      'weightKg': 3,
      'description': 'd',
      'status': 'PENDING',
      'createdAt': '2024-05-01T00:00:00.000Z',
      'updatedAt': '2024-05-01T00:00:00.000Z',
    };
    test('lus', () {
      final b = BidModel.fromJson({
        ...base,
        'senderGpPro': true,
        'travelerGpPro': true,
      });
      expect(b.senderGpPro, isTrue);
      expect(b.travelerGpPro, isTrue);
    });
    test('absents = false, anciennes clés ignorées', () {
      final b = BidModel.fromJson({
        ...base,
        'senderKiloPro': true,
        'travelerKiloPro': true,
      });
      expect(b.senderGpPro, isFalse);
      expect(b.travelerGpPro, isFalse);
    });
  });

  group('ProfilePublicModel.gpPro', () {
    test('lu, absent = false, isKiloPro ignoré', () {
      expect(ProfilePublicModel.fromJson({'gpPro': true}).gpPro, isTrue);
      expect(ProfilePublicModel.fromJson({}).gpPro, isFalse);
      expect(ProfilePublicModel.fromJson({'isKiloPro': true}).gpPro, isFalse);
    });
  });

  group('ParticipantModel.gpPro', () {
    const base = {'id': 'p', 'name': 'N'};
    test('lu, absent = false, kiloPro ignoré', () {
      expect(ParticipantModel.fromJson({...base, 'gpPro': true}).gpPro, isTrue);
      expect(ParticipantModel.fromJson(base).gpPro, isFalse);
      expect(
        ParticipantModel.fromJson({...base, 'kiloPro': true}).gpPro,
        isFalse,
      );
    });
  });

  group('SenderPublicProfile.gpPro', () {
    const base = {
      'id': 's',
      'displayName': 'N',
      'averageRating': 4.0,
      'totalRatings': 2,
      'kycVerified': true,
    };
    test('lu, absent = false, ancienne clé ignorée', () {
      expect(
        SenderPublicProfile.fromJson(const {...base, 'gpPro': true}).gpPro,
        isTrue,
      );
      expect(SenderPublicProfile.fromJson(base).gpPro, isFalse);
      expect(
        SenderPublicProfile.fromJson(const {...base, 'kiloPro': true}).gpPro,
        isFalse,
      );
    });
    test('guest = false et props distinguent gpPro', () {
      expect(SenderPublicProfile.guest('x').gpPro, isFalse);
      expect(
        SenderPublicProfile.fromJson(const {...base, 'gpPro': true}),
        isNot(SenderPublicProfile.fromJson(base)),
      );
    });
  });

  group('NegotiationThread.travelerGpPro / senderGpPro', () {
    const base = {
      'id': 't-1',
      'packageRequestId': 'pr-1',
      'travelerId': 'tr-1',
      'travelerTravelDate': '2026-06-15',
      'travelerAvailableKg': 10.0,
      'status': 'OPEN',
      'currentPriceEur': 30.0,
      'roundsCount': 1,
      'lastActivityAt': '2026-05-10T10:00:00Z',
      'createdAt': '2026-05-10T10:00:00Z',
    };
    test('lus', () {
      final t = NegotiationThread.fromJson(const {
        ...base,
        'travelerGpPro': true,
        'senderGpPro': true,
      });
      expect(t.travelerGpPro, isTrue);
      expect(t.senderGpPro, isTrue);
      expect(t, isNot(NegotiationThread.fromJson(base)));
    });
    test('absents = false, anciennes clés ignorées', () {
      final t = NegotiationThread.fromJson(const {
        ...base,
        'travelerKiloPro': true,
        'senderKiloPro': true,
      });
      expect(t.travelerGpPro, isFalse);
      expect(t.senderGpPro, isFalse);
    });
  });

  group('BidNegotiation.counterpartyGpPro', () {
    const base = {'bidId': 'b', 'announcementId': 'a', 'status': 'NEGOTIATING'};
    test('lu, absent = false, ancienne clé ignorée', () {
      expect(
        BidNegotiation.fromJson({
          ...base,
          'counterpartyGpPro': true,
        }).counterpartyGpPro,
        isTrue,
      );
      expect(BidNegotiation.fromJson(base).counterpartyGpPro, isFalse);
      expect(
        BidNegotiation.fromJson({
          ...base,
          'counterpartyKiloPro': true,
        }).counterpartyGpPro,
        isFalse,
      );
    });
  });
}
