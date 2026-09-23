import 'package:dony/features/package_request/presentation/request_time_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  test('moins d une minute', () {
    final now = DateTime.utc(2026, 9, 17, 8, 25, 30);
    expect(
      requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now, l10n: fr),
      "publiée à l'instant",
    );
  });

  test('moins d une minute (en)', () {
    final now = DateTime.utc(2026, 9, 17, 8, 25, 30);
    expect(
      requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now, l10n: en),
      'posted just now',
    );
  });

  test('minutes', () {
    final now = DateTime.utc(2026, 9, 17, 8, 50);
    expect(
      requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now, l10n: fr),
      'publiée il y a 25 min',
    );
  });

  test('minutes (en)', () {
    final now = DateTime.utc(2026, 9, 17, 8, 50);
    expect(
      requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now, l10n: en),
      'posted 25 min ago',
    );
  });

  test('heures le même jour : le cas de la capture (06:25 UTC, 08:25 UTC)', () {
    final now = DateTime(2026, 9, 17, 10, 25);
    expect(
      requestTimeLabel(DateTime(2026, 9, 17, 8, 25), now: now, l10n: fr),
      'publiée il y a 2 h',
    );
  });

  test('heures le même jour (en)', () {
    final now = DateTime(2026, 9, 17, 10, 25);
    expect(
      requestTimeLabel(DateTime(2026, 9, 17, 8, 25), now: now, l10n: en),
      'posted 2 h ago',
    );
  });

  test('hier', () {
    final now = DateTime(2026, 9, 17, 9);
    final d = DateTime(2026, 9, 16, 8, 25);
    expect(
      requestTimeLabel(d, now: now, l10n: fr),
      'publiée hier, ${DateFormat.jm('fr').format(d)}',
    );
  });

  test('hier (en)', () {
    final now = DateTime(2026, 9, 17, 9);
    final d = DateTime(2026, 9, 16, 8, 25);
    expect(
      requestTimeLabel(d, now: now, l10n: en),
      'posted yesterday, ${DateFormat.jm('en').format(d)}',
    );
  });

  test('plus ancien', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(DateTime(2026, 9, 12, 8, 25), now: now, l10n: fr),
      'publiée le 12 sept.',
    );
  });

  test('plus ancien (en)', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(DateTime(2026, 9, 12, 8, 25), now: now, l10n: en),
      'posted on Sep 12',
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
        requestTimeLabel(DateTime(2026, 9, 15, 22), now: now, l10n: fr),
        'publiée le 15 sept.',
      );
    },
  );

  test('hier reste correct juste après minuit (plusieurs heures d\'écart)', () {
    final now = DateTime(2026, 9, 17, 0, 5);
    final d = DateTime(2026, 9, 16, 22);
    expect(
      requestTimeLabel(d, now: now, l10n: fr),
      'publiée hier, ${DateFormat.jm('fr').format(d)}',
    );
  });

  test('verbe personnalisé', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(
        DateTime(2026, 9, 12),
        now: now,
        l10n: fr,
        verb: RequestTimeVerb.created,
      ),
      'créée le 12 sept.',
    );
  });

  test('verbe personnalisé (en)', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(
      requestTimeLabel(
        DateTime(2026, 9, 12),
        now: now,
        l10n: en,
        verb: RequestTimeVerb.created,
      ),
      'created on Sep 12',
    );
  });
}
