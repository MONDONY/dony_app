import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _fullJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'senderName': 'Amadou Diallo',
  'senderPhoneAvailable': true,
  'weightKg': 5.0,
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
  'travelerPhoneAvailable': true,
};

final _minimalJson = {
  'id': 'bid-002',
  'announcementId': 'ann-002',
  'senderId': 'sender-002',
  'weightKg': 3,
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
      expect(model.senderPhoneAvailable, isTrue);
      expect(model.weightKg, 5.0);
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
      expect(model.travelerPhoneAvailable, isTrue);
    });

    test('handles minimal JSON with all optionals null/absent', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.id, 'bid-002');
      expect(model.senderName, isNull);
      expect(model.senderPhoneAvailable, isFalse);
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

    test('totalAmountEur lit la clé backend totalNetAmountEur (net voyageur)', () {
      // Régression : le backend expose le net sous `totalNetAmountEur`. Avant le
      // mapping, le champ restait null → "0 €"/"—" en mode grille (pricePerKg=0).
      final model = BidModel.fromJson({
        ..._minimalJson,
        'pricingMode': 'MIXED',
        'pricePerKg': 0,
        'totalNetAmountEur': 45.5,
      });
      expect(model.totalAmountEur, 45.5);
    });

    test('totalAmountEur null si la clé backend absente', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.totalAmountEur, isNull);
    });

    test(
      'totalSenderAmountEur (total payé expéditeur = net + commission) parsé',
      () {
        final model = BidModel.fromJson({
          ..._minimalJson,
          'totalNetAmountEur': 30.0,
          'totalSenderAmountEur': 33.60, // net 30 + commission 12%
        });
        expect(model.totalAmountEur, 30.0);
        expect(model.totalSenderAmountEur, 33.60);
      },
    );

    test('totalSenderAmountEur null si absent', () {
      expect(BidModel.fromJson(_minimalJson).totalSenderAmountEur, isNull);
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

    test(
      'returns "Expéditeur" when senderName is null (le numéro n\'est plus un repli)',
      () {
        final model = BidModel.fromJson({
          ..._minimalJson,
          'senderPhoneAvailable': true,
        });
        expect(model.resolvedSenderName, 'Expéditeur');
      },
    );

    test('returns "Expéditeur" when both null', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.resolvedSenderName, 'Expéditeur');
    });
  });

  group('BidModel.departureAt / resolvedDepartureAt', () {
    test('parses departureAt ISO string from JSON', () {
      final model = BidModel.fromJson({
        ..._minimalJson,
        'departureAt': '2026-07-01T10:00:00.000+02:00',
      });
      expect(
        model.departureAt,
        DateTime.parse('2026-07-01T10:00:00.000+02:00'),
      );
      expect(
        model.resolvedDepartureAt,
        DateTime.parse('2026-07-01T10:00:00.000+02:00'),
      );
    });

    test('resolvedDepartureAt fuses date + time when departureAt absent', () {
      final model = BidModel.fromJson({
        ..._minimalJson,
        'departureDate': '2026-07-01',
        'departureTime': '10:30',
      });
      expect(model.departureAt, isNull);
      expect(model.resolvedDepartureAt, DateTime(2026, 7, 1, 10, 30));
    });

    test(
      'resolvedDepartureAt is null when no departureAt and no departureTime',
      () {
        final model = BidModel.fromJson({
          ..._minimalJson,
          'departureDate': '2026-07-01',
        });
        expect(model.resolvedDepartureAt, isNull);
      },
    );
  });

  group('BidModel avatar URLs', () {
    test('parses senderAvatarUrl and travelerAvatarUrl when present', () {
      final model = BidModel.fromJson({
        ..._minimalJson,
        'senderAvatarUrl': 'https://cdn.dony.app/avatars/sender-1.jpg',
        'travelerAvatarUrl': 'https://cdn.dony.app/avatars/traveler-1.jpg',
      });
      expect(
        model.senderAvatarUrl,
        'https://cdn.dony.app/avatars/sender-1.jpg',
      );
      expect(
        model.travelerAvatarUrl,
        'https://cdn.dony.app/avatars/traveler-1.jpg',
      );
    });

    test('senderAvatarUrl and travelerAvatarUrl are null when absent', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.senderAvatarUrl, isNull);
      expect(model.travelerAvatarUrl, isNull);
    });

    test('toJson includes senderAvatarUrl and travelerAvatarUrl', () {
      final model = BidModel.fromJson({
        ..._minimalJson,
        'senderAvatarUrl': 'https://cdn.dony.app/avatars/sender-1.jpg',
        'travelerAvatarUrl': 'https://cdn.dony.app/avatars/traveler-1.jpg',
      });
      final json = model.toJson();
      expect(
        json['senderAvatarUrl'],
        'https://cdn.dony.app/avatars/sender-1.jpg',
      );
      expect(
        json['travelerAvatarUrl'],
        'https://cdn.dony.app/avatars/traveler-1.jpg',
      );
    });
  });

  group('BidModel.canCancelBeforeHandover', () {
    BidModel withStatus(String status) =>
        BidModel.fromJson({..._minimalJson, 'status': status});

    test('true pour PENDING (statut legacy)', () {
      expect(withStatus('PENDING').canCancelBeforeHandover, isTrue);
    });

    test('true pour PAYMENT_ESCROWED (payé, avant acceptation voyageur)', () {
      // Régression : après migration Stripe escrow, le statut post-paiement est
      // PAYMENT_ESCROWED et non PENDING. L'expéditeur doit pouvoir annuler.
      expect(withStatus('PAYMENT_ESCROWED').canCancelBeforeHandover, isTrue);
    });

    test('true pour ACCEPTED (voyageur a accepté, colis pas remis)', () {
      expect(withStatus('ACCEPTED').canCancelBeforeHandover, isTrue);
    });

    test('false pour AWAITING_PAYMENT (pas encore payé)', () {
      expect(withStatus('AWAITING_PAYMENT').canCancelBeforeHandover, isFalse);
    });

    test('false pour HANDED_OVER (relève de canCancelAfterHandover)', () {
      expect(withStatus('HANDED_OVER').canCancelBeforeHandover, isFalse);
    });

    test('false pour IN_TRANSIT / COMPLETED / CANCELLED / REJECTED', () {
      for (final status in [
        'IN_TRANSIT',
        'COMPLETED',
        'CANCELLED',
        'REJECTED',
      ]) {
        expect(
          withStatus(status).canCancelBeforeHandover,
          isFalse,
          reason: '$status ne doit pas être annulable avant remise',
        );
      }
    });
  });

  group('BidModel.canReportDeliveryNoShow', () {
    test('true si IN_TRANSIT, trajet parti, aucun signalement', () {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        departureAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(bid.canReportDeliveryNoShow, isTrue);
    });

    test('false si un signalement existe déjà', () {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        departureAt: DateTime.now().subtract(const Duration(days: 1)),
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
      );
      expect(bid.canReportDeliveryNoShow, isFalse);
    });

    test('false si le trajet n\'est pas encore parti', () {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        departureAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(bid.canReportDeliveryNoShow, isFalse);
    });

    test(
      'fromJson mappe deliveryNoShowStatus et deliveryNoShowContestationDeadline',
      () {
        final json = {
          'id': 'b1',
          'announcementId': 'a1',
          'senderId': 's1',
          'weightKg': 5.0,
          'status': 'IN_TRANSIT',
          'createdAt': '2026-01-01T00:00:00',
          'updatedAt': '2026-01-01T00:00:00',
          'deliveryNoShowStatus': 'CONTESTED',
          'deliveryNoShowContestationDeadline': '2026-07-16T10:00:00Z',
          'deliveryNoShowReportedByTraveler': true,
        };
        final bid = BidModel.fromJson(json);
        expect(bid.deliveryNoShowStatus, 'CONTESTED');
        expect(bid.deliveryNoShowContestationDeadline, isNotNull);
        expect(bid.deliveryNoShowReportedByTraveler, isTrue);
      },
    );
  });

  group('BidModel.tripCancellationId / tripCancellationRematchStatus', () {
    test(
      'fromJson mappe tripCancellationId et tripCancellationRematchStatus quand présents',
      () {
        final model = BidModel.fromJson({
          ..._minimalJson,
          'status': 'CANCELLED',
          'tripCancellationId': 'cancel-001',
          'tripCancellationRematchStatus': 'SUGGESTED',
        });
        expect(model.tripCancellationId, 'cancel-001');
        expect(model.tripCancellationRematchStatus, 'SUGGESTED');
      },
    );

    test(
      'tripCancellationId et tripCancellationRematchStatus null quand absents',
      () {
        final model = BidModel.fromJson(_minimalJson);
        expect(model.tripCancellationId, isNull);
        expect(model.tripCancellationRematchStatus, isNull);
      },
    );
  });

  group('BidModel.currency', () {
    test('fromJson mappe currency depuis le backend, pas toujours EUR', () {
      final model = BidModel.fromJson({..._minimalJson, 'currency': 'CAD'});
      expect(model.currency, 'CAD');
    });

    test('currency vaut EUR par défaut quand absent (ancien payload)', () {
      final model = BidModel.fromJson(_minimalJson);
      expect(model.currency, 'EUR');
    });
  });
}
