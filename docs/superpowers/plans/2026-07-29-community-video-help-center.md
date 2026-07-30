# Centre d’aide communautaire et tutoriels vidéo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrichir le Centre d’aide Yadony avec des liens communautaires configurables, neuf tutoriels YouTube lus dans l’application et des accès contextuels depuis les parcours critiques.

**Architecture:** Firebase Remote Config fournit un JSON versionné, validé par un repository de la feature `profile`. Un `HelpCenterBloc` global expose le dernier catalogue valide aux écrans, porte les actions externes et centralise les événements analytics ; le lecteur YouTube reste un écran dédié piloté par GoRouter.

**Tech Stack:** Flutter/Dart, flutter_bloc, GetIt, GoRouter, Firebase Remote Config, `youtube_player_iframe`, `url_launcher`, flutter_animate, PostHog via `AnalyticsService`.

## Global Constraints

- Toute copie publique utilise exactement « Yadony ».
- iOS 14+ et Android 8.0+ (API 26).
- Aucun `setState` dans les features ; l’état fonctionnel passe par BLoC.
- Toute navigation passe par GoRouter.
- Tout nouveau BLoC reçoit `AnalyticsService` via GetIt.
- Tous les appels analytics sont `unawaited()` et ne contiennent aucune PII.
- Les URL sociales et vidéo ne sont jamais codées dans les widgets.
- Une configuration invalide ne bloque ni le démarrage ni la FAQ existante.
- Toutes les cibles tactiles font au moins 44 × 44 et les textes utilisent Plus Jakarta Sans avec une taille minimale de 12.
- Ne jamais utiliser `Icons.local_shipping*`.
- Préserver les modifications locales hors périmètre.

## File Map

**Créations**

- `lib/features/profile/data/models/help_center_config.dart` — modèles, enums et validation JSON.
- `lib/features/profile/data/datasources/help_center_remote_config_datasource.dart` — abstraction Remote Config mockable.
- `lib/features/profile/data/repositories/help_center_repository.dart` — valeur active, rafraîchissement et ouverture externe.
- `lib/features/profile/bloc/help_center_bloc.dart` — chargement, sélection et analytics.
- `lib/features/profile/bloc/help_center_event.dart` — événements suffixés `Requested`.
- `lib/features/profile/bloc/help_center_state.dart` — états sealed.
- `lib/features/profile/presentation/widgets/help_tutorial_card.dart` — carte catalogue 16:9.
- `lib/features/profile/presentation/widgets/contextual_tutorial_card.dart` — accès compact réutilisable.
- `lib/features/profile/presentation/widgets/social_community_section.dart` — réseaux actifs.
- `lib/features/profile/presentation/screens/help_tutorial_screen.dart` — lecteur intégré.
- `assets/config/help_center_config.default.json` — fallback vide valide et exemple de schéma.
- Tests unitaires et widgets détaillés avec leur chemin exact dans chaque tâche.

**Modifications**

- `pubspec.yaml`, `pubspec.lock` — Remote Config, lecteur et asset.
- `lib/core/di/injection.dart` — datasource, repository et BLoC.
- `lib/app/app.dart` — provider global du catalogue.
- `lib/app/router.dart` — route du lecteur.
- `lib/core/services/analytics_events.dart`, `CLAUDE.md` — événements.
- `lib/features/profile/presentation/screens/faq_screen.dart` — hub en trois blocs.
- Neuf écrans d’intégration listés dans Task 7.

---

### Task 1: Modèles stricts et configuration par défaut

**Files:**
- Create: `lib/features/profile/data/models/help_center_config.dart`
- Create: `assets/config/help_center_config.default.json`
- Modify: `pubspec.yaml`
- Test: `test/features/profile/data/models/help_center_config_test.dart`

**Interfaces:**
- Consumes: un `Map<String, dynamic>` issu du JSON Remote Config.
- Produces: `HelpCenterConfig.fromJson(Map<String, dynamic>)`, `HelpTutorial`, `SocialLink`, `TutorialContext`, `SocialNetwork`.

- [ ] **Step 1: Ajouter les tests de parsing en échec**

Écrire des tests couvrant : configuration complète, `schemaVersion != 1`,
URL non HTTPS, identifiant vidéo invalide, identifiant tutoriel dupliqué,
contexte inconnu et conservation des autres entrées valides.

```dart
test('ignore une entrée sociale invalide sans perdre le catalogue', () {
  final config = HelpCenterConfig.fromJson({
    'schemaVersion': 1,
    'youtubeChannelUrl': 'https://www.youtube.com/@yadony',
    'socialLinks': [
      {'network': 'whatsapp', 'url': 'javascript:alert(1)', 'active': true},
      {
        'network': 'instagram',
        'url': 'https://instagram.com/yadony',
        'active': true,
      },
    ],
    'tutorials': validTutorialsJson,
  });

  expect(config.socialLinks.map((item) => item.network),
      [SocialNetwork.instagram]);
  expect(config.tutorials, isNotEmpty);
});
```

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/data/models/help_center_config_test.dart`

Expected: FAIL car les modèles n’existent pas.

- [ ] **Step 3: Implémenter les types et la validation**

Définir :

```dart
enum SocialNetwork { whatsapp, facebook, instagram, tiktok, youtube }

enum TutorialContext {
  search,
  activities,
  tripPublish,
  requestPublish,
  negotiation,
  payment,
  qrHandover,
  tracking,
  dispute,
}

final class HelpTutorial extends Equatable {
  const HelpTutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.youtubeVideoId,
    required this.order,
    required this.active,
    required this.contexts,
    this.durationLabel,
  });
  // Champs + props.
}

final class HelpCenterConfig extends Equatable {
  const HelpCenterConfig({
    required this.schemaVersion,
    required this.socialLinks,
    required this.tutorials,
    this.youtubeChannelUrl,
  });

  static const empty = HelpCenterConfig(
    schemaVersion: 1,
    socialLinks: [],
    tutorials: [],
  );

  factory HelpCenterConfig.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('unsupported_schema');
    }
    return HelpCenterConfig(
      schemaVersion: 1,
      socialLinks: parseValidSocialLinks(json['socialLinks']),
      tutorials: parseValidTutorials(json['tutorials'])
        ..sort((a, b) => a.order.compareTo(b.order)),
      youtubeChannelUrl: parseHttpsUri(json['youtubeChannelUrl']),
    );
  }

  HelpTutorial? tutorialFor(TutorialContext context) {
    for (final item in tutorials) {
      if (item.active && item.contexts.contains(context)) return item;
    }
    return null;
  }

  HelpTutorial? tutorialById(String id) {
    for (final item in tutorials) {
      if (item.active && item.id == id) return item;
    }
    return null;
  }
}
```

Valider `^[A-Za-z0-9_-]{11}$` pour les identifiants vidéo et n’accepter que
les URL `https` ayant un host non vide. Trier les tutoriels par `order`.
Définir dans le même fichier les trois helpers privés utilisés ci-dessus :
`parseValidSocialLinks(Object?)`, `parseValidTutorials(Object?)` et
`parseHttpsUri(Object?)`. Les deux premiers parcourent uniquement une `List`,
capturent `FormatException` entrée par entrée et éliminent les identifiants
dupliqués avec un `Set<String>`.

- [ ] **Step 4: Ajouter le fallback asset**

```json
{
  "schemaVersion": 1,
  "youtubeChannelUrl": null,
  "socialLinks": [],
  "tutorials": []
}
```

Déclarer `assets/config/help_center_config.default.json` dans `pubspec.yaml`.

- [ ] **Step 5: Vérifier et committer**

Run: `flutter test test/features/profile/data/models/help_center_config_test.dart`

Expected: PASS.

```bash
git add pubspec.yaml assets/config/help_center_config.default.json lib/features/profile/data/models/help_center_config.dart test/features/profile/data/models/help_center_config_test.dart
git commit -m "feat(help): modéliser le catalogue distant"
```

### Task 2: Datasource Remote Config et repository résilient

**Files:**
- Create: `lib/features/profile/data/datasources/help_center_remote_config_datasource.dart`
- Create: `lib/features/profile/data/repositories/help_center_repository.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Test: `test/features/profile/data/repositories/help_center_repository_test.dart`

**Interfaces:**
- Consumes: clé `help_center_config_v1`, `FirebaseRemoteConfig`, fallback asset et `UrlLauncherPlatform`.
- Produces: `Future<HelpCenterConfig> load()`, `Future<HelpCenterConfig> refresh()`, `Future<bool> openExternal(Uri uri)`.

- [ ] **Step 1: Ajouter les dépendances**

Run:

```bash
flutter pub add firebase_remote_config
flutter pub add youtube_player_iframe
```

Expected: résolution réussie et lockfile mis à jour.

- [ ] **Step 2: Écrire les tests repository en échec**

Créer une interface datasource injectée :

```dart
abstract interface class HelpCenterConfigSource {
  String get activatedJson;
  Future<String?> fetchAndActivate();
}
```

Tester :

- `load()` parse la valeur activée ;
- valeur activée vide → fallback asset ;
- `refresh()` retourne et mémorise la nouvelle valeur valide ;
- fetch en erreur → dernière configuration valide ;
- nouveau JSON invalide → dernière configuration valide ;
- `openExternal` refuse un schéma non HTTPS.

- [ ] **Step 3: Vérifier l’échec**

Run: `flutter test test/features/profile/data/repositories/help_center_repository_test.dart`

Expected: FAIL car datasource et repository n’existent pas.

- [ ] **Step 4: Implémenter Firebase Remote Config**

Configurer `FirebaseRemoteConfig.instance` avec un timeout de 10 secondes, un
intervalle minimal de 5 minutes en développement et 12 heures en production.
Appeler `setDefaults({'help_center_config_v1': fallbackJson})`, puis
`fetchAndActivate()`. Ne jamais laisser remonter une exception Firebase au
démarrage.

Le repository garde `_lastValid = HelpCenterConfig.empty`, parse chaque valeur
dans un bloc protégé et ne remplace `_lastValid` qu’après validation.

- [ ] **Step 5: Vérifier et committer**

Run: `flutter test test/features/profile/data/repositories/help_center_repository_test.dart`

Expected: PASS.

```bash
git add pubspec.yaml pubspec.lock lib/features/profile/data/datasources/help_center_remote_config_datasource.dart lib/features/profile/data/repositories/help_center_repository.dart test/features/profile/data/repositories/help_center_repository_test.dart
git commit -m "feat(help): charger la configuration distante"
```

### Task 3: HelpCenterBloc, DI globale et analytics

**Files:**
- Create: `lib/features/profile/bloc/help_center_bloc.dart`
- Create: `lib/features/profile/bloc/help_center_event.dart`
- Create: `lib/features/profile/bloc/help_center_state.dart`
- Modify: `lib/core/di/injection.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Test: `test/features/profile/bloc/help_center_bloc_test.dart`

**Interfaces:**
- Consumes: `HelpCenterRepository`, `AnalyticsService`.
- Produces: `HelpCenterLoadRequested`, `HelpTutorialOpenRequested`, `HelpTutorialPlaybackRequested`, `HelpExternalOpenRequested`, `HelpCenterState`.

- [ ] **Step 1: Écrire les tests BLoC en échec**

Tester les séquences :

```dart
blocTest<HelpCenterBloc, HelpCenterState>(
  'publie le cache puis la configuration rafraîchie',
  build: () => HelpCenterBloc(repository, analytics),
  act: (bloc) => bloc.add(const HelpCenterLoadRequested()),
  expect: () => [
    const HelpCenterLoading(),
    HelpCenterSuccess(cachedConfig, isRefreshing: true),
    HelpCenterSuccess(remoteConfig),
  ],
);
```

Tester aussi l’erreur avec données précédentes, l’ouverture d’un tutoriel avec
`tutorial_id/source`, le démarrage et la fin, chaque réseau, l’abonnement et
les raisons fermées `fetch`, `parse`, `launch`.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/bloc/help_center_bloc_test.dart`

Expected: FAIL car le BLoC n’existe pas.

- [ ] **Step 3: Implémenter événements et états**

Utiliser des événements suffixés `Requested` :

```dart
final class HelpTutorialOpenRequested extends HelpCenterEvent {
  const HelpTutorialOpenRequested({
    required this.tutorialId,
    required this.source,
  });
  final String tutorialId;
  final TutorialContext? source; // null = help_center
}

enum HelpPlaybackAction { started, completed }

sealed class HelpCenterState extends Equatable { const HelpCenterState(); }
final class HelpCenterInitial extends HelpCenterState { const HelpCenterInitial(); }
final class HelpCenterLoading extends HelpCenterState { const HelpCenterLoading(); }
final class HelpCenterSuccess extends HelpCenterState {
  const HelpCenterSuccess(this.config, {this.isRefreshing = false});
  final HelpCenterConfig config;
  final bool isRefreshing;
}
final class HelpCenterError extends HelpCenterState {
  const HelpCenterError(this.reason, {required this.config});
  final String reason;
  final HelpCenterConfig config;
}
```

Tous les handlers analytics utilisent ce pattern :

```dart
unawaited(
  _analytics.logEvent(
    AnalyticsEvents.helpTutorialOpened,
    properties: {'tutorial_id': event.tutorialId, 'source': sourceName},
  ),
);
```
Les événements externes délèguent l’ouverture au repository et émettent une
erreur non bloquante si elle échoue.

- [ ] **Step 4: Enregistrer et fournir globalement**

Dans GetIt :

```dart
getIt.registerLazySingleton<HelpCenterConfigSource>(
  () => FirebaseHelpCenterRemoteConfigDatasource(),
);
getIt.registerLazySingleton(
  () => HelpCenterRepository(getIt<HelpCenterConfigSource>()),
);
getIt.registerFactory(
  () => HelpCenterBloc(getIt<HelpCenterRepository>(), getIt<AnalyticsService>()),
);
```

Ajouter dans le `MultiBlocProvider` racine :

```dart
BlocProvider(
  create: (_) => getIt<HelpCenterBloc>()..add(const HelpCenterLoadRequested()),
),
```

- [ ] **Step 5: Déclarer les événements**

Ajouter les huit constantes décrites dans la spécification à
`AnalyticsEvents`.

- [ ] **Step 6: Vérifier et committer**

Run:

```bash
flutter test test/features/profile/bloc/help_center_bloc_test.dart
flutter analyze lib/features/profile/bloc lib/core/di/injection.dart lib/app/app.dart
```

Expected: PASS et aucune erreur.

```bash
git add lib/features/profile/bloc/help_center_* lib/core/di/injection.dart lib/app/app.dart lib/core/services/analytics_events.dart test/features/profile/bloc/help_center_bloc_test.dart
git commit -m "feat(help): exposer le catalogue global"
```

### Task 4: Hub FAQ, tutoriels et communauté

**Files:**
- Create: `lib/features/profile/presentation/widgets/help_tutorial_card.dart`
- Create: `lib/features/profile/presentation/widgets/social_community_section.dart`
- Modify: `lib/features/profile/presentation/screens/faq_screen.dart`
- Test: `test/features/profile/presentation/screens/faq_screen_test.dart`
- Test: `test/features/profile/presentation/widgets/social_community_section_test.dart`

**Interfaces:**
- Consumes: `HelpCenterSuccess.config`, `FaqBloc`, route tutoriel.
- Produces: hub ordonné et actions `HelpTutorialOpenRequested` / `HelpExternalOpenRequested`.

- [ ] **Step 1: Écrire les tests widgets en échec**

Vérifier :

- ordre FAQ → Tutoriels vidéo → Rejoindre la communauté ;
- sections masquées avec `HelpCenterConfig.empty` ;
- tri des tutoriels ;
- réseau inactif absent ;
- libellés Rejoindre/Suivre/S’abonner ;
- tap tutoriel vers `/profile/help/tutorial/search_intro` ;
- tap social déclenche le bon événement ;
- facteur de texte 2.0 sans overflow.

- [ ] **Step 2: Vérifier l’échec**

Run:

```bash
flutter test test/features/profile/presentation/screens/faq_screen_test.dart test/features/profile/presentation/widgets/social_community_section_test.dart
```

Expected: FAIL sur les nouvelles sections.

- [ ] **Step 3: Construire les cartes**

`HelpTutorialCard` utilise une miniature
`https://i.ytimg.com/vi/<videoId>/hqdefault.jpg`, ratio 16:9, overlay lecture,
durée facultative, semantics « Lire le tutoriel … » et animation d’entrée.

`SocialCommunitySection` mappe chaque réseau vers une icône du design system,
un libellé et une couleur accessible. Les actions ont une hauteur minimale de
56 et n’emploient aucune URL locale.

- [ ] **Step 4: Enrichir FaqScreen**

Conserver la recherche et les catégories actuelles. Sous la FAQ, rendre les
deux nouvelles sections à partir de `HelpCenterBloc`. Au tap tutoriel :

```dart
context.read<HelpCenterBloc>().add(
  HelpTutorialOpenRequested(tutorialId: tutorial.id, source: null),
);
context.push('/profile/help/tutorial/${tutorial.id}');
```

- [ ] **Step 5: Vérifier et committer**

Run:

```bash
flutter test test/features/profile/presentation/screens/faq_screen_test.dart test/features/profile/presentation/widgets/social_community_section_test.dart
```

Expected: PASS.

```bash
git add lib/features/profile/presentation/screens/faq_screen.dart lib/features/profile/presentation/widgets/help_tutorial_card.dart lib/features/profile/presentation/widgets/social_community_section.dart test/features/profile/presentation
git commit -m "feat(help): ajouter tutoriels et communauté"
```

### Task 5: Lecteur YouTube intégré et route

**Files:**
- Create: `lib/features/profile/presentation/screens/help_tutorial_screen.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/profile/presentation/screens/help_tutorial_screen_test.dart`
- Test: `test/app/router_help_tutorial_test.dart`

**Interfaces:**
- Consumes: `tutorialId`, catalogue global, `YoutubePlayerController`.
- Produces: route `/profile/help/tutorial/:tutorialId`, lecture intégrée et fallback externe.

- [ ] **Step 1: Écrire les tests en échec**

Injecter une fabrique de contrôleur ou un widget player substituable en test.
Vérifier titre, description, ratio 16:9, tutoriel inconnu, état erreur,
« Réessayer », « Ouvrir dans YouTube », « S’abonner à la chaîne » et analytics
started/completed émis une seule fois.

- [ ] **Step 2: Vérifier l’échec**

Run:

```bash
flutter test test/features/profile/presentation/screens/help_tutorial_screen_test.dart test/app/router_help_tutorial_test.dart
```

Expected: FAIL car écran et route absents.

- [ ] **Step 3: Implémenter le lecteur**

Créer le contrôleur sans autoplay :

```dart
YoutubePlayerController.fromVideoId(
  videoId: tutorial.youtubeVideoId,
  autoPlay: false,
  params: const YoutubePlayerParams(
    showControls: true,
    showFullscreenButton: true,
    enableCaption: true,
    strictRelatedVideos: true,
    privacyEnhanced: true,
  ),
);
```

Utiliser `YoutubePlayerScaffold`/`YoutubePlayer` selon l’API résolue par la
version lockée. Observer `PlayerState.playing` et `PlayerState.ended` sans
`setState`, puis envoyer les événements BLoC une seule fois. Fermer le
contrôleur dans `dispose`.

- [ ] **Step 4: Ajouter la route**

```dart
GoRoute(
  path: '/profile/help/tutorial/:tutorialId',
  builder: (context, state) => HelpTutorialScreen(
    tutorialId: state.pathParameters['tutorialId']!,
  ),
),
```

Le tutoriel est résolu depuis le BLoC global ; aucun objet mutable n’est passé
dans `extra`.

- [ ] **Step 5: Vérifier et committer**

Run:

```bash
flutter test test/features/profile/presentation/screens/help_tutorial_screen_test.dart test/app/router_help_tutorial_test.dart
flutter analyze lib/features/profile/presentation/screens/help_tutorial_screen.dart lib/app/router.dart
```

Expected: PASS et aucune erreur.

```bash
git add lib/features/profile/presentation/screens/help_tutorial_screen.dart lib/app/router.dart test/features/profile/presentation/screens/help_tutorial_screen_test.dart test/app/router_help_tutorial_test.dart
git commit -m "feat(help): intégrer le lecteur YouTube"
```

### Task 6: Carte d’aide contextuelle réutilisable

**Files:**
- Create: `lib/features/profile/presentation/widgets/contextual_tutorial_card.dart`
- Test: `test/features/profile/presentation/widgets/contextual_tutorial_card_test.dart`

**Interfaces:**
- Consumes: `TutorialContext`, catalogue global, GoRouter.
- Produces: `ContextualTutorialCard(context: TutorialContext)`.

- [ ] **Step 1: Écrire les tests en échec**

Tester : carte absente sans tutoriel actif, présente avec le bon titre, cible
tactile 44+, navigation vers le bon ID et événement avec la bonne source.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/presentation/widgets/contextual_tutorial_card_test.dart`

Expected: FAIL car le widget n’existe pas.

- [ ] **Step 3: Implémenter le composant**

```dart
class ContextualTutorialCard extends StatelessWidget {
  const ContextualTutorialCard({required this.context, super.key});
  final TutorialContext context;

  @override
  Widget build(BuildContext context) {
    final config = context.select<HelpCenterBloc, HelpCenterConfig>(
      (bloc) => switch (bloc.state) {
        HelpCenterSuccess(:final config) => config,
        HelpCenterError(:final config) => config,
        _ => HelpCenterConfig.empty,
      },
    );
    final tutorial = config.tutorialFor(this.context);
    if (tutorial == null) return const SizedBox.shrink();
    // Carte secondaire + événement + context.push.
  }
}
```

Utiliser `DonyIcon('circle-play')`, une surface secondaire et le texte
« Besoin d’aide ? Voir le tutoriel ».

- [ ] **Step 4: Vérifier et committer**

Run: `flutter test test/features/profile/presentation/widgets/contextual_tutorial_card_test.dart`

Expected: PASS.

```bash
git add lib/features/profile/presentation/widgets/contextual_tutorial_card.dart test/features/profile/presentation/widgets/contextual_tutorial_card_test.dart
git commit -m "feat(help): créer l'aide vidéo contextuelle"
```

### Task 7: Intégrer les neuf points d’aide

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/features/matching/presentation/screens/activites_hub_screen.dart`
- Modify: `lib/features/matching/presentation/screens/create_trip_screen.dart`
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart`
- Modify: `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart`
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart`
- Modify: `lib/features/tracking/presentation/screens/scan_hub_screen.dart`
- Modify: `lib/features/tracking/presentation/screens/tracking_timeline_screen.dart`
- Modify: `lib/features/disputes/presentation/dispute_list_screen.dart`
- Test: tests widgets existants correspondants et création du test timeline.

**Interfaces:**
- Consumes: `ContextualTutorialCard`.
- Produces: neuf accès contextuels non bloquants.

- [ ] **Step 1: Ajouter les assertions en échec aux tests existants**

Pour chaque écran, fournir un `HelpCenterBloc` avec le tutoriel du contexte,
vérifier la présence de la carte et le chemin après tap :

| Écran | Contexte | Tutoriel |
|---|---|---|
| `HomeScreen` | `search` | découverte/recherche |
| `ActivitesHubScreen` | `activities` | espace Activités |
| `CreateTripScreen` | `tripPublish` | publier un trajet |
| `PackageRequestCreateScreen` | `requestPublish` | publier une demande |
| `NegotiationThreadScreen` | `negotiation` | négocier |
| `PaymentScreen` | `payment` | accepter et payer |
| `ScanHubScreen` | `qrHandover` | remise/retrait QR |
| `TrackingTimelineScreen` | `tracking` | lecture et suivi |
| `DisputeListScreen` | `dispute` | ouvrir un litige |

- [ ] **Step 2: Vérifier les échecs**

Run:

```bash
flutter test test/features/home/presentation/home_screen_test.dart test/features/matching/presentation/screens/activites_hub_screen_test.dart test/features/matching/presentation/screens/create_trip_screen_test.dart test/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen_success_test.dart test/features/package_request/presentation/screens/shared/negotiation_thread_screen_test.dart test/features/payments/presentation/screens/payment_screen_test.dart test/features/tracking/presentation/scan_hub_screen_test.dart test/features/tracking/presentation/tracking_timeline_screen_test.dart test/features/disputes/presentation/dispute_list_screen_test.dart
```

Expected: FAIL car les cartes ne sont pas intégrées.

- [ ] **Step 3: Ajouter chaque carte à un emplacement pédagogique**

Placer la carte :

- après le contrôle principal de recherche sur Accueil ;
- après l’introduction d’Activités ;
- avant la première étape des deux formulaires ;
- au-dessus du fil/actions de négociation ;
- au-dessus du récapitulatif de paiement ;
- sous l’explication QR ;
- sous le résumé de statut du suivi ;
- au-dessus de la liste/état vide des litiges.

Ne modifier aucun BLoC métier et ne masquer aucun CTA existant.

- [ ] **Step 4: Vérifier et committer**

Relancer exactement la commande de Step 2.

Expected: PASS sans overflow.

```bash
git add lib/features/home/presentation/home_screen.dart lib/features/matching/presentation/screens/activites_hub_screen.dart lib/features/matching/presentation/screens/create_trip_screen.dart lib/features/package_request/presentation/screens lib/features/payments/presentation/screens/payment_screen.dart lib/features/tracking/presentation/screens lib/features/disputes/presentation/dispute_list_screen.dart test/features
git commit -m "feat(help): relier les tutoriels aux parcours"
```

### Task 8: Documentation Remote Config et vérification finale

**Files:**
- Create: `docs/help-center-remote-config.md`
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: schéma `help_center_config_v1` et événements implémentés.
- Produces: procédure de publication reproductible.

- [ ] **Step 1: Documenter un JSON complet**

Inclure les cinq réseaux avec `active: false`, les neuf tutoriels avec des IDs
stables et des identifiants vidéo d’exemple syntaxiquement valides mais
inactifs. Expliquer : validation locale, publication Firebase, test en dev,
activation progressive et retour arrière par restauration de la version
précédente.

- [ ] **Step 2: Mettre à jour analytics et démarrage**

Ajouter les huit événements à la table de `CLAUDE.md`. Ajouter dans `README.md`
la dépendance Firebase Remote Config et le nom exact du paramètre.

- [ ] **Step 3: Formater et vérifier les fichiers ciblés**

Run:

```bash
dart format lib/features/profile lib/core/di/injection.dart lib/core/services/analytics_events.dart lib/app/app.dart lib/app/router.dart lib/features/home/presentation/home_screen.dart lib/features/matching/presentation/screens/activites_hub_screen.dart lib/features/matching/presentation/screens/create_trip_screen.dart lib/features/package_request/presentation/screens lib/features/payments/presentation/screens/payment_screen.dart lib/features/tracking/presentation/screens lib/features/disputes/presentation/dispute_list_screen.dart test/features/profile
flutter test test/features/profile
flutter analyze lib/features/profile lib/app/router.dart lib/app/app.dart lib/core/di/injection.dart
```

Expected: format exit 0, tests PASS, analyse sans erreur.

- [ ] **Step 4: Exécuter la suite complète**

Run:

```bash
flutter test --coverage
flutter analyze
```

Expected: tous les tests passent, aucune erreur d’analyse et couverture globale
au moins égale à 90 %.

- [ ] **Step 5: Contrôle manuel**

Sur Android puis iOS :

- publier une configuration Remote Config de test ;
- ouvrir chaque réseau ;
- lire, mettre en pause, terminer et passer en plein écran ;
- couper le réseau avant chargement puis réessayer ;
- vérifier l’ouverture externe et l’abonnement ;
- tester taille de texte maximale et thème sombre ;
- confirmer que la FAQ reste disponible avec un JSON invalide.

- [ ] **Step 6: Commit final**

```bash
git add docs/help-center-remote-config.md CLAUDE.md README.md
git commit -m "docs: expliquer la configuration du centre d'aide"
```
