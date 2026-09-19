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
  });
}
