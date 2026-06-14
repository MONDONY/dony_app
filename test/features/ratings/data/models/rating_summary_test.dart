import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';

void main() {
  group('RatingItem', () {
    test('parse existing fields', () {
      final r = RatingItem.fromJson({
        'stars': 4,
        'comment': 'Super voyage',
        'createdAt': '2025-06-01T12:00:00',
        'excluded': false,
      });
      expect(r.stars, 4);
      expect(r.comment, 'Super voyage');
      expect(r.createdAt, DateTime.parse('2025-06-01T12:00:00'));
      expect(r.excluded, false);
    });

    test('excluded defaults to false when absent', () {
      final r = RatingItem.fromJson({
        'stars': 3,
        'createdAt': '2025-06-01T12:00:00',
      });
      expect(r.excluded, false);
    });

    test('RatingItem parse author + corridor', () {
      final r = RatingItem.fromJson({
        'stars': 5,
        'createdAt': '2026-01-01T00:00:00',
        'excluded': false,
        'authorName': 'Fatou M.',
        'authorAvatarUrl': 'https://cdn/f.jpg',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
      });
      expect(r.authorName, 'Fatou M.');
      expect(r.authorAvatarUrl, 'https://cdn/f.jpg');
      expect(r.departureCity, 'Paris');
      expect(r.arrivalCity, 'Dakar');
    });

    test('new fields are nullable when absent', () {
      final r = RatingItem.fromJson({
        'stars': 2,
        'createdAt': '2025-06-01T12:00:00',
        'excluded': false,
      });
      expect(r.authorName, isNull);
      expect(r.authorAvatarUrl, isNull);
      expect(r.departureCity, isNull);
      expect(r.arrivalCity, isNull);
    });
  });
}
