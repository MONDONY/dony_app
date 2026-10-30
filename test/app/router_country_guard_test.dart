import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
