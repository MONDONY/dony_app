import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson lit le compteur et la dernière annonce', () {
    final s = AnnouncementsSummary.fromJson({
      'unreadCount': 2,
      'latestId': 'a1',
      'latestTitle': 'Maintenance ce soir',
      'latestAt': '2026-09-03T10:00:00',
    });

    expect(s.unreadCount, 2);
    expect(s.latestId, 'a1');
    expect(s.latestTitle, 'Maintenance ce soir');
    expect(s.latestAt, DateTime(2026, 9, 3, 10));
    expect(s.hasAny, isTrue);
  });

  test('sans aucune annonce : compteur à zéro, rien à afficher', () {
    final s = AnnouncementsSummary.fromJson({'unreadCount': 0});

    expect(s.unreadCount, 0);
    expect(s.latestId, isNull);
    expect(s.hasAny, isFalse);
    expect(AnnouncementsSummary.empty.hasAny, isFalse);
  });

  test('copyWith ne touche qu\'au compteur', () {
    final s = AnnouncementsSummary.fromJson({
      'unreadCount': 3,
      'latestId': 'a1',
      'latestTitle': 't',
    }).copyWith(unreadCount: 0);

    expect(s.unreadCount, 0);
    expect(s.latestId, 'a1');
    expect(s.latestTitle, 't');
  });
}
