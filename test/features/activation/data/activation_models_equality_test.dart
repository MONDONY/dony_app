import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivationTrip', () {
    const json = {
      'id': 'a1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': '2026-06-01T00:00:00Z',
      'availableKg': 10,
      'pricePerKg': 8.5,
      'currency': 'EUR',
    };

    test('égalité par valeur entre deux lectures du même JSON', () {
      final a = ActivationTrip.fromJson(json);
      final b = ActivationTrip.fromJson(json);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.availableKg, 10.0);
      expect(a.pricePerKg, 8.5);
    });

    test('un champ différent rompt l’égalité', () {
      final a = ActivationTrip.fromJson(json);
      final b = ActivationTrip.fromJson(Map.of(json)..['currency'] = 'XOF');
      expect(a, isNot(b));
    });

    test('nombres non numériques ignorés, villes vides par défaut', () {
      final t = ActivationTrip.fromJson(const {
        'id': 'a2',
        'availableKg': 'dix',
        'departureDate': 'n/a',
      });
      expect(t.availableKg, isNull);
      expect(t.departureCity, '');
      expect(t.departureDate, isA<DateTime>());
    });
  });

  group('ActivationPackage', () {
    test('égalité par valeur', () {
      const json = {
        'id': 'p1',
        'departureCity': 'Lyon',
        'arrivalCity': 'Bamako',
        'desiredDate': '2026-07-01T00:00:00Z',
        'weightKg': 4,
      };
      final a = ActivationPackage.fromJson(json);
      expect(a, ActivationPackage.fromJson(json));
      expect(a.hashCode, ActivationPackage.fromJson(json).hashCode);
      expect(a.weightKg, 4.0);
      expect(
        a,
        isNot(ActivationPackage.fromJson(Map.of(json)..['weightKg'] = 5)),
      );
    });
  });

  group('ActivationStatus', () {
    test('compare aussi les listes de trajets et de colis', () {
      final json = {
        'intent': 'BOTH',
        'opportunities': {
          'kind': 'PACKAGES',
          'total': 1,
          'packages': [
            {'id': 'p1', 'desiredDate': '2026-07-01T00:00:00Z'},
          ],
        },
      };
      final a = ActivationStatus.fromJson(json);
      final b = ActivationStatus.fromJson(json);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.intent, UserIntent.both);
      expect(a.kind, OpportunityKind.packages);
    });
  });
}
