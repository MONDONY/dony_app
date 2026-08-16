import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseJson({Map<String, dynamic>? overrides}) {
  final base = <String, dynamic>{
    'id': 't-1',
    'packageRequestId': 'pr-1',
    'travelerId': 'tr-1',
    'travelerAnnouncementId': null,
    'travelerTravelDate': '2026-06-15',
    'travelerAvailableKg': 10.0,
    'status': 'OPEN',
    'currentPriceEur': 30.0,
    'roundsCount': 1,
    'lastActivityAt': '2026-05-10T10:00:00Z',
    'createdAt': '2026-05-10T10:00:00Z',
    'messages': [
      {
        'id': 'm-1',
        'threadId': 't-1',
        'fromUserId': 'tr-1',
        'kind': 'PROPOSAL',
        'proposedPriceEur': 30.0,
        'body': null,
        'createdAt': '2026-05-10T10:00:00Z',
      },
    ],
    'paymentIntentClientSecret': null,
  };
  if (overrides != null) {
    base.addAll(overrides);
  }
  return base;
}

void main() {
  test('NegotiationThread.fromJson parses with messages', () {
    final t = NegotiationThread.fromJson(_baseJson());

    expect(t.id, 't-1');
    expect(t.status, NegotiationThreadStatus.open);
    expect(t.messages.length, 1);
    expect(t.messages.first.kind, NegotiationMessageKind.proposal);
  });

  test(
    'NegotiationThread.fromJson parses nouveaux champs optionnels du profil voyageur',
    () {
      final t = NegotiationThread.fromJson(
        _baseJson(
          overrides: {
            'travelerName': 'Mamadou Diallo',
            'travelerRating': 4.8,
            'travelerTripsCount': 12,
            'travelerPhotoUrl': 'https://example.com/photo.jpg',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'weightKg': 5.0,
          },
        ),
      );

      expect(t.travelerName, 'Mamadou Diallo');
      expect(t.travelerRating, 4.8);
      expect(t.travelerTripsCount, 12);
      expect(t.travelerPhotoUrl, 'https://example.com/photo.jpg');
      expect(t.departureCity, 'Paris');
      expect(t.arrivalCity, 'Dakar');
      expect(t.weightKg, 5.0);
    },
  );

  test('NegotiationThread.fromJson retourne null pour les champs absents', () {
    final t = NegotiationThread.fromJson(_baseJson());

    expect(t.travelerName, isNull);
    expect(t.travelerRating, isNull);
    expect(t.travelerTripsCount, isNull);
    expect(t.travelerPhotoUrl, isNull);
    expect(t.departureCity, isNull);
    expect(t.arrivalCity, isNull);
    expect(t.weightKg, isNull);
  });

  test(
    'NegotiationThread.fromJson parse le statut AWAITING_TRIP correctement',
    () {
      final t = NegotiationThread.fromJson(
        _baseJson(overrides: {'status': 'AWAITING_TRIP'}),
      );
      expect(t.status, NegotiationThreadStatus.awaitingTrip);
    },
  );

  test(
    'NegotiationThread.fromJson parse le statut AWAITING_PAYMENT correctement',
    () {
      final t = NegotiationThread.fromJson(
        _baseJson(overrides: {'status': 'AWAITING_PAYMENT'}),
      );
      expect(t.status, NegotiationThreadStatus.awaitingPayment);
    },
  );

  test('NegotiationThread.fromJson parse le statut REJECTED correctement', () {
    final t = NegotiationThread.fromJson(
      _baseJson(overrides: {'status': 'REJECTED'}),
    );
    expect(t.status, NegotiationThreadStatus.rejected);
  });

  test('NegotiationThread.fromJson parse le statut CANCELLED correctement', () {
    final t = NegotiationThread.fromJson(
      _baseJson(overrides: {'status': 'CANCELLED'}),
    );
    expect(t.status, NegotiationThreadStatus.cancelled);
  });

  test('fromJson parses grossPriceEur + paymentMethod', () {
    final t = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'status': 'AWAITING_PAYMENT',
          'currentPriceEur': 35,
          'grossPriceEur': 39.20,
          'roundsCount': 2,
          'paymentMethod': 'CASH',
        },
      ),
    );
    expect(t.currentPriceEur, 35);
    expect(t.grossPriceEur, 39.20);
    expect(t.paymentMethod, PaymentMethod.cash);
  });

  test('fromJson returns null grossPriceEur and paymentMethod when absent', () {
    final t = NegotiationThread.fromJson(_baseJson());
    expect(t.grossPriceEur, isNull);
    expect(t.paymentMethod, isNull);
  });

  test(
    'fromJson parses travelerCapacityUnit and isTravelerKgFree for KG_FREE',
    () {
      final t = NegotiationThread.fromJson(
        _baseJson(overrides: {'travelerCapacityUnit': 'KG_FREE'}),
      );
      expect(t.travelerCapacityUnit, 'KG_FREE');
      expect(t.isTravelerKgFree, isTrue);
    },
  );

  test('isTravelerKgFree is false for SUITCASE_23KG', () {
    final t = NegotiationThread.fromJson(
      _baseJson(overrides: {'travelerCapacityUnit': 'SUITCASE_23KG'}),
    );
    expect(t.travelerCapacityUnit, 'SUITCASE_23KG');
    expect(t.isTravelerKgFree, isFalse);
  });

  test('isTravelerKgFree is false when travelerCapacityUnit absent (null)', () {
    final t = NegotiationThread.fromJson(_baseJson());
    expect(t.travelerCapacityUnit, isNull);
    expect(t.isTravelerKgFree, isFalse);
  });

  test('fromJson parses materializedBidId when present', () {
    final t = NegotiationThread.fromJson(
      _baseJson(
        overrides: {'status': 'ACCEPTED', 'materializedBidId': 'bid-123'},
      ),
    );
    expect(t.materializedBidId, 'bid-123');
  });

  test('fromJson returns null materializedBidId when absent', () {
    final t = NegotiationThread.fromJson(_baseJson());
    expect(t.materializedBidId, isNull);
  });

  test('fromJson parses senderPhotoUrl when present', () {
    final t = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'senderPhotoUrl': 'https://cdn.dony.app/avatars/sender-42.jpg',
        },
      ),
    );
    expect(t.senderPhotoUrl, 'https://cdn.dony.app/avatars/sender-42.jpg');
  });

  test('fromJson returns null senderPhotoUrl when absent', () {
    final t = NegotiationThread.fromJson(_baseJson());
    expect(t.senderPhotoUrl, isNull);
  });

  test('senderPhotoUrl participates in props/equality', () {
    final t1 = NegotiationThread.fromJson(_baseJson());
    final t2 = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'senderPhotoUrl': 'https://cdn.dony.app/avatars/sender-42.jpg',
        },
      ),
    );
    expect(t1, isNot(equals(t2)));
  });

  test('parse availablePaymentMethods depuis le JSON', () {
    final t = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'availablePaymentMethods': ['STRIPE', 'CASH'],
        },
      ),
    );
    expect(t.availablePaymentMethods, {
      PaymentMethod.stripe,
      PaymentMethod.cash,
    });
  });

  test('availablePaymentMethods null quand absent', () {
    final t = NegotiationThread.fromJson(_baseJson());
    expect(t.availablePaymentMethods, isNull);
  });

  test('availablePaymentMethods participates in props/equality', () {
    final t1 = NegotiationThread.fromJson(_baseJson());
    final t2 = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'availablePaymentMethods': ['STRIPE'],
        },
      ),
    );
    expect(t1, isNot(equals(t2)));
  });

  // ── Finding #5 — resilient parse of availablePaymentMethods ────────────────
  // An unknown wire value here must be skipped, not fail the whole thread
  // parse (unlike PaymentMethod.fromWire/setFromJson elsewhere, left as-is).

  test('availablePaymentMethods ignore une valeur wire inconnue au lieu de '
      'faire échouer tout le parse', () {
    final t = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'availablePaymentMethods': ['STRIPE', 'BITCOIN', 'CASH'],
        },
      ),
    );
    expect(t.availablePaymentMethods, {
      PaymentMethod.stripe,
      PaymentMethod.cash,
    });
  });

  test('availablePaymentMethods vide (Set vide, pas null) quand toutes les '
      'valeurs sont inconnues', () {
    final t = NegotiationThread.fromJson(
      _baseJson(
        overrides: {
          'availablePaymentMethods': ['BITCOIN', 'GOLD'],
        },
      ),
    );
    expect(t.availablePaymentMethods, isNotNull);
    expect(t.availablePaymentMethods, isEmpty);
  });

  test(
    'le reste du thread parse normalement malgré une valeur wire inconnue',
    () {
      final t = NegotiationThread.fromJson(
        _baseJson(
          overrides: {
            'status': 'AWAITING_PAYMENT',
            'availablePaymentMethods': ['BITCOIN'],
          },
        ),
      );
      expect(t.id, 't-1');
      expect(t.status, NegotiationThreadStatus.awaitingPayment);
    },
  );

  test('parse canNudge (true / défaut false)', () {
    expect(
      NegotiationThread.fromJson(
        _baseJson(overrides: {'canNudge': true}),
      ).canNudge,
      isTrue,
    );
    expect(NegotiationThread.fromJson(_baseJson()).canNudge, isFalse);
  });

  test('canNudge participates in props/equality', () {
    final t1 = NegotiationThread.fromJson(_baseJson());
    final t2 = NegotiationThread.fromJson(
      _baseJson(overrides: {'canNudge': true}),
    );
    expect(t1, isNot(equals(t2)));
  });

  group('commissionStatus', () {
    final baseJson = _baseJson();

    test(
      'fromJson lit commissionStatus et en déduit le besoin de règlement',
      () {
        final thread = NegotiationThread.fromJson({
          ...baseJson,
          'commissionStatus': 'PENDING',
        });
        expect(thread.commissionStatus, 'PENDING');
        expect(thread.needsCommissionSettlement, isTrue);
      },
    );

    test('commissionStatus absent → aucun règlement attendu', () {
      final thread = NegotiationThread.fromJson(baseJson);
      expect(thread.commissionStatus, isNull);
      expect(thread.needsCommissionSettlement, isFalse);
    });

    test('commissionStatus CHARGED → aucun règlement attendu', () {
      final thread = NegotiationThread.fromJson({
        ...baseJson,
        'commissionStatus': 'CHARGED',
      });
      expect(thread.commissionStatus, 'CHARGED');
      expect(thread.needsCommissionSettlement, isFalse);
    });

    test(
      'commissionStatus REQUIRES_3DS → règlement encore attendu (3DS bancaire)',
      () {
        final thread = NegotiationThread.fromJson({
          ...baseJson,
          'commissionStatus': 'REQUIRES_3DS',
        });
        expect(thread.commissionStatus, 'REQUIRES_3DS');
        expect(thread.needsCommissionSettlement, isTrue);
      },
    );

    test('commissionStatus participates in props/equality', () {
      final t1 = NegotiationThread.fromJson(baseJson);
      final t2 = NegotiationThread.fromJson({
        ...baseJson,
        'commissionStatus': 'PENDING',
      });
      expect(t1, isNot(equals(t2)));
    });
  });

  group('AWAITING_COMMISSION status', () {
    test('AWAITING_COMMISSION est reconnu et compté comme actif', () {
      expect(
        NegotiationThreadStatus.fromJson('AWAITING_COMMISSION'),
        NegotiationThreadStatus.awaitingCommission,
      );
      expect(NegotiationThreadStatus.awaitingCommission.isActive, isTrue);
    });

    // Garde-fou de compatibilité : un statut inconnu ne doit jamais rendre un fil
    // impossible à ouvrir. Avant ce correctif, firstWhere levait une StateError.
    test('un statut inconnu ne lève pas et retombe sur open', () {
      expect(
        NegotiationThreadStatus.fromJson('STATUT_DU_FUTUR'),
        NegotiationThreadStatus.open,
      );
    });
  });

  group('commissionDeadline', () {
    final baseJson = _baseJson();

    test('fromJson lit commissionDeadline', () {
      final thread = NegotiationThread.fromJson({
        ...baseJson,
        'commissionDeadline': '2026-08-16T14:30:00',
      });
      expect(thread.commissionDeadline, DateTime.parse('2026-08-16T14:30:00'));
    });

    test('commissionDeadline absent reste null', () {
      expect(NegotiationThread.fromJson(baseJson).commissionDeadline, isNull);
    });
  });
}
