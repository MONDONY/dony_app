import 'package:dony/app/deep_link_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isDeepLinkGateLocation', () {
    test(
      'verrou PIN, connexion, onboarding et force-update sont des portes',
      () {
        for (final location in [
          '/auth/local',
          '/auth/method',
          '/auth/otp',
          '/auth/personal-info',
          '/auth/country-selection',
          '/onboarding',
          '/force-update',
        ]) {
          expect(isDeepLinkGateLocation(location), isTrue, reason: location);
        }
      },
    );

    test('les écrans applicatifs laissent passer', () {
      for (final location in [
        '/home',
        '/announcements/abc/trip',
        '/package-requests/abc/public',
        '/bids/abc',
        '/profile',
      ]) {
        expect(isDeepLinkGateLocation(location), isFalse, reason: location);
      }
    });
  });

  group('DeepLinkGate', () {
    late String location;
    late List<String> navigated;
    late DeepLinkGate gate;

    setUp(() {
      location = '/home';
      navigated = [];
      gate = DeepLinkGate(
        currentLocation: () => location,
        navigate: navigated.add,
      );
    });

    test('hors porte : navigue tout de suite, rien en attente', () {
      gate.dispatch('/announcements/abc/trip');

      expect(navigated, ['/announcements/abc/trip']);
      expect(gate.pendingRoute, isNull);
    });

    test('sur le verrou PIN : retient le lien au lieu de le pousser', () {
      location = '/auth/local';

      gate.dispatch('/announcements/abc/trip');

      expect(navigated, isEmpty);
      expect(gate.pendingRoute, '/announcements/abc/trip');
    });

    test('rejoue le lien une fois la porte franchie, une seule fois', () {
      location = '/auth/method';
      gate.dispatch('/package-requests/abc/public');
      // Connexion → verrou PIN : toujours une porte, rien ne bouge.
      location = '/auth/local';
      gate.onLocationChanged();
      expect(navigated, isEmpty);

      location = '/home';
      gate.onLocationChanged();
      expect(navigated, ['/package-requests/abc/public']);
      expect(gate.pendingRoute, isNull);

      // Les changements de route suivants ne rejouent pas.
      location = '/profile';
      gate.onLocationChanged();
      expect(navigated, hasLength(1));
    });

    test('sans lien en attente, un changement de route ne fait rien', () {
      gate.onLocationChanged();

      expect(navigated, isEmpty);
    });

    test('le dernier lien reçu sur une porte remplace le précédent', () {
      location = '/onboarding';
      gate.dispatch('/announcements/aaa/trip');
      gate.dispatch('/announcements/bbb/trip');

      location = '/home';
      gate.onLocationChanged();

      expect(navigated, ['/announcements/bbb/trip']);
    });

    group('écran d\'attente mobile money déjà ouvert (retour Wave)', () {
      const bidAwaiting =
          '/bids/3f2504e0-4f89-41d3-9a0c-0305e82c3301/mobile-money/awaiting';
      const supplementAwaiting =
          '/bids/3f2504e0-4f89-41d3-9a0c-0305e82c3301/supplements/'
          '9b2c4d6e-1f3a-4b5c-8d7e-0a1b2c3d4e5f/mobile-money/awaiting';

      test('colis : le lien vers l\'écran déjà affiché est ignoré', () {
        location = bidAwaiting;

        gate.dispatch(bidAwaiting);

        expect(navigated, isEmpty);
        expect(gate.pendingRoute, isNull);
      });

      test('supplément : le lien vers l\'écran déjà affiché est ignoré', () {
        location = supplementAwaiting;

        gate.dispatch(supplementAwaiting);

        expect(navigated, isEmpty);
      });

      test('casse des UUID indifférente', () {
        location = bidAwaiting;

        gate.dispatch(
          bidAwaiting.replaceFirst(
            '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
            '3F2504E0-4F89-41D3-9A0C-0305E82C3301',
          ),
        );

        expect(navigated, isEmpty);
      });

      test('un autre écran d\'attente reste ouvert normalement', () {
        location = bidAwaiting;

        gate.dispatch(supplementAwaiting);

        expect(navigated, [supplementAwaiting]);
      });

      test('lien retenu sur une porte : pas rejoué si l\'écran visé est déjà '
          'affiché après la porte', () {
        location = '/auth/local';
        gate.dispatch(bidAwaiting);

        location = bidAwaiting;
        gate.onLocationChanged();

        expect(navigated, isEmpty);
        expect(gate.pendingRoute, isNull);
      });

      test('hors attente mobile money, une route identique est toujours '
          'poussée (comportement inchangé)', () {
        location = '/bids/abc';

        gate.dispatch('/bids/abc');

        expect(navigated, ['/bids/abc']);
      });
    });
  });
}
