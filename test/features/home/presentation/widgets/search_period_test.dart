// Libellé partagé d'une période de recherche (champ du composeur, puce et
// feuille « Date de départ » de l'accueil), en français et en anglais.

import 'package:dony/features/home/presentation/widgets/search_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final now = DateTime(2026, 10, 22);

  group('un seul jour : format d\'avant les périodes', () {
    test('fr', () {
      final day = DateTime(2026, 10, 30);
      expect(formatSearchPeriod(day, null, 'fr', now: now), '30 oct.');
      expect(
        formatSearchPeriod(day, null, 'fr', withWeekday: true, now: now),
        'ven. 30 oct.',
      );
    });

    test('en', () {
      final day = DateTime(2026, 10, 30);
      expect(formatSearchPeriod(day, null, 'en', now: now), 'Oct 30');
      expect(
        formatSearchPeriod(day, null, 'en', withWeekday: true, now: now),
        'Fri, Oct 30',
      );
    });

    test('début et fin le même jour = un seul jour', () {
      expect(
        formatSearchPeriod(
          DateTime(2026, 10, 30),
          DateTime(2026, 10, 30, 18),
          'fr',
          now: now,
        ),
        '30 oct.',
      );
    });
  });

  group('période', () {
    final start = DateTime(2026, 11, 15);
    final end = DateTime(2026, 12, 15);

    test('fr : flèche, sans année dans l\'année en cours', () {
      expect(
        formatSearchPeriod(start, end, 'fr', now: now),
        '15 nov. → 15 déc.',
      );
    });

    test('en', () {
      expect(formatSearchPeriod(start, end, 'en', now: now), 'Nov 15 → Dec 15');
    });

    test('jamais de tiret cadratin', () {
      expect(
        formatSearchPeriod(start, end, 'fr', now: now),
        isNot(contains('—')),
      );
    });

    test('à cheval sur deux années : l\'année sur les deux bornes', () {
      final from = DateTime(2026, 12, 20);
      final to = DateTime(2027, 1, 5);
      expect(
        formatSearchPeriod(from, to, 'fr', now: now),
        '20 déc. 2026 → 5 janv. 2027',
      );
      expect(
        formatSearchPeriod(from, to, 'en', now: now),
        'Dec 20, 2026 → Jan 5, 2027',
      );
    });

    test('une autre année que l\'année en cours : l\'année à la fin', () {
      expect(
        formatSearchPeriod(
          DateTime(2027, 3),
          DateTime(2027, 3, 31),
          'fr',
          now: now,
        ),
        '1 mars → 31 mars 2027',
      );
      expect(
        formatSearchPeriod(
          DateTime(2027, 3),
          DateTime(2027, 3, 31),
          'en',
          now: now,
        ),
        'Mar 1 → Mar 31, 2027',
      );
    });
  });
}
