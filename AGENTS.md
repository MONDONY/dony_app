# AGENTS.md

## Projet et stack

`dony_app` est l'application Flutter de dony, marketplace P2P de transport de colis
par des voyageurs vers l'Afrique.

- Flutter/Dart, `flutter_bloc`, GoRouter, Dio, GetIt et Hive.
- Firebase Auth, Stripe, FCM et Sentry.
- iOS 14+ et Android 8.0+ (API 26).
- Architecture feature-first; backend = source de vérité.

Avant une story, lire `../docs-claude/docs/stories/epic-XX-*.md`, ses critères
Given/When/Then et les contrats API concernés.

## Démarrage rapide Android sous WSL2

L'IP WSL2 change après un redémarrage. Démarrer le backend, mettre à jour
`env.dev.json`, puis lancer l'émulateur :

```bash
cd /mnt/c/Users/abou5/Desktop/mon-dony/dony-back
./mvnw spring-boot:run -Dspring.profiles.active=dev

WSL_IP=$(hostname -I | awk '{print $1}') && \
sed -i "s|\"API_BASE_URL\": \"http://[^\"]*\"|\"API_BASE_URL\": \"http://$WSL_IP:8080/api/v1\"|" env.dev.json

adb devices
flutter run --dart-define-from-file=env.dev.json -d emulator-5554
```

Le manifeste debug autorise le HTTP local. En cas d'échec : renouveler l'IP, vérifier
`server.address=0.0.0.0`, ou redémarrer ADB avec
`adb kill-server && adb start-server`.

## Commandes

Conserver ces commandes de référence :

```bash
# Dev
flutter run --dart-define-from-file=env.dev.json [-d <device-id>]
flutter clean && flutter pub get && flutter run --dart-define-from-file=env.dev.json

# Qualité
flutter analyze && dart fix --apply && dart format lib/ test/

# Tests
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Build
flutter build apk --dart-define-from-file=env.prod.json --release
flutter build appbundle --dart-define-from-file=env.prod.json --release

# Code gen
flutter pub run build_runner build --delete-conflicting-outputs
```

Les fichiers d'environnement contiennent `API_BASE_URL`, `FIREBASE_PROJECT_ID`,
`STRIPE_PUBLISHABLE_KEY` et `SENTRY_DSN`. Ne jamais hardcoder ces valeurs.

## Architecture feature-first

Chaque feature sous `lib/features/` contient exactement :

```text
feature/
├── bloc/
├── data/
│   ├── models/
│   ├── repositories/
│   └── datasources/
└── presentation/
```

- `lib/app/router.dart` contient toutes les routes.
- `lib/core/di/injection.dart` contient les enregistrements GetIt.
- `lib/core/network/` contient l'unique client Dio et `AuthInterceptor`.
- `lib/core/storage/` contient le stockage local partagé.
- `cancellation/` reste une feature dédiée, jamais incluse dans `matching/`.
- Le design system est sous `lib/core/design/`; ses règles plus spécifiques sont
  dans `lib/core/design/AGENTS.md`.

## BLoC, navigation, réseau et injection

- Aucun `setState`. Tout état de feature passe par `flutter_bloc`.
- Événements suffixés `Requested`; states scellés `Initial`, `Loading`,
  `Success`/état métier et `Error`.
- Utiliser `BlocConsumer` : `listener` pour navigation/snackbar, `builder` pour l'UI.
- Aucun `Navigator.push()`. Utiliser GoRouter :
  `context.go`, `context.push` et `context.pop`, avec auth guard dans `router.dart`.
- Conserver les deep links existants :
  `dony://payment/confirm?payment_intent=pi_xxx`,
  `dony://tracking/scan?bid_id=xxx` et
  `https://dony.app/tracking/{token}`.
- Aucun package `http`. Utiliser l'instance Dio unique et `AuthInterceptor`.
- Dio : timeout de connexion 10 s, timeout de réception 30 s et retry avec
  backoff exponentiel sur les erreurs réseau.
- Ne jamais instancier service, repository ou BLoC dans un widget. GetIt :
  singletons paresseux pour core/repositories/datasources, factories pour les BLoCs.
- La validation client améliore l'UX; le backend reste la source de vérité.

Après une navigation qui peut modifier des données :

- `await context.push<bool>(...)`, puis recharger si le résultat vaut `true`;
- l'écran fils retourne `context.pop(true)` après un succès réel;
- `await Sheet.show(...)`, puis recharger pour un BLoC distinct;
- ne pas recharger si le parent et la sheet partagent explicitement le même BLoC.

## Hive, offline, photo, GPS et paiements

- Hive sert uniquement au PIN chiffré et à la queue QR offline.
- Ne jamais stocker token Firebase, données KYC ou données sensibles en clair dans
  Hive. Lire l'utilisateur via `FirebaseAuth.instance.currentUser`.
- Un scan QR hors ligne est mis en queue puis synchronisé automatiquement à la
  reconnexion en moins de 30 s.
- Capturer le GPS avant la photo et écrire les coordonnées dans les métadonnées
  EXIF. Photo : qualité 85 %, 1920×1080 maximum, 10 MB maximum.
- Avant tout paiement, appeler `requirePaymentAuth`. Biométrie et PIN sont
  facultatifs; s'il n'existe aucune protection locale configurée, le paiement
  continue.
- FCM : mettre à jour le token au démarrage et sur `onTokenRefresh`; acquitter les
  notifications critiques.
- Le handler FCM background est une fonction top-level annotée
  `@pragma('vm:entry-point')`.

## Analytics

- Tout nouvel écran et toute nouvelle action métier doivent être trackés.
- GoRouter et `PosthogObserver` assurent le screen tracking de navigation.
- Déclarer chaque nom dans `AnalyticsEvents`; aucune chaîne d'event inline.
- Tirer les événements métier dans le BLoC après succès. Les événements de vue ou
  d'intention peuvent partir de `initState` via `addPostFrameCallback`.
- Injecter `AnalyticsService` dans tout nouveau BLoC.
- Utiliser `unawaited(_analytics.logEvent(...))` pour ne jamais bloquer le flux.
- Aucune PII dans les propriétés analytics : pas de téléphone, email, nom, adresse
  exacte, token ni valeur exacte sensible.
- Lors de toute modification d'un écran existant, vérifier et mettre à jour le
  tracking des actions modifiées, ajoutées ou supprimées.
- Le consentement RGPD utilise
  `AnalyticsService.setConsent({required granted, source})`. Toujours fournir
  `source` : `manual`, `auto_non_gdpr` ou `settings`.
- `setConsent` écrit dans Hive puis pousse au backend avec
  `PUT /auth/me/analytics-consent`; le backend est la source de vérité, Hive n'est
  qu'un cache et `audit_log` constitue la preuve légale.
- Le payload de consentement ne contient que `granted`, `policyVersion` et `source`,
  sans PII.
- Au login, `AnalyticsService.syncFromBackend()` réconcilie le cache. Toute nouvelle
  décision doit appeler `syncFromBackend()` avant de tester `hasAnswered`.

## Bottom sheets : bouton sticky obligatoire

Tout `DonyButton` d'un bottom sheet doit être placé dans `stickyBottom`, jamais dans
le `child` scrollable :

```dart
// Correct
DonyBottomSheet.show(
  context,
  stickyBottom: DonyButton(label: 'Confirmer', onPressed: ...),
  child: MyContent(),
);

// Interdit
DonyBottomSheet.show(
  context,
  child: Column(children: [
    MyContent(),
    DonyButton(label: 'Confirmer', onPressed: ...),
  ]),
);
```

| Cas | Pattern |
| --- | --- |
| Bouton simple | `stickyBottom: DonyButton(...)` |
| État BLoC | `wrapper: (child) => BlocProvider(...)` et `BlocBuilder` dans `stickyBottom` |
| Validité locale | `ValueNotifier<bool>` et `ValueListenableBuilder` dans `stickyBottom` |
| État local + BLoC | `ValueListenableBuilder` puis `BlocBuilder` |
| Sheet multi-états | `ValueNotifier<_BtnConfig?>` mis à jour après la frame |

`useRootNavigator: true` est déjà forcé par `DonyBottomSheet.show()`. Disposer les
`ValueNotifier` créés dans `show()` avec `.whenComplete(notifier.dispose)`. Utiliser
`wrapper` lorsque le contenu et `stickyBottom` doivent partager le même BLoC.

## Design et accessibilité

- Importer le design system via
  `package:dony/core/design/design_system.dart`.
- Pour tout travail UI, charger et appliquer le skill Codex
  `make-interfaces-feel-better`, puis respecter `lib/core/design/AGENTS.md`.
- Apple HIG et Material 3 sont obligatoires.
- Touch targets d'au moins 44×44, `Semantics` sur les contrôles sans texte,
  `tooltip` sur les `IconButton`, et contraste d'au moins 4.5:1.
- Ne jamais communiquer une information uniquement par la couleur.
- Ne jamais utiliser `Icons.local_shipping*` : dony transporte en bagage voyageur.
  Préférer `Icons.inventory_2_rounded`, `Icons.flight_rounded` ou
  `Icons.outbox_rounded`.

## Git

- Ne jamais commit directement sur `main`.
- Utiliser une branche `feature/<nom>`, `fix/<nom>` ou `chore/<nom>`.
- Ne jamais ajouter de ligne `Co-Authored-By: Codex`; les commits restent au nom du
  développeur.
- Ne pas inclure de secret, fichier d'environnement ou changement hors périmètre.

## Sécurité release

- HTTPS uniquement et SSL pinning activé en production.
- ProGuard/R8 et obfuscation activés pour les builds release.
- Aucune donnée sensible dans les logs de production.
- Firebase ID token auto-refreshé et jamais stocké dans Hive.
- Sentry configuré sans PII ni secret.

## Tests et couverture

Après toute feature, correction ou modification de code :

```bash
flutter analyze
flutter test --coverage
```

La couverture globale exigée est d'au moins 90 %.

- BLoC : `blocTest<XBloc, XState>` couvrant events, transitions et erreurs.
- Widgets critiques : `pumpWidget`, loading, error, success, validation et
  navigation.
- Ajouter un test de régression pour chaque bug.
- Tout nouveau code et ses tests restent dans le même commit.
- Ne pas ignorer un test rouge ni abaisser le seuil de couverture.

## Definition of Done

- Tous les Given/When/Then sont couverts.
- BLoC, GoRouter, Dio, GetIt et règles offline/sécurité sont respectés.
- Les nouveaux écrans et actions ont leur analytics sans PII.
- Loading, erreur, succès et accessibilité sont vérifiés.
- Tout bouton de bottom sheet est dans `stickyBottom`.
- `flutter analyze` et `flutter test --coverage` passent; couverture globale ≥ 90 %.
- La documentation de story terminée est créée dans
  `docs/stories-done/story-<epic>.<numero>-<slug>.md` seulement après ces
  vérifications.
