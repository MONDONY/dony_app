import 'package:dony/app/app.dart';
import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liste blanche des chemins FIXES atteignables par `yadony://` : un chemin
/// retiré par erreur casse un lien de notification sans autre signal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'les informations fiscales (DAC7) restent ouvrables par lien profond',
    () {
      expect(kAllowedDeepLinkPaths, contains('/profile/tax-info'));
    },
  );

  test('chaque chemin autorisé est une route réelle du routeur', () {
    for (final path in kAllowedDeepLinkPaths) {
      expect(path, startsWith('/'));
      final match = appRouter.configuration.findMatch(Uri.parse(path));
      expect(match.isNotEmpty, isTrue, reason: path);
    }
  });

  test('aucun chemin d\'administration ni générique', () {
    for (final path in kAllowedDeepLinkPaths) {
      expect(path, isNot(startsWith('/admin')));
      expect(path, isNot('/'));
    }
  });
}
