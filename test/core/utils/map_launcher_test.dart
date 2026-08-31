import 'package:dony/core/utils/map_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMapUri', () {
    const lat = 43.2965;
    const lng = 5.3698;

    test('iOS → Apple Plans (maps.apple.com, https)', () {
      final uri = buildMapUri(
        lat: lat,
        lng: lng,
        label: 'Marseille, France',
        isApple: true,
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['ll'], '43.2965,5.3698');
      expect(uri.queryParameters['q'], 'Marseille, France');
    });

    test('Android → Google Maps (google.com/maps, https)', () {
      final uri = buildMapUri(
        lat: lat,
        lng: lng,
        label: 'Marseille, France',
        isApple: false,
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, startsWith('/maps'));
      expect(uri.queryParameters['query'], '43.2965,5.3698');
    });

    test('label nul → URI valide, coordonnées présentes, pas de q', () {
      final apple = buildMapUri(lat: lat, lng: lng, isApple: true);
      final google = buildMapUri(lat: lat, lng: lng, isApple: false);
      expect(apple.queryParameters['ll'], '43.2965,5.3698');
      expect(apple.queryParameters.containsKey('q'), isFalse);
      expect(google.queryParameters['query'], '43.2965,5.3698');
    });

    test('label avec caractères spéciaux : re-décodé identique, https valide', () {
      const label = "Abobo, Abidjan, Côte d'Ivoire";
      final uri = buildMapUri(lat: lat, lng: lng, label: label, isApple: true);
      expect(uri.queryParameters['q'], label);
      expect(uri.toString(), startsWith('https://maps.apple.com/'));
      // Aucune espace brute dans la chaîne encodée.
      expect(uri.toString(), isNot(contains(' ')));
    });
  });
}
