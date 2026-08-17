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
/// **Configuration à part entière, pas un alias de [kApiBaseUrl].** Une affiche
/// postée sur Facebook n'est plus rappelable : son URL doit pouvoir déménager
/// vers un domaine court sans que l'adresse de l'API bouge, et sans que celle
/// de l'API impose son `context-path` à un lien lu par un humain. Aliaser les
/// deux reviendrait à s'engager à servir `/api/v1/...` pour toujours.
///
/// Le repli sur [kApiBaseUrl] garde le dev et le staging fonctionnels sans
/// configuration supplémentaire : c'est bien le même serveur qui rend la page.
///
/// Volontairement une constante et non une valeur construite au démarrage :
/// l'écran d'affiche doit pouvoir la lire sans dépendre de GetIt, comme le
/// handler FCM d'arrière-plan le fait pour [kApiBaseUrl].
const String posterShareBaseUrl = String.fromEnvironment(
  'POSTER_SHARE_BASE_URL',
  defaultValue: kApiBaseUrl,
);
