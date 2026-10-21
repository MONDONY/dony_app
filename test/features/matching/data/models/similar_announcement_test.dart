import 'package:dony/features/matching/data/models/similar_announcement.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _ann() => {
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2026-10-13',
  'availableKg': 10,
  'totalKg': 20,
  'pricePerKg': 5,
  'status': 'ACTIVE',
  'createdAt': '2026-10-01T10:00:00',
  'updatedAt': '2026-10-01T10:00:00',
};

void main() {
  group('UnmetCriterion', () {
    test('parses_code_requested_actual', () {
      final c = UnmetCriterion.fromJson({
        'code': 'DATE',
        'requested': '2026-10-12',
        'actual': '2026-10-13',
      });
      expect(c.code, 'DATE');
      expect(c.requested, '2026-10-12');
      expect(c.actual, '2026-10-13');
    });

    test('missing_requested_actual_default_to_empty', () {
      final c = UnmetCriterion.fromJson({'code': 'URGENT'});
      expect(c.requested, '');
      expect(c.actual, '');
      final n = UnmetCriterion.fromJson({
        'code': 'FUTUR_CODE',
        'requested': null,
        'actual': null,
      });
      expect(n.code, 'FUTUR_CODE');
      expect(n.requested, '');
    });
  });

  test('SimilarAnnouncement parses announcement and unmet', () {
    final s = SimilarAnnouncement.fromJson({
      'announcement': _ann(),
      'unmet': [
        {'code': 'DATE', 'requested': 'a', 'actual': 'b'},
      ],
    });
    expect(s.announcement.id, 'a1');
    expect(s.unmet.single.code, 'DATE');
  });
}
