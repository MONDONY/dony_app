import 'package:dony/features/package_request/presentation/request_time_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('moins d une minute', () {
    final now = DateTime.utc(2026, 9, 17, 8, 25, 30);
    expect(
      requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now),
      "publiée à l'instant",
    );
  });

  test('minutes', () {
    final now = DateTime.utc(2026, 9, 17, 8, 50);
    expect(
      requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now),
      'publiée il y a 25 min',
    );
  });

  test('heures le même jour : le cas de la capture (06:25 UTC, 08:25 UTC)', () {
    final now = DateTime(2026, 9, 17, 10, 25);
    expect(
      requestTimeLabel(DateTime(2026, 9, 17, 8, 25), now: now),
      'publiée il y a 2 h',
    );
  });

  test('hier', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(DateTime(2026, 9, 16, 8, 25), now: now),
      'publiée hier, 08:25',
    );
  });

  test('plus ancien', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(DateTime(2026, 9, 12, 8, 25), now: now),
      'publiée le 12 sept.',
    );
  });

  // Comparaison calendaire (DateTime(y, m, d - 1)) plutôt que
  // `today.difference(day).inDays == 1` : cette dernière peut tronquer à 0 un
  // jour de 23h/25h réelles (changement d'heure été/hiver), et « hier »
  // n'apparaît alors jamais ce jour-là. Un vrai test de passage à l'heure
  // d'hiver demanderait le paquet `timezone` (données IANA), absent du
  // projet : à défaut, ces tests calendaires couvrent la limite exacte
  // avant/après « hier » que la comparaison par soustraction de jours doit
  // respecter à l'identique.
  test(
    'avant-hier n\'est jamais confondu avec hier (limite calendaire stricte)',
    () {
      final now = DateTime(2026, 9, 17, 9);
      expect(
        requestTimeLabel(DateTime(2026, 9, 15, 22), now: now),
        'publiée le 15 sept.',
      );
    },
  );

  test('hier reste correct juste après minuit (plusieurs heures d\'écart)', () {
    final now = DateTime(2026, 9, 17, 0, 5);
    expect(
      requestTimeLabel(DateTime(2026, 9, 16, 22), now: now),
      'publiée hier, 22:00',
    );
  });

  test('verbe personnalisé', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(DateTime(2026, 9, 12), now: now, verb: 'créée'),
      'créée le 12 sept.',
    );
  });
}
