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

/// Base des liens publics imprimés sur les affiches de trajet et collés par le
/// voyageur dans ses publications.
///
/// Dérivée de [kApiBaseUrl] parce que la page publique est servie par le même
/// backend, sous son `context-path` `/api/v1`. Le jour où un domaine court est
/// mis en place, seule cette valeur change : les affiches déjà publiées
/// continuent de fonctionner, l'ancienne URL restant servie.
///
/// Volontairement une constante et non une valeur construite au démarrage :
/// l'écran d'affiche doit pouvoir la lire sans dépendre de GetIt, comme le
/// handler FCM d'arrière-plan le fait pour [kApiBaseUrl].
const String defaultPosterShareBaseUrl = kApiBaseUrl;
