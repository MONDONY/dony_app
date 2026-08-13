/// URL de base de l'API, figée à la compilation par `--dart-define-from-file`.
///
/// Vit ici plutôt que dans `main.dart` parce que le handler FCM d'arrière-plan
/// s'exécute dans un isolate séparé : il n'a ni GetIt, ni `ApiClient`, ni
/// aucune valeur construite au démarrage de l'app. Une constante compile-time
/// est la seule configuration qui lui parvienne, et elle doit être la même que
/// celle du reste de l'app — d'où la source unique.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);
