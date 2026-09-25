// Non-régression du remplacement des motifs de date fixes ('d MMM',
// 'd MMM yyyy') par les squelettes intl DateFormat.MMMd / DateFormat.yMMMd
// dans formatNotificationAge (notification_bottom_sheet.dart).
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);
  final now = DateTime(2026, 10, 6, 14, 5);

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en_US');
  });

  group('formatNotificationAge — français', () {
    test('30 s : maintenant', () {
      expect(
        formatNotificationAge(
          fr,
          now.subtract(const Duration(seconds: 30)),
          now,
        ),
        'maintenant',
      );
    });

    test('5 min', () {
      expect(
        formatNotificationAge(
          fr,
          now.subtract(const Duration(minutes: 5)),
          now,
        ),
        '5 min',
      );
    });

    test('3 h', () {
      expect(
        formatNotificationAge(fr, now.subtract(const Duration(hours: 3)), now),
        '3 h',
      );
    });

    test('2 j', () {
      expect(
        formatNotificationAge(fr, now.subtract(const Duration(days: 2)), now),
        '2 j',
      );
    });

    test('date de l\'année : ancien rendu "d MMM" (12 août)', () {
      expect(
        formatNotificationAge(fr, DateTime(2026, 8, 12), now),
        DateFormat.MMMd('fr').format(DateTime(2026, 8, 12)),
      );
      expect(formatNotificationAge(fr, DateTime(2026, 8, 12), now), '12 août');
    });

    test('date d\'une autre année : ancien rendu "d MMM yyyy"', () {
      expect(
        formatNotificationAge(fr, DateTime(2025, 12, 24), now),
        DateFormat.yMMMd('fr').format(DateTime(2025, 12, 24)),
      );
      expect(
        formatNotificationAge(fr, DateTime(2025, 12, 24), now),
        '24 déc. 2025',
      );
    });
  });

  group('formatNotificationAge — anglais', () {
    test('30 s : now', () {
      expect(
        formatNotificationAge(
          en,
          now.subtract(const Duration(seconds: 30)),
          now,
        ),
        'now',
      );
    });

    test('5 min', () {
      expect(
        formatNotificationAge(
          en,
          now.subtract(const Duration(minutes: 5)),
          now,
        ),
        '5 min',
      );
    });

    test('3 h', () {
      expect(
        formatNotificationAge(en, now.subtract(const Duration(hours: 3)), now),
        '3 h',
      );
    });

    test('2 j : "2d"', () {
      expect(
        formatNotificationAge(en, now.subtract(const Duration(days: 2)), now),
        '2d',
      );
    });

    test('date de l\'année : DateFormat.MMMd(en)', () {
      expect(
        formatNotificationAge(en, DateTime(2026, 8, 12), now),
        DateFormat.MMMd('en').format(DateTime(2026, 8, 12)),
      );
    });

    test('date d\'une autre année : DateFormat.yMMMd(en)', () {
      expect(
        formatNotificationAge(en, DateTime(2025, 12, 24), now),
        DateFormat.yMMMd('en').format(DateTime(2025, 12, 24)),
      );
    });
  });
}
