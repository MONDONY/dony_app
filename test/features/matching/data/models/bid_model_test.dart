import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _minimalBid() => {
  'id': 'bid1',
  'announcementId': 'ann1',
  'senderId': 'sender1',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
};

void main() {
  group('BidModel.arrivalInstructions', () {
    test('fromJson parses arrivalInstructions', () {
      final json = _minimalBid()
        ..['arrivalInstructions'] = 'Métro Châtelet, sortie 3';
      final model = BidModel.fromJson(json);
      expect(model.arrivalInstructions, 'Métro Châtelet, sortie 3');
    });

    test('arrivalInstructions absent → null', () {
      final model = BidModel.fromJson(_minimalBid());
      expect(model.arrivalInstructions, isNull);
    });

    test('round-trips arrivalInstructions through toJson', () {
      final json = _minimalBid()
        ..['arrivalInstructions'] = 'Métro Châtelet, sortie 3';
      final out = BidModel.fromJson(json).toJson();
      expect(out['arrivalInstructions'], 'Métro Châtelet, sortie 3');
    });
  });

  group('BidModel.recipientAppStatus (lot 2 destinataire)', () {
    test('fromJson lit le statut du lien et le renvoie en toJson', () {
      final json = _minimalBid()..['recipientAppStatus'] = 'CONFIRMED';
      final model = BidModel.fromJson(json);
      expect(model.recipientAppStatus, 'CONFIRMED');
      expect(model.toJson()['recipientAppStatus'], 'CONFIRMED');
    });

    test('ancien back sans le champ → null', () {
      expect(BidModel.fromJson(_minimalBid()).recipientAppStatus, isNull);
    });
  });

  group('BidModel.recipientDeclined (FLUTTER-E8, yadony-back #412)', () {
    test('ancien back sans les champs : false et null', () {
      final model = BidModel.fromJson(_minimalBid());
      expect(model.recipientDeclined, isFalse);
      expect(model.recipientReplacementRequestedAt, isNull);
      expect(model.nextRecipientReplacementAllowedAt, isNull);
    });

    test('fromJson lit le refus et la dernière demande (UTC)', () {
      final json = _minimalBid()
        ..['recipientDeclined'] = true
        ..['recipientReplacementRequestedAt'] = '2026-10-06T08:30:00Z';
      final model = BidModel.fromJson(json);
      expect(model.recipientDeclined, isTrue);
      expect(
        model.recipientReplacementRequestedAt,
        DateTime.utc(2026, 10, 6, 8, 30),
      );
      expect(
        model.nextRecipientReplacementAllowedAt,
        DateTime.utc(2026, 10, 6, 20, 30),
      );
      final out = model.toJson();
      expect(out['recipientDeclined'], isTrue);
      expect(
        out['recipientReplacementRequestedAt'],
        '2026-10-06T08:30:00.000Z',
      );
    });

    test('null explicite toléré', () {
      final json = _minimalBid()
        ..['recipientDeclined'] = null
        ..['recipientReplacementRequestedAt'] = null;
      final model = BidModel.fromJson(json);
      expect(model.recipientDeclined, isFalse);
      expect(model.recipientReplacementRequestedAt, isNull);
    });

    test('isRecipientDeclinedForSender suit recipientAppStatus', () {
      expect(
        BidModel.fromJson(
          _minimalBid()..['recipientAppStatus'] = 'DECLINED',
        ).isRecipientDeclinedForSender,
        isTrue,
      );
      expect(
        BidModel.fromJson(
          _minimalBid()..['recipientAppStatus'] = 'CONFIRMED',
        ).isRecipientDeclinedForSender,
        isFalse,
      );
    });
  });

  group('BidModel.handoverAddress / deliveryAddress (carte Lieux)', () {
    test('fromJson lit les deux adresses avec leurs coordonnées', () {
      final json = _minimalBid()
        ..['handoverAddress'] = {
          'label': '22 Rue du Séminaire, Chevilly-Larue',
          'lat': 48.7667,
          'lng': 2.3508,
        }
        ..['deliveryAddress'] = {
          'label': 'ACI 2000, Bamako',
          'lat': 12.6362,
          'lng': -8.0121,
        };
      final model = BidModel.fromJson(json);
      expect(
        model.handoverAddress?.label,
        '22 Rue du Séminaire, Chevilly-Larue',
      );
      expect(model.handoverAddress?.lat, 48.7667);
      expect(model.deliveryAddress?.label, 'ACI 2000, Bamako');
      expect(model.deliveryAddress?.lng, -8.0121);
      expect(model.toJson()['deliveryAddress'], model.deliveryAddress);
    });

    test('ancien back sans les champs → null', () {
      final model = BidModel.fromJson(_minimalBid());
      expect(model.handoverAddress, isNull);
      expect(model.deliveryAddress, isNull);
    });
  });

  group('BidModel.contactWindowOpen (FLUTTER-DK, yadony-back #414)', () {
    test('fromJson lit true et le renvoie en toJson', () {
      final json = _minimalBid()..['contactWindowOpen'] = true;
      final model = BidModel.fromJson(json);
      expect(model.contactWindowOpen, isTrue);
      expect(model.toJson()['contactWindowOpen'], isTrue);
    });

    test('fromJson lit false', () {
      final json = _minimalBid()..['contactWindowOpen'] = false;
      expect(BidModel.fromJson(json).contactWindowOpen, isFalse);
    });

    test('ancien back sans le champ → null (repli sur le statut)', () {
      expect(BidModel.fromJson(_minimalBid()).contactWindowOpen, isNull);
    });
  });

  group('BidModel.senderIncidentCount (FLUTTER-E0/E6)', () {
    test('lu et renvoyé en toJson', () {
      final model = BidModel.fromJson(
        _minimalBid()..['senderIncidentCount'] = 2,
      );
      expect(model.senderIncidentCount, 2);
      expect(model.toJson()['senderIncidentCount'], 2);
    });

    test('absent (back antérieur) → null', () {
      expect(BidModel.fromJson(_minimalBid()).senderIncidentCount, isNull);
    });
  });

  group('BidModel.pickupCodeRenewalNeeded (FLUTTER-G2, yadony-back #461)', () {
    test('absent (back antérieur) : faux', () {
      expect(BidModel.fromJson(_minimalBid()).pickupCodeRenewalNeeded, isFalse);
    });

    test('lu et réécrit', () {
      final model = BidModel.fromJson(
        _minimalBid()
          ..['status'] = 'IN_TRANSIT'
          ..['pickupCodeRenewalNeeded'] = true,
      );
      expect(model.pickupCodeRenewalNeeded, isTrue);
      expect(model.toJson()['pickupCodeRenewalNeeded'], isTrue);
    });

    test('needsNewPickupCode : drapeau serveur, même avec un code expiré', () {
      final model = BidModel.fromJson(
        _minimalBid()
          ..['status'] = 'IN_TRANSIT'
          ..['confirmationCode'] = '123456'
          ..['pickupCodeRenewalNeeded'] = true,
      );
      expect(model.needsNewPickupCode, isTrue);
    });

    test(
      'needsNewPickupCode : repli sur l\'absence du code (back antérieur)',
      () {
        final blocked = BidModel.fromJson(
          _minimalBid()..['status'] = 'ARRIVED',
        );
        final valid = BidModel.fromJson(
          _minimalBid()
            ..['status'] = 'ARRIVED'
            ..['confirmationCode'] = '123456',
        );
        final accepted = BidModel.fromJson(
          _minimalBid()..['status'] = 'ACCEPTED',
        );
        expect(blocked.needsNewPickupCode, isTrue);
        expect(valid.needsNewPickupCode, isFalse);
        expect(accepted.needsNewPickupCode, isFalse);
      },
    );
  });

  group('BidModel.isPickupCodeExpired (FLUTTER-G2)', () {
    BidModel model({String? code, bool flag = true}) => BidModel.fromJson(
      _minimalBid()
        ..['status'] = 'IN_TRANSIT'
        ..['confirmationCode'] = code
        ..['pickupCodeRenewalNeeded'] = flag,
    );

    test('code présent + drapeau serveur : expiré', () {
      expect(model(code: '123456').isPickupCodeExpired, isTrue);
    });

    test('code effacé : bloqué, pas expiré', () {
      expect(model().isPickupCodeExpired, isFalse);
      expect(model(code: '').isPickupCodeExpired, isFalse);
    });

    test('code valide (pas de drapeau) : pas expiré', () {
      expect(model(code: '123456', flag: false).isPickupCodeExpired, isFalse);
    });
  });
}
