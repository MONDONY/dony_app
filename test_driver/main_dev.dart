// Point d'entrée de DÉVELOPPEMENT.
//
// Identique à l'application normale, avec en plus le pont `flutter_skill`
// qui donne à un agent IA la main sur l'application en cours d'exécution.
//
// Ce fichier vit hors de `lib/` pour une raison précise : pub interdit à la
// bibliothèque d'un paquet d'importer ses `dev_dependencies`. En le sortant
// de `lib/`, `flutter_skill` cesse d'être une dépendance de production et
// disparaît des dépendances du binaire soumis aux stores.
//
// Lancer avec :
//   flutter run -t test_driver/main_dev.dart --dart-define-from-file=env.dev.json
import 'package:dony/main.dart' as app;
import 'package:flutter_skill/flutter_skill.dart';

Future<void> main() async {
  app.devBindingHook = FlutterSkillBinding.ensureInitialized;
  await app.main();
}
