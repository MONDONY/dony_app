import 'package:dony/app/parcel_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  group('resolveParcelDeepLink', () {
    test("résout un UUID valide vers l'écran de transition", () {
      expect(
        resolveParcelDeepLink(Uri.parse('yadony://colis/$uuid')),
        '/colis/$uuid',
      );
    });

    test('accepte un UUID en majuscules', () {
      final upper = uuid.toUpperCase();
      expect(
        resolveParcelDeepLink(Uri.parse('yadony://colis/$upper')),
        '/colis/$upper',
      );
    });

    test('ignore un autre schéma', () {
      expect(resolveParcelDeepLink(Uri.parse('https://colis/$uuid')), isNull);
    });

    test('ignore un autre hôte', () {
      expect(
        resolveParcelDeepLink(Uri.parse('yadony://annonce/$uuid')),
        isNull,
      );
    });

    test('ignore un identifiant non UUID', () {
      expect(resolveParcelDeepLink(Uri.parse('yadony://colis/42')), isNull);
    });

    test('ignore un segment en trop', () {
      expect(
        resolveParcelDeepLink(Uri.parse('yadony://colis/$uuid/edit')),
        isNull,
      );
    });

    test("ignore l'absence de segment", () {
      expect(resolveParcelDeepLink(Uri.parse('yadony://colis')), isNull);
    });

    test('ignore une tentative de remontée', () {
      expect(
        resolveParcelDeepLink(Uri.parse('yadony://colis/../admin')),
        isNull,
      );
    });
  });
}
