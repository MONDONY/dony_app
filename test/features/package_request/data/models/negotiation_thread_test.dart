import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseJson({
  Map<String, dynamic>? overrides,
}) {
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
      }
    ],
    'paymentIntentClientSecret': null,
  };
  if (overrides != null) base.addAll(overrides);
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

  test('NegotiationThread.fromJson parses nouveaux champs optionnels du profil voyageur',
      () {
    final t = NegotiationThread.fromJson(_baseJson(overrides: {
      'travelerName': 'Mamadou Diallo',
      'travelerRating': 4.8,
      'travelerTripsCount': 12,
      'travelerPhotoUrl': 'https://example.com/photo.jpg',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'weightKg': 5.0,
    }));

    expect(t.travelerName, 'Mamadou Diallo');
    expect(t.travelerRating, 4.8);
    expect(t.travelerTripsCount, 12);
    expect(t.travelerPhotoUrl, 'https://example.com/photo.jpg');
    expect(t.departureCity, 'Paris');
    expect(t.arrivalCity, 'Dakar');
    expect(t.weightKg, 5.0);
  });

  test('NegotiationThread.fromJson retourne null pour les champs absents',
      () {
    final t = NegotiationThread.fromJson(_baseJson());

    expect(t.travelerName, isNull);
    expect(t.travelerRating, isNull);
    expect(t.travelerTripsCount, isNull);
    expect(t.travelerPhotoUrl, isNull);
    expect(t.departureCity, isNull);
    expect(t.arrivalCity, isNull);
    expect(t.weightKg, isNull);
  });

  test('NegotiationThread.fromJson parse le statut AWAITING_TRIP correctement',
      () {
    final t = NegotiationThread.fromJson(
      _baseJson(overrides: {'status': 'AWAITING_TRIP'}),
    );
    expect(t.status, NegotiationThreadStatus.awaitingTrip);
  });

  test('NegotiationThread.fromJson parse le statut AWAITING_PAYMENT correctement',
      () {
    final t = NegotiationThread.fromJson(
      _baseJson(overrides: {'status': 'AWAITING_PAYMENT'}),
    );
    expect(t.status, NegotiationThreadStatus.awaitingPayment);
  });

  test('NegotiationThread.fromJson parse le statut REJECTED correctement', () {
    final t = NegotiationThread.fromJson(
      _baseJson(overrides: {'status': 'REJECTED'}),
    );
    expect(t.status, NegotiationThreadStatus.rejected);
  });
}
