// E2E smoke : valide que le pipeline integration_test boote l'app authentifiée
// (session Firebase persistée + PIN 123456) et atteint l'accueil.
// Pré-requis : device connecté, app déjà loguée (drissa), PIN 123456.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/app_driver.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot smoke: app authentifiée atteint l\'accueil', (tester) async {
    await launchAndReady(tester);
    // launchAndReady ne retourne qu'une fois l'écran principal atteint
    // (il attend le PIN puis l'option d'accueil). On vérifie qu'on n'est PAS
    // resté bloqué sur l'écran de connexion.
    expect(find.text('Saisissez votre code PIN'), findsNothing,
        reason: 'Encore sur l\'écran PIN — boot non terminé');
    expect(find.textContaining('méthode'), findsNothing,
        reason: 'Sur l\'écran de connexion — session perdue ?');
    // Assertion POSITIVE : le home est réellement rendu (sinon un écran blanc
    // ou un crash au boot passerait les deux findsNothing ci-dessus).
    final atHome = find.byTooltip('Options').evaluate().isNotEmpty ||
        find.text('Rechercher').evaluate().isNotEmpty;
    expect(atHome, isTrue,
        reason: 'Home non atteint (écran blanc / crash au boot ?)');
  });
}
