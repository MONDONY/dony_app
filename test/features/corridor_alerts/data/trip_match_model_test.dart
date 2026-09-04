import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson maps all AlertTripMatchDto fields', () {
    final json = <String, dynamic>{
      'announcementId': 'ann-1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': '2026-07-10',
      'travelerId': 't-1',
      'travelerName': 'Awa S.',
      'travelerInitials': 'AS',
      'travelerRating': 4.7,
      'availableKg': 12.0,
      'pricePerKg': 9.5,
      'transportMode': 'PLANE',
      'photoUrl': 'https://x/y.jpg',
    };
    final m = TripMatchModel.fromJson(json);
    expect(m.announcementId, 'ann-1');
    expect(m.departureCity, 'Paris');
    expect(m.arrivalCity, 'Dakar');
    expect(m.departureDate, DateTime(2026, 7, 10));
    expect(m.travelerId, 't-1');
    expect(m.travelerName, 'Awa S.');
    expect(m.travelerInitials, 'AS');
    expect(m.travelerRating, 4.7);
    expect(m.availableKg, 12.0);
    expect(m.pricePerKg, 9.5);
    expect(m.transportMode, 'PLANE');
    expect(m.photoUrl, 'https://x/y.jpg');
    // Backend antérieur : pas d'horodatage de publication.
    expect(m.publishedAt, isNull);
  });

  test('fromJson parses publishedAt when present', () {
    final m = TripMatchModel.fromJson(const <String, dynamic>{
      'announcementId': 'ann-3',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': '2026-07-10',
      'travelerId': 't-3',
      'travelerName': 'Awa S.',
      'travelerInitials': 'AS',
      'travelerRating': 4.7,
      'availableKg': 12.0,
      'publishedAt': '2026-06-01T10:00:00',
    });
    expect(m.publishedAt, DateTime(2026, 6, 1, 10));
  });

  test('fromJson tolerates null optional fields', () {
    final json = <String, dynamic>{
      'announcementId': 'ann-2',
      'departureCity': 'Lyon',
      'arrivalCity': 'Abidjan',
      'departureDate': '2026-08-01',
      'travelerId': 't-2',
      'travelerName': 'Koffi',
      'travelerInitials': 'K',
      'travelerRating': 0.0,
      'availableKg': 5.0,
    };
    final m = TripMatchModel.fromJson(json);
    expect(m.pricePerKg, isNull);
    expect(m.transportMode, isNull);
    expect(m.photoUrl, isNull);
  });
}
