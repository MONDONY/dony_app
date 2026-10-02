import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse un expéditeur avec trajets', () {
    final s = ActivationStatus.fromJson(const {
      'intent': 'SENDER',
      'destinationCountry': 'CI',
      'kycVerified': true,
      'firstActionDone': false,
      'opportunities': {
        'kind': 'TRIPS',
        'total': 3,
        'trips': [
          {
            'id': 't1',
            'departureCity': 'Paris',
            'arrivalCity': 'Abidjan',
            'departureDate': '2026-10-10',
            'availableKg': 12,
            'pricePerKg': 9.5,
            'currency': 'EUR',
          },
        ],
        'packages': <Object>[],
      },
    });
    expect(s.intent, UserIntent.sender);
    expect(s.destinationCountry, 'CI');
    expect(s.kycVerified, isTrue);
    expect(s.firstActionDone, isFalse);
    expect(s.kind, OpportunityKind.trips);
    expect(s.total, 3);
    expect(s.trips.single.departureDate, DateTime(2026, 10, 10));
    expect(s.trips.single.availableKg, 12.0);
    expect(s.trips.single.pricePerKg, 9.5);
  });

  test('parse un voyageur avec colis', () {
    final s = ActivationStatus.fromJson(const {
      'intent': 'TRAVELER',
      'opportunities': {
        'kind': 'PACKAGES',
        'total': 1,
        'packages': [
          {
            'id': 'p1',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'desiredDate': '2026-10-12',
            'weightKg': 3,
          },
        ],
      },
    });
    expect(s.kind, OpportunityKind.packages);
    expect(s.packages.single.weightKg, 3.0);
    expect(s.packages.single.desiredDate, DateTime(2026, 10, 12));
  });

  test('tolère les champs absents', () {
    final s = ActivationStatus.fromJson(const {});
    expect(s.intent, isNull);
    expect(s.kind, OpportunityKind.none);
    expect(s.total, 0);
    expect(s.trips, isEmpty);
    expect(s.firstActionDone, isTrue); // absent = on ne guide pas
  });

  test('intention inconnue ignorée', () {
    expect(UserIntent.fromWire('FOO'), isNull);
    expect(UserIntent.fromWire(null), isNull);
    expect(UserIntent.fromWire('BOTH'), UserIntent.both);
  });
}
