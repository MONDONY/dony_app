import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/distance_badge.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _ann({AddressData? pickup}) => AnnouncementModel(
  id: 'a1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  departureDate: DateTime(2026, 6, 15),
  availableKg: 8,
  totalKg: 8,
  pricePerKg: 12,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  pickupAddress: pickup,
);

void main() {
  const user = (lat: 48.8566, lng: 2.3522);

  group('buildDistanceBadge', () {
    test('sans position de l\'utilisateur, aucun badge', () {
      final a = _ann(
        pickup: const AddressData(label: 'Orly ORY', lat: 48.7262, lng: 2.3652),
      );
      expect(buildDistanceBadge(a, null), isNull);
    });

    test('sans adresse de remise, aucun badge', () {
      expect(buildDistanceBadge(_ann(), user), isNull);
    });

    test('à moins d\'un kilomètre : « < 1 km » derrière le code aéroport', () {
      final a = _ann(
        pickup: const AddressData(label: 'Orly ORY', lat: 48.8566, lng: 2.3522),
      );
      expect(buildDistanceBadge(a, user), 'ORY · < 1 km');
    });

    test('distance arrondie au kilomètre', () {
      final a = _ann(
        pickup: const AddressData(label: 'Orly ORY', lat: 48.7262, lng: 2.3652),
      );
      expect(buildDistanceBadge(a, user), 'ORY · 15 km');
    });

    test('sans code aéroport, le premier mot du libellé sert de repère', () {
      final a = _ann(
        pickup: const AddressData(
          label: 'Gare du Nord',
          lat: 48.8809,
          lng: 2.3553,
        ),
      );
      expect(buildDistanceBadge(a, user), startsWith('Gare · '));
    });
  });
}
