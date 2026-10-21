import 'package:dony/features/matching/data/models/announcement_search_page.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _ann(String id) => {
  'id': id,
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
  test('search_page_without_similar_key_is_empty', () {
    final page = AnnouncementSearchPage.fromJson({
      'content': [_ann('a1')],
      'totalElements': 1,
    }, page: 0);
    expect(page.similar, isEmpty);
  });

  test('search_page_parses_similar_with_announcement_and_unmet', () {
    final page = AnnouncementSearchPage.fromJson({
      'content': [_ann('a1')],
      'totalElements': 1,
      'similarAnnouncements': [
        {
          'announcement': _ann('a2'),
          'unmet': [
            {'code': 'DATE', 'requested': 'x', 'actual': 'y'},
            {'code': 'KILO_PRO_ONLY'},
          ],
        },
      ],
    }, page: 0);
    expect(page.similar, hasLength(1));
    expect(page.similar.first.announcement.id, 'a2');
    expect(page.similar.first.unmet.map((u) => u.code), [
      'DATE',
      'KILO_PRO_ONLY',
    ]);
  });

  test('malformed_similar_entry_is_skipped', () {
    final page = AnnouncementSearchPage.fromJson({
      'content': const [],
      'similarAnnouncements': [
        'oops',
        {'unmet': []},
        {'announcement': _ann('a3'), 'unmet': []},
      ],
    }, page: 0);
    expect(page.similar.map((s) => s.announcement.id), ['a3']);
  });
}
