import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCountryEmpty', () {
    final cases = <(String?, String?, bool)>[
      (null, null, true),
      ('', '', true),
      ('  ', '\t', true),
      ('FR', null, false),
      ('FR', '', false),
      // Réinstallation : Hive vide, le serveur connaît le pays.
      (null, 'FR', false),
      ('', ' SN ', false),
      ('FR', 'SN', false),
    ];
    for (final (hive, synced, empty) in cases) {
      test('Hive "$hive" + serveur "$synced" -> $empty', () {
        expect(isCountryEmpty(hiveCountry: hive, syncedCountry: synced), empty);
      });
    }
  });

  const next = '/auth/country-selection?next=%2Ftrips%2Fcreate';

  group('resolveCountryGuardRedirect', () {
    test('pays vide redirige vers la sélection avec next', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: true,
          travelerCountryUnsupported: false,
        ),
        next,
      );
    });

    test('pays renseigné laisse passer', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: false,
          travelerCountryUnsupported: false,
        ),
        isNull,
      );
    });

    test('kTravelerCountryUnsupported garde son comportement, avec next', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/trips/create',
          countryEmpty: false,
          travelerCountryUnsupported: true,
        ),
        next,
      );
    });

    test('une autre route n\'est pas gardée', () {
      expect(
        resolveCountryGuardRedirect(
          path: '/home',
          countryEmpty: true,
          travelerCountryUnsupported: true,
        ),
        isNull,
      );
    });
  });
}
