import 'package:dony/app/announcement_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le lien `dony://annonce/{uuid}` est imprimé sur des affiches publiées sur
/// Facebook et WhatsApp : il est donc atteignable par n'importe qui. La liste
/// blanche de `app.dart` protège les autres liens par égalité stricte, ce que
/// ne permet pas un chemin paramétré, d'où la validation dédiée testée ici.
void main() {
  const uuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  group('resolveAnnouncementDeepLink', () {
    test('résout un UUID valide vers le détail du trajet', () {
      expect(
        resolveAnnouncementDeepLink(Uri.parse('dony://annonce/$uuid')),
        '/announcements/$uuid/trip',
      );
    });

    test('accepte un UUID en majuscules', () {
      final upper = uuid.toUpperCase();
      expect(
        resolveAnnouncementDeepLink(Uri.parse('dony://annonce/$upper')),
        '/announcements/$upper/trip',
      );
    });

    test('rejette un autre schéma', () {
      expect(
        resolveAnnouncementDeepLink(Uri.parse('https://annonce/$uuid')),
        isNull,
      );
    });

    test('rejette un autre hôte', () {
      expect(
        resolveAnnouncementDeepLink(Uri.parse('dony://admin/$uuid')),
        isNull,
      );
    });

    test('rejette un identifiant qui n\'est pas un UUID', () {
      expect(
        resolveAnnouncementDeepLink(Uri.parse('dony://annonce/42')),
        isNull,
      );
    });

    test('rejette un segment supplémentaire', () {
      expect(
        resolveAnnouncementDeepLink(Uri.parse('dony://annonce/$uuid/edit')),
        isNull,
      );
    });

    test('rejette un chemin vide', () {
      expect(resolveAnnouncementDeepLink(Uri.parse('dony://annonce')), isNull);
    });

    /// Sans validation stricte du segment, une correspondance par préfixe
    /// laisserait ce lien atteindre une route non prévue.
    test('rejette une tentative de remontée de chemin', () {
      expect(
        resolveAnnouncementDeepLink(Uri.parse('dony://annonce/../admin')),
        isNull,
      );
    });
  });
}
