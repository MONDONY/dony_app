import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

/// La route `/profile/upgrade-to-pro` n'a plus d'entrée dans l'interface
/// quand l'offre PRO est fermée, mais un lien profond ou une ancienne
/// notification peuvent encore la viser : seule sa garde l'en protège.
void main() {
  test('offre PRO fermée : renvoyé vers le profil', () {
    expect(resolveProRouteRedirect(proEnabled: false), '/profile');
  });

  test('offre PRO ouverte : aucune redirection', () {
    expect(resolveProRouteRedirect(proEnabled: true), isNull);
  });
}
