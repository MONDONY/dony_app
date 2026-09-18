import 'package:dony/app/package_request_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le lien `yadony://demande/{uuid}` est imprimé sur la page publique d'une
/// demande d'envoi, partagée sur Facebook et WhatsApp : il est donc
/// atteignable par n'importe qui. La liste blanche de `app.dart` protège les
/// autres liens par égalité stricte, ce que ne permet pas un chemin
/// paramétré, d'où la validation dédiée testée ici.
void main() {
  const uuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  group('resolvePackageRequestDeepLink', () {
    test('résout un UUID valide vers le détail public de la demande', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://demande/$uuid')),
        '/package-requests/$uuid/public',
      );
    });

    test('accepte un UUID en majuscules', () {
      final upper = uuid.toUpperCase();
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://demande/$upper')),
        '/package-requests/$upper/public',
      );
    });

    test('rejette un autre schéma', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('https://demande/$uuid')),
        isNull,
      );
    });

    test('rejette un autre hôte', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://admin/$uuid')),
        isNull,
      );
    });

    test('rejette un identifiant qui n\'est pas un UUID', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://demande/42')),
        isNull,
      );
    });

    test('rejette un segment supplémentaire', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://demande/$uuid/edit')),
        isNull,
      );
    });

    test('rejette un chemin vide', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://demande')),
        isNull,
      );
    });

    /// Sans validation stricte du segment, une correspondance par préfixe
    /// laisserait ce lien atteindre une route non prévue.
    test('rejette une tentative de remontée de chemin', () {
      expect(
        resolvePackageRequestDeepLink(Uri.parse('yadony://demande/../admin')),
        isNull,
      );
    });
  });
}
