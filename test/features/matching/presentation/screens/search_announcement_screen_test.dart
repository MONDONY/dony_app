import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/search_announcement_screen.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

AnnouncementModel _buildAnnouncement({AddressData? pickupAddress}) =>
    AnnouncementModel(
      id: 'ann-test',
      travelerId: 'traveler-test',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 6, 1),
      availableKg: 20.0,
      totalKg: 20.0,
      pricePerKg: 5.0,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      pickupAddress: pickupAddress,
    );

void main() {
  group('buildDistanceBadge', () {
    test('retourne null quand userPos est null', () {
      final announcement = _buildAnnouncement(
        pickupAddress: const AddressData(
          label: 'Paris CDG',
          lat: 49.0097,
          lng: 2.5479,
        ),
      );
      expect(buildDistanceBadge(announcement, null), isNull);
    });

    test('retourne null quand pickupAddress est null', () {
      final announcement = _buildAnnouncement();
      expect(
        buildDistanceBadge(announcement, (lat: 48.8566, lng: 2.3522)),
        isNull,
      );
    });

    test('retourne le code IATA et la distance', () {
      final announcement = _buildAnnouncement(
        pickupAddress: const AddressData(
          label: 'Paris CDG',
          lat: 49.0097,
          lng: 2.5479,
        ),
      );
      final result =
          buildDistanceBadge(announcement, (lat: 48.8566, lng: 2.3522));
      expect(result, isNotNull);
      expect(result, contains('CDG'));
      expect(result, contains('km'));
    });

    test('utilise le premier mot du label si pas de code IATA', () {
      final announcement = _buildAnnouncement(
        pickupAddress: const AddressData(
          label: 'Roissy Charles',
          lat: 49.0097,
          lng: 2.5479,
        ),
      );
      final result =
          buildDistanceBadge(announcement, (lat: 48.8566, lng: 2.3522));
      expect(result, isNotNull);
      expect(result, startsWith('Roissy'));
      expect(result, contains('km'));
    });

    test('distance est un entier arrondi en km', () {
      // Paris (48.8566, 2.3522) → CDG (49.0097, 2.5479) ≈ 25 km
      final announcement = _buildAnnouncement(
        pickupAddress: const AddressData(
          label: 'CDG Terminal 2',
          lat: 49.0097,
          lng: 2.5479,
        ),
      );
      final result =
          buildDistanceBadge(announcement, (lat: 48.8566, lng: 2.3522));
      expect(result, isNotNull);
      // Format attendu: "CDG · XX km"
      final parts = result!.split(' · ');
      expect(parts.length, 2);
      expect(parts[0], 'CDG');
      expect(parts[1].endsWith(' km'), isTrue);
      final km = int.tryParse(parts[1].replaceAll(' km', ''));
      expect(km, isNotNull);
      // CDG est environ 25 km de Paris centre — tolérance large
      expect(km, greaterThan(10));
      expect(km, lessThan(50));
    });
  });
}
