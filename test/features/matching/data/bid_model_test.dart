import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _fullJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'senderName': 'Amadou Diallo',
  'senderPhone': '+33612345678',
  'weightKg': 5.0,
  'declaredValueEur': 200.0,
  'description': 'Vêtements',
  'contentCategory': 'CLOTHING',
  'recipientName': 'Fatou Sow',
  'recipientPhone': '+22177000000',
  'status': 'ACCEPTED',
  'rejectionReason': null,
  'handoverLocation': 'Gare du Nord',
  'handoverWindowStart': '2024-06-01T10:00:00.000Z',
  'handoverWindowEnd': '2024-06-01T12:00:00.000Z',
  'voyageurConfirmed': true,
  'disclaimerSignedAt': '2024-05-15T08:00:00.000Z',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-15T00:00:00.000Z',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01T00:00:00.000Z',
  'departureTime': '10:00',
  'arrivalTime': '20:00',
  'pricePerKg': 12.0,
  'trackingNumber': 'DON-ABC123',
  'trackingToken': 'tok_xyz',
  'confirmationCode': '4721',
  'travelerId': 'trav-001',
  'travelerName': 'Ibrahima Ba',
  'travelerPhone': '+33698765432',
};

final _minimalJson = {
  'id': 'bid-002',
  'announcementId': 'ann-002',
  'senderId': 'sender-002',
  'weightKg': 3,
  'declaredValueEur': 50,
  'description': 'Produits cosmétiques',
  'status': 'PENDING',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

void main() {
  group('BidModel.fromJson', () {
    test('parses all fields from full JSON', () {
      final model = BidModel.fromJson(_fullJson);
      expect(model.id, 'bid-001');
      expect(model.announcementId, 'ann-001');
      expect(model.senderId, 'sender-001');
      expect(model.senderName, 'Amadou Diallo');
      expect(model.senderPhone, '+33612345678');
      expect(model.weightKg, 5.0);
      expect(model.declaredValueEur, 200.0);
      expect(model.description, 'Vêtements');
      expect(model.contentCategory, 'CLOTHING');
      expect(model.recipientName, 'Fatou Sow');
      expect(model.recipientPhone, '+22177000000');
      expect(model.status, 'ACCEPTED');
      expect(model.handoverLocation, 'Gare du Nord');
      expect(model.handoverWindowStart, isNotNull);
      expect(model.handoverWindowEnd, isNotNull);
      expect(model.voyageurConfirmed, isTrue);
      expect(model.disclaimerSignedAt, isNotNull);
      expect(model.departureCity, 'Paris');
      expect(model.arrivalCity, 'Dakar');
      expect(model.departureDate, isNotNull);
      expect(model.departureTime, '10:00');
      expect(model.arrivalTime, '20:00');
      expect(model.pricePerKg, 12.0);
      expect(model.trackingNumber, 'DON-ABC123');
      expect(model.trackingToken, 'tok_xyz');
      expect(model.confirmationCode, '4721');
      expect(model.travelerId, 'trav-001');
      expect(model.travelerName, 'Ibrahima Ba');
      expect(model.travelerPhone, '+33698765432');
    });

    test('handles minimal JSON with all optionals null/absent', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.id, 'bid-002');
      expect(model.senderName, isNull);
      expect(model.senderPhone, isNull);
      expect(model.contentCategory, isNull);
      expect(model.recipientName, isNull);
      expect(model.recipientPhone, isNull);
      expect(model.handoverLocation, isNull);
      expect(model.handoverWindowStart, isNull);
      expect(model.handoverWindowEnd, isNull);
      expect(model.voyageurConfirmed, isFalse);
      expect(model.disclaimerSignedAt, isNull);
      expect(model.departureCity, isNull);
      expect(model.arrivalCity, isNull);
      expect(model.departureDate, isNull);
      expect(model.trackingNumber, isNull);
      expect(model.confirmationCode, isNull);
    });

    test('weightKg parsed from int', () {
      final model = BidModel.fromJson({..._minimalJson, 'weightKg': 5});
      expect(model.weightKg, 5.0);
    });

    test('declaredValueEur parsed from int', () {
      final model = BidModel.fromJson({..._minimalJson, 'declaredValueEur': 100});
      expect(model.declaredValueEur, 100.0);
    });
  });

  group('BidModel.toJson', () {
    test('serializes full model back to JSON', () {
      final model = BidModel.fromJson(_fullJson);
      final json = model.toJson();
      expect(json['id'], 'bid-001');
      expect(json['weightKg'], 5.0);
      expect(json['voyageurConfirmed'], isTrue);
      expect(json['handoverWindowStart'], isNotNull);
      expect(json['disclaimerSignedAt'], isNotNull);
      expect(json['departureDate'], isNotNull);
    });

    test('serializes model with null optional fields', () {
      final model = BidModel.fromJson(_minimalJson);
      final json = model.toJson();
      expect(json['senderName'], isNull);
      expect(json['handoverWindowStart'], isNull);
      expect(json['handoverWindowEnd'], isNull);
      expect(json['disclaimerSignedAt'], isNull);
      expect(json['departureDate'], isNull);
    });
  });

  group('BidModel.commissionStatus', () {
    test('parses REFUND_FAILED without throwing', () {
      final model = BidModel.fromJson({
        ..._minimalJson,
        'commissionStatus': 'REFUND_FAILED',
      });
      expect(model.commissionStatus, CommissionStatus.refundFailed);
    });

    test('null commissionStatus stays null', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.commissionStatus, isNull);
    });
  });

  group('BidModel.skeleton', () {
    test('creates skeleton with given id', () {
      final s = BidModel.skeleton('bid-deep');
      expect(s.id, 'bid-deep');
      expect(s.senderId, isEmpty);
      expect(s.isSkeleton, isTrue);
    });

    test('non-skeleton bid returns isSkeleton false', () {
      final model = BidModel.fromJson(_fullJson);
      expect(model.isSkeleton, isFalse);
    });
  });

  group('BidModel.resolvedSenderName', () {
    test('returns senderName when set', () {
      final model = BidModel.fromJson(_fullJson);
      expect(model.resolvedSenderName, 'Amadou Diallo');
    });

    test('returns senderPhone when senderName is null', () {
      final model = BidModel.fromJson({
        ..._minimalJson,
        'senderPhone': '+221700000001',
      });
      expect(model.resolvedSenderName, '+221700000001');
    });

    test('returns "Expéditeur" when both null', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.resolvedSenderName, 'Expéditeur');
    });
  });
}
