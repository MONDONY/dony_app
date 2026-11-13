import 'package:dony/core/utils/arrival_range.dart';
import 'package:dony/core/utils/trip_local_time.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);
  final now = DateTime(2026, 11, 13);

  group('arrivalRangeDays', () {
    test('fourchette de la même année : deux jours sans année', () {
      final fromFr = arrivalRangeDays(
        fr,
        DateTime(2026, 12, 11),
        DateTime(2026, 12, 18),
        now: now,
      );
      expect(fromFr, (from: '11 déc.', to: '18 déc.'));
      final fromEn = arrivalRangeDays(
        en,
        DateTime(2026, 12, 11),
        DateTime(2026, 12, 18),
        now: now,
      );
      expect(fromEn, (from: 'Dec 11', to: 'Dec 18'));
    });

    test('jour d\'une autre année : il porte son année', () {
      final days = arrivalRangeDays(
        fr,
        DateTime(2026, 12, 28),
        DateTime(2027, 1, 18),
        now: now,
      );
      expect(days.from, '28 déc.');
      expect(days.to, '18 janv. 2027');
    });

    test('fin absente, le même jour ou avant le début : date seule', () {
      final start = DateTime(2026, 12, 11);
      expect(arrivalRangeDays(fr, start, null, now: now).to, isNull);
      expect(
        arrivalRangeDays(fr, start, DateTime(2026, 12, 11, 23), now: now).to,
        isNull,
      );
      expect(
        arrivalRangeDays(fr, start, DateTime(2026, 12, 2), now: now).to,
        isNull,
      );
    });
  });

  group('cityTakesElision', () {
    test('voyelle, accent compris : élision', () {
      expect(cityTakesElision('Abidjan'), isTrue);
      expect(cityTakesElision(' Évry'), isTrue);
      expect(cityTakesElision('Ouagadougou'), isTrue);
    });

    test('consonne ou nom vide : pas d\'élision', () {
      expect(cityTakesElision('Dakar'), isFalse);
      expect(cityTakesElision(''), isFalse);
      expect(cityTakesElision('   '), isFalse);
    });
  });
}
