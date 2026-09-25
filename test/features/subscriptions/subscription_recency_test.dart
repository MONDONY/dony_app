import 'package:dony/features/subscriptions/presentation/widgets/subscription_recency.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);
  final now = DateTime(2026, 9, 1, 12);

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  String label(Duration ago) =>
      subscriptionRecencyLabel(fr, now.subtract(ago), now: now);

  test('moins d\'une minute → à l\'instant', () {
    expect(label(const Duration(seconds: 20)), "à l'instant");
  });

  test('moins d\'une minute → en anglais', () {
    expect(
      subscriptionRecencyLabel(
        en,
        now.subtract(const Duration(seconds: 20)),
        now: now,
      ),
      'just now',
    );
  });

  test('minutes puis heures', () {
    expect(label(const Duration(minutes: 5)), 'il y a 5 min');
    expect(label(const Duration(minutes: 59)), 'il y a 59 min');
    expect(label(const Duration(hours: 2)), 'il y a 2 h');
    expect(label(const Duration(hours: 23)), 'il y a 23 h');
  });

  test('minutes puis heures — en anglais', () {
    expect(
      subscriptionRecencyLabel(
        en,
        now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      '5 min ago',
    );
    expect(
      subscriptionRecencyLabel(
        en,
        now.subtract(const Duration(hours: 2)),
        now: now,
      ),
      '2 h ago',
    );
  });

  test('hier, puis jours', () {
    expect(label(const Duration(days: 1)), 'hier');
    expect(label(const Duration(days: 3)), 'il y a 3 j');
  });

  test('hier, puis jours — en anglais', () {
    expect(
      subscriptionRecencyLabel(
        en,
        now.subtract(const Duration(days: 1)),
        now: now,
      ),
      'yesterday',
    );
    expect(
      subscriptionRecencyLabel(
        en,
        now.subtract(const Duration(days: 3)),
        now: now,
      ),
      '3d ago',
    );
  });

  test('date future → à l\'instant plutôt qu\'une durée négative', () {
    expect(
      subscriptionRecencyLabel(
        fr,
        now.add(const Duration(minutes: 3)),
        now: now,
      ),
      "à l'instant",
    );
  });

  // ─── Au-delà d'une semaine : les douze mois, jour 27 (spec 4.4) ────────────
  //
  // Le rendu français doit égaler l'ancien `'${day} ${_kMoisAbreges[month]}'`
  // pour chaque mois, table aujourd'hui supprimée.
  group(
    'au-delà d\'une semaine — les douze mois (fr égal à l\'ancienne table)',
    () {
      const expectedFr = <int, String>{
        1: '27 janv.',
        2: '27 févr.',
        3: '27 mars',
        4: '27 avr.',
        5: '27 mai',
        6: '27 juin',
        7: '27 juil.',
        8: '27 août',
        9: '27 sept.',
        10: '27 oct.',
        11: '27 nov.',
        12: '27 déc.',
      };

      for (final entry in expectedFr.entries) {
        test('mois ${entry.key}', () {
          // `now` est fixé loin après la date publiée pour rester dans la
          // branche "date courte" (diff.inDays >= 7).
          final published = DateTime(2026, entry.key, 27);
          final reference = published.add(const Duration(days: 20));
          expect(
            subscriptionRecencyLabel(fr, published, now: reference),
            entry.value,
          );
        });
      }
    },
  );

  group('date de départ', () {
    String depart(DateTime d) => subscriptionDepartureLabel(fr, d, now: now);

    test('départ proche → jour et mois, sans année', () {
      expect(depart(DateTime(2026, 9, 27)), '27 sept.');
      expect(depart(DateTime(2027, 8, 30)), '30 août');
    });

    test('départ au-delà de douze mois → année ajoutée', () {
      // Sans l'année, « 3 janv. » pour un départ en 2028 serait trompeur.
      expect(depart(DateTime(2028, 1, 3)), '3 janv. 2028');
    });

    test('départ passé → affiché tel quel, sans année', () {
      expect(depart(DateTime(2026, 7, 4)), '4 juil.');
    });

    test('départ lointain → égal à l\'ancien rendu concaténé', () {
      expect(depart(DateTime(2027, 9, 27)), '27 sept. 2027');
    });

    test('départ proche — en anglais', () {
      expect(
        subscriptionDepartureLabel(en, DateTime(2026, 9, 27), now: now),
        'Sep 27',
      );
    });

    test('départ lointain — en anglais', () {
      expect(
        subscriptionDepartureLabel(en, DateTime(2027, 9, 27), now: now),
        'Sep 27, 2027',
      );
    });
  });
}
