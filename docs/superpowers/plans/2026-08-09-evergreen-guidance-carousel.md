# Carousel de guidance evergreen — écran Recherche — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les deux blocs statiques `RoleGuidanceBanner` (CTA mort) + `ContextualTutorialCard` de l'écran Recherche par un unique carousel evergreen auto-rotatif (`EvergreenGuidanceCarousel`), à 5 slides masquées dynamiquement selon l'état utilisateur, pour rendre visibles la publication de trajet, l'envoi de colis, les alertes corridor, la vérification KYC et le fonctionnement du toggle Trajets/Colis.

**Architecture:** Nouveau widget `StatefulWidget` autonome dans `lib/features/home/presentation/widgets/`, purement présentation (reçoit `HiveService` + `bool isKycVerified`), qui lit lui-même l'état des 3 flags Hive via `ValueListenableBuilder` (même pattern que `RoleGuidanceBanner`) et l'état du tutoriel via `HelpCenterBloc` (même pattern que `ContextualTutorialCard`). `home_screen.dart` l'instancie à la place des deux anciens blocs, sans autre logique. Une nouvelle clé Hive (`kHasActiveCorridorAlert`) est posée côté `CorridorAlertFormCubit` à la création réussie d'une alerte.

**Tech Stack:** Flutter/Dart, flutter_bloc, GoRouter, Hive, flutter_animate non requis (animation manuelle via `PageController` + `Timer`).

## Global Constraints

- BLoC pour tout état de feature, jamais `setState` en dehors du widget lui-même pour piloter son propre carousel — GoRouter (`context.push`), jamais `Navigator.push`.
- Couleurs : `Theme.of(context).colorScheme` (`cs.primary`, `cs.success`, `cs.warning`, `cs.info`, `cs.secondary` via l'extension `DonyStatusColors`) — jamais `DonyColors.surface/textPrimary/bgApp/borderDefault` en dur (dark mode).
- Espacements/rayons : `DonySpacing.*` / `DonyRadius.*`, jamais de valeurs en dur.
- Touch targets ≥ 44×44 pt pour tout élément interactif (CTA des slides).
- Tracking analytics obligatoire sur toute nouvelle action métier : nom d'event déclaré dans `AnalyticsEvents`, jamais de string inline ; table des events dans `dony_app/CLAUDE.md` mise à jour.
- Couverture de tests ≥ 90 % (`flutter test --coverage`), tous les tests doivent passer avant tout commit.
- Ne jamais commit directement sur `main` — déjà sur `feature/recherche-guidance-carousel`.
- Ne jamais inclure `Co-Authored-By: Claude` dans les messages de commit.
- Respect de la réduction de mouvement : l'auto-rotation du carousel doit être désactivée si `MediaQuery.of(context).disableAnimations` est vrai (préférence système "Réduire les animations").

---

### Task 1: Flag Hive `kHasActiveCorridorAlert` posé à la création d'une alerte

**Files:**
- Modify: `lib/core/storage/hive_service.dart:9-10`
- Modify: `lib/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart` (import, constructeur, `submit()`)
- Modify: `lib/core/di/injection.dart:772-780`
- Test: `test/features/corridor_alerts/bloc/corridor_alert_form_cubit_test.dart`

**Interfaces:**
- Consomme : `HiveService.userPrefs` (`Box`, méthode `put(key, value)`) — déjà existant, pattern identique à `kHasPublishedAsTraveler`.
- Produit : `HiveService.kHasActiveCorridorAlert` (String, clé Hive `'has_active_corridor_alert'`) — consommée par `EvergreenGuidanceCarousel` en Task 2. `CorridorAlertFormCubit` gagne un paramètre nommé optionnel `HiveService? hiveService`.

Le flag n'est **jamais réinitialisé** (même précédent que `kHasPublishedAsTraveler`/`kHasPublishedAsSender`, qui ne se remettent pas à `false` si le trajet est annulé) : une fois qu'un utilisateur a créé une alerte, la slide correspondante du carousel disparaît définitivement. `hiveService` est optionnel (et non un paramètre requis) pour ne casser aucun des 21 sites d'instanciation existants de `CorridorAlertFormCubit` dans les tests — si absent, l'écriture Hive est simplement sautée (`_hiveService?.userPrefs.put(...)`), sans exception.

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter en haut du fichier de test, avec les autres imports :

```dart
import 'package:dony/core/storage/hive_service.dart';
import 'package:hive/hive.dart';
```

Ajouter avec les autres classes mock (après `class MockAnalytics extends Mock implements AnalyticsService {}`) :

```dart
class MockHiveService extends Mock implements HiveService {}
class MockBox extends Mock implements Box {}
```

Ajouter un nouveau groupe de tests, juste avant le dernier `}` de `void main()` :

```dart
  group('kHasActiveCorridorAlert', () {
    test('submit (create) réussi pose le flag si hiveService fourni', () async {
      final hive = MockHiveService();
      final box = MockBox();
      when(() => hive.userPrefs).thenReturn(box);
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      when(() => repo.create(any())).thenAnswer((_) async => _created());

      final c = CorridorAlertFormCubit(repo, analytics, hiveService: hive);
      c.setDeparture('Paris', 'FR');
      c.setArrival('Bamako', 'ML');
      await c.submit();

      verify(() => box.put(HiveService.kHasActiveCorridorAlert, true)).called(1);
    });

    test('submit (create) réussi sans hiveService ne lève pas d\'exception', () async {
      when(() => repo.create(any())).thenAnswer((_) async => _created());

      final c = CorridorAlertFormCubit(repo, analytics);
      c.setDeparture('Paris', 'FR');
      c.setArrival('Bamako', 'ML');
      await c.submit();

      expect(c.state.status, CorridorAlertFormStatus.success);
    });

    test('submit (edit) réussi pose aussi le flag', () async {
      final hive = MockHiveService();
      final box = MockBox();
      when(() => hive.userPrefs).thenReturn(box);
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      when(() => repo.update('a1', any())).thenAnswer((_) async => _created());

      final c = CorridorAlertFormCubit(
        repo,
        analytics,
        hiveService: hive,
        editing: _created(),
      );
      await c.submit();

      verify(() => box.put(HiveService.kHasActiveCorridorAlert, true)).called(1);
    });

    test('submit en erreur ne pose pas le flag', () async {
      final hive = MockHiveService();
      final box = MockBox();
      when(() => hive.userPrefs).thenReturn(box);
      when(() => repo.create(any())).thenThrow(Exception('422'));

      final c = CorridorAlertFormCubit(repo, analytics, hiveService: hive);
      c.setDeparture('Paris', 'FR');
      c.setArrival('Bamako', 'ML');
      await c.submit();

      verifyNever(() => box.put(HiveService.kHasActiveCorridorAlert, true));
    });
  });
```

- [ ] **Step 2: Lancer les tests et vérifier l'échec**

Run: `flutter test test/features/corridor_alerts/bloc/corridor_alert_form_cubit_test.dart`
Expected: FAIL — `CorridorAlertFormCubit` n'a pas de paramètre nommé `hiveService`, `HiveService.kHasActiveCorridorAlert` n'existe pas (erreur de compilation).

- [ ] **Step 3: Ajouter la clé Hive**

Dans `lib/core/storage/hive_service.dart`, juste après la ligne 10 (`static const String kHasPublishedAsSender = 'has_published_as_sender';`) :

```dart
  static const String kHasPublishedAsTraveler = 'has_published_as_traveler';
  static const String kHasPublishedAsSender = 'has_published_as_sender';

  // Alerte corridor active : posé à la première création/édition réussie,
  // jamais réinitialisé (même précédent que kHasPublishedAsTraveler/Sender).
  // Sert uniquement à masquer la slide "Créer une alerte" du carousel
  // evergreen de l'écran Recherche une fois l'action faite.
  static const String kHasActiveCorridorAlert = 'has_active_corridor_alert';
```

- [ ] **Step 4: Modifier `CorridorAlertFormCubit`**

Dans `lib/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart`, ajouter l'import en haut du fichier (avec les autres imports relatifs) :

```dart
import '../../../core/storage/hive_service.dart';
```

Remplacer le constructeur (lignes 137-160) :

```dart
class CorridorAlertFormCubit extends Cubit<CorridorAlertFormState> {
  CorridorAlertFormCubit(this._repository, this._analytics,
      {CorridorAlertModel? editing,
      AlertDirection initialDirection = AlertDirection.travelerWantsPackages,
      HiveService? hiveService})
      : _editingId = editing?.id,
        _hiveService = hiveService,
        super(
          editing == null
              ? CorridorAlertFormState(direction: initialDirection)
              : CorridorAlertFormState(
                  departureCity: editing.departureCity,
                  arrivalCity: editing.arrivalCity,
                  departureCountryCode: editing.departureCountryCode,
                  arrivalCountryCode: editing.arrivalCountryCode,
                  dateFrom: editing.dateFrom,
                  dateTo: editing.dateTo,
                  minWeightKg: editing.minWeightKg,
                  contentCategories: editing.contentCategories,
                  direction: editing.direction,
                  centerLat: editing.centerLat,
                  centerLng: editing.centerLng,
                  radiusKm: editing.radiusKm,
                  centerLabel: editing.centerLabel,
                ),
        );

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;
  final HiveService? _hiveService;
  final String? _editingId;
```

Puis dans `submit()`, insérer l'écriture du flag juste avant `emit(state.copyWith(status: CorridorAlertFormStatus.success));` :

```dart
    try {
      if (_editingId != null) {
        await _repository.update(_editingId, draft);
        unawaited(
            _analytics.logEvent(AnalyticsEvents.corridorAlertUpdated));
      } else {
        await _repository.create(draft);
        unawaited(
            _analytics.logEvent(AnalyticsEvents.corridorAlertCreated));
      }
      final hive = _hiveService;
      if (hive != null) {
        unawaited(hive.userPrefs.put(HiveService.kHasActiveCorridorAlert, true));
      }
      emit(state.copyWith(status: CorridorAlertFormStatus.success));
    } catch (err) {
```

Dans `lib/core/di/injection.dart`, modifier l'enregistrement (lignes 772-780) :

```dart
  getIt.registerFactoryParam<CorridorAlertFormCubit,
      ({CorridorAlertModel? editing, AlertDirection direction}), void>(
    (params, _) => CorridorAlertFormCubit(
      getIt<CorridorAlertRepository>(),
      getIt<AnalyticsService>(),
      editing: params.editing,
      initialDirection: params.direction,
      hiveService: getIt<HiveService>(),
    ),
  );
```

- [ ] **Step 5: Lancer les tests et vérifier le succès**

Run: `flutter test test/features/corridor_alerts/bloc/corridor_alert_form_cubit_test.dart`
Expected: PASS — les 4 nouveaux tests passent, et les ~34 tests existants du fichier passent toujours inchangés (aucun ne fournit `hiveService`, donc `_hiveService` reste `null` et le `?.` les protège).

- [ ] **Step 6: Commit**

```bash
git add lib/core/storage/hive_service.dart lib/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart lib/core/di/injection.dart test/features/corridor_alerts/bloc/corridor_alert_form_cubit_test.dart
git commit -m "feat: pose kHasActiveCorridorAlert à la création/édition réussie d'une alerte"
```

---

### Task 2: Widget `EvergreenGuidanceCarousel`

**Files:**
- Create: `lib/features/home/presentation/widgets/evergreen_guidance_carousel.dart`
- Modify: `lib/core/services/analytics_events.dart:159-167`
- Modify: `dony_app/CLAUDE.md` (table "Events actuellement implémentés")
- Test: `test/features/home/presentation/widgets/evergreen_guidance_carousel_test.dart`

**Interfaces:**
- Consomme : `HiveService.userPrefs`/`listenUserPrefs` (Task 1 + existant), `HiveService.kHasPublishedAsTraveler`/`kHasPublishedAsSender`/`kHasActiveCorridorAlert`/`kContextualTutorialDismissedPrefix`, `HelpCenterBloc` (état global, `HelpCenterConfig.tutorialFor(TutorialContext.search)` → `HelpTutorial?`), `AnalyticsService.logEvent` via `getIt`.
- Produit : `EvergreenGuidanceCarousel({required HiveService hiveService, required bool isKycVerified})` — widget public consommé par `home_screen.dart` en Task 3. `AnalyticsEvents.homeGuidanceCarouselCtaTapped` (String constante).

- [ ] **Step 1: Ajouter l'event analytics**

Dans `lib/core/services/analytics_events.dart`, insérer juste après le bloc `homeMatchingTripsFilterToggled` (ligne 167) :

```dart
  /// Tap CTA d'une slide du carousel evergreen (écran Recherche).
  /// Propriété `slide` : trip / parcel / alert / kyc / tutorial.
  static const homeGuidanceCarouselCtaTapped =
      'home_guidance_carousel_cta_tapped';
```

- [ ] **Step 2: Écrire les tests qui échouent**

Créer `test/features/home/presentation/widgets/evergreen_guidance_carousel_test.dart` :

```dart
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/home/presentation/widgets/evergreen_guidance_carousel.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{"schemaVersion": 1, "socialLinks": [], "tutorials": []}
''';

const _searchHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "search_intro",
      "title": "Découvrir la recherche",
      "description": "Trouver un voyageur ou un colis compatible.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"]
    }
  ]
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);
  final String json;
  @override
  Future<String?> fetchAndActivate() async => json;
}

BlocProvider<HelpCenterBloc> _helpCenterProvider({
  String helpConfigJson = _emptyHelpConfigJson,
}) => BlocProvider<HelpCenterBloc>(
  create: (_) => HelpCenterBloc(
    HelpCenterRepository(
      _StaticHelpCenterSource(helpConfigJson),
      fallbackJsonLoader: () async => _emptyHelpConfigJson,
    ),
    makeDisabledAnalytics(MockAnalyticsBackend()),
  )..add(const HelpCenterLoadRequested()),
);

class MockAnalyticsService extends Mock implements AnalyticsService {}

Widget _wrap({
  required MockHiveService hive,
  bool isKycVerified = true,
  bool hasPublishedTrip = true,
  bool hasPublishedParcel = true,
  bool hasActiveCorridorAlert = true,
  bool tutorialDismissed = true,
  String helpConfigJson = _emptyHelpConfigJson,
}) {
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(() => box.get(HiveService.kHasPublishedAsTraveler, defaultValue: false))
      .thenReturn(hasPublishedTrip);
  when(() => box.get(HiveService.kHasPublishedAsSender, defaultValue: false))
      .thenReturn(hasPublishedParcel);
  when(() => box.get(HiveService.kHasActiveCorridorAlert, defaultValue: false))
      .thenReturn(hasActiveCorridorAlert);
  // Id fixe du seul tutoriel du fixture _searchHelpConfigJson ("search_intro") :
  // clé littérale, pas de matcher générique (évite le mélange matcher/valeur
  // brute que mocktail refuse sur un même appel).
  when(() => box.get(
        '${HiveService.kContextualTutorialDismissedPrefix}search_intro',
        defaultValue: false,
      )).thenReturn(tutorialDismissed);
  when(() => hive.listenUserPrefs(keys: any(named: 'keys')))
      .thenReturn(ValueNotifier<Box>(box));

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: EvergreenGuidanceCarousel(
            hiveService: hive,
            isKycVerified: isKycVerified,
          ),
        ),
      ),
      GoRoute(
        path: '/trips/publish-intro',
        builder: (_, __) => const Scaffold(body: Text('publish-intro-trip')),
      ),
      GoRoute(
        path: '/parcels/send-intro',
        builder: (_, __) => const Scaffold(body: Text('send-intro-parcel')),
      ),
      GoRoute(
        path: '/corridor-alerts',
        builder: (_, __) => const Scaffold(body: Text('corridor-alerts')),
      ),
      GoRoute(
        path: '/kyc/verify',
        builder: (_, __) => const Scaffold(body: Text('kyc-verify')),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [_helpCenterProvider(helpConfigJson: helpConfigJson)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    getIt.registerSingleton<AnalyticsService>(MockAnalyticsService());
    when(() => getIt<AnalyticsService>().logEvent(any(),
            properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  tearDownAll(() => getIt.reset());

  late MockHiveService hive;
  setUp(() => hive = MockHiveService());

  testWidgets('disparaît quand toutes les actions sont déjà faites', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evergreen-guidance-carousel')), findsNothing);
  });

  testWidgets('affiche la slide trajet si pas encore publié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
    expect(find.text('Publier mon trajet'), findsOneWidget);
  });

  testWidgets('masque la slide trajet si déjà publié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-trip')), findsNothing);
  });

  testWidgets('affiche la slide colis si pas encore envoyé', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedParcel: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-parcel')), findsOneWidget);
  });

  testWidgets('affiche la slide alerte si aucune alerte active', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasActiveCorridorAlert: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-alert')), findsOneWidget);
  });

  testWidgets('affiche la slide KYC si pas vérifié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, isKycVerified: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-kyc')), findsOneWidget);
  });

  testWidgets('masque la slide KYC si déjà vérifié', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, isKycVerified: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-kyc')), findsNothing);
  });

  testWidgets('affiche la slide tuto si un tutoriel search existe et non fermé',
      (tester) async {
    await tester.pumpWidget(_wrap(
      hive: hive,
      helpConfigJson: _searchHelpConfigJson,
      tutorialDismissed: false,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-tutorial')), findsOneWidget);
  });

  testWidgets('masque la slide tuto si déjà fermée via la croix historique',
      (tester) async {
    await tester.pumpWidget(_wrap(
      hive: hive,
      helpConfigJson: _searchHelpConfigJson,
      tutorialDismissed: true,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-slide-tutorial')), findsNothing);
  });

  testWidgets('tap CTA trajet pousse /trips/publish-intro et logue l\'event',
      (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guidance-slide-trip-cta')));
    await tester.pumpAndSettle();
    expect(find.text('publish-intro-trip'), findsOneWidget);
    verify(() => getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.homeGuidanceCarouselCtaTapped,
          properties: {'slide': 'trip'},
        )).called(1);
  });

  testWidgets('une seule slide visible : pas de dots affichés', (tester) async {
    await tester.pumpWidget(_wrap(hive: hive, hasPublishedTrip: false));
    await tester.pumpAndSettle();
    // trip est la seule slide visible (tout le reste "déjà fait" par défaut) :
    // la Row de dots n'est construite que si slides.length > 1.
    expect(find.byKey(const Key('guidance-slide-trip')), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
```

- [ ] **Step 3: Lancer les tests et vérifier l'échec**

Run: `flutter test test/features/home/presentation/widgets/evergreen_guidance_carousel_test.dart`
Expected: FAIL — le fichier `evergreen_guidance_carousel.dart` n'existe pas encore.

- [ ] **Step 4: Implémenter `EvergreenGuidanceCarousel`**

Créer `lib/features/home/presentation/widgets/evergreen_guidance_carousel.dart` :

```dart
import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

/// Carousel evergreen affiché juste avant la liste de résultats de l'écran
/// Recherche. Remplace `RoleGuidanceBanner` (CTA mort, dismiss définitif) et
/// `ContextualTutorialCard` (carte séparée) par des cartes pleine couleur en
/// rotation automatique, chacune masquée dès que l'action qu'elle propose
/// est faite. Aucune croix de fermeture manuelle : la disparition est
/// entièrement pilotée par l'état applicatif.
class EvergreenGuidanceCarousel extends StatefulWidget {
  const EvergreenGuidanceCarousel({
    super.key,
    required this.hiveService,
    required this.isKycVerified,
  });

  final HiveService hiveService;
  final bool isKycVerified;

  static const Duration autoplayInterval = Duration(seconds: 4);

  @override
  State<EvergreenGuidanceCarousel> createState() =>
      _EvergreenGuidanceCarouselState();
}

class _EvergreenGuidanceCarouselState
    extends State<EvergreenGuidanceCarousel> {
  final PageController _pageController = PageController();
  Timer? _autoplayTimer;
  int _currentIndex = 0;
  int? _lastSlideCount;

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartAutoplay(int slideCount) {
    _autoplayTimer?.cancel();
    if (slideCount <= 1) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _autoplayTimer = Timer.periodic(
      EvergreenGuidanceCarousel.autoplayInterval,
      (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_currentIndex + 1) % slideCount;
        _pageController.animateToPage(
          next,
          duration: DonyDuration.page,
          curve: DonyCurve.enter,
        );
      },
    );
  }

  void _onPageChanged(int index, int slideCount) {
    setState(() => _currentIndex = index);
    _restartAutoplay(slideCount);
  }

  void _onSlideTap(
    BuildContext context, {
    required String slideId,
    required String route,
  }) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': slideId},
      ),
    );
    context.push(route);
  }

  void _onTutorialTap(BuildContext context, HelpTutorial tutorial) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': 'tutorial'},
      ),
    );
    context.read<HelpCenterBloc>().add(
          HelpTutorialOpenRequested(
            tutorialId: tutorial.id,
            source: TutorialContext.search,
          ),
        );
    context.push('/profile/help/tutorial/${tutorial.id}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tutorialConfig = context.select<HelpCenterBloc, HelpCenterConfig>(
      (bloc) => switch (bloc.state) {
        HelpCenterSuccess(:final config) => config,
        HelpCenterError(:final config) => config,
        _ => HelpCenterConfig.empty,
      },
    );
    final tutorial = tutorialConfig.tutorialFor(TutorialContext.search);

    return ValueListenableBuilder<Box>(
      valueListenable: widget.hiveService.listenUserPrefs(keys: [
        HiveService.kHasPublishedAsTraveler,
        HiveService.kHasPublishedAsSender,
        HiveService.kHasActiveCorridorAlert,
        if (tutorial != null)
          '${HiveService.kContextualTutorialDismissedPrefix}${tutorial.id}',
      ]),
      builder: (context, box, _) {
        final hasPublishedTrip = box.get(
          HiveService.kHasPublishedAsTraveler,
          defaultValue: false,
        ) as bool;
        final hasPublishedParcel = box.get(
          HiveService.kHasPublishedAsSender,
          defaultValue: false,
        ) as bool;
        final hasActiveCorridorAlert = box.get(
          HiveService.kHasActiveCorridorAlert,
          defaultValue: false,
        ) as bool;
        final tutorialDismissed = tutorial != null &&
            (box.get(
              '${HiveService.kContextualTutorialDismissedPrefix}${tutorial.id}',
              defaultValue: false,
            ) as bool);

        final slides = <_GuidanceSlideData>[
          if (!hasPublishedTrip)
            _GuidanceSlideData(
              id: 'trip',
              icon: 'plane',
              title: 'Publier mon trajet',
              subtitle:
                  'Rentabilise tes voyages en transportant des colis pour d’autres.',
              ctaLabel: 'Commencer',
              color: cs.primary,
              onTap: () => _onSlideTap(
                context,
                slideId: 'trip',
                route: '/trips/publish-intro',
              ),
            ),
          if (!hasPublishedParcel)
            _GuidanceSlideData(
              id: 'parcel',
              icon: 'send',
              title: 'Envoyer un colis',
              subtitle:
                  'Trouve un voyageur qui emporte ton colis à destination.',
              ctaLabel: 'Rechercher',
              color: cs.success,
              onTap: () => _onSlideTap(
                context,
                slideId: 'parcel',
                route: '/parcels/send-intro',
              ),
            ),
          if (!hasActiveCorridorAlert)
            _GuidanceSlideData(
              id: 'alert',
              icon: 'bell',
              title: 'Créer une alerte',
              subtitle:
                  'Sois notifié dès qu’une annonce correspond à tes critères.',
              ctaLabel: 'Créer',
              color: cs.warning,
              onTap: () => _onSlideTap(
                context,
                slideId: 'alert',
                route: '/corridor-alerts',
              ),
            ),
          if (!widget.isKycVerified)
            _GuidanceSlideData(
              id: 'kyc',
              icon: 'shield-check',
              title: 'Vérifier mon identité',
              subtitle:
                  'Valide ton profil pour publier un trajet et réserver en toute confiance.',
              ctaLabel: 'Vérifier',
              color: cs.info,
              onTap: () => _onSlideTap(
                context,
                slideId: 'kyc',
                route: '/kyc/verify',
              ),
            ),
          if (tutorial != null && !tutorialDismissed)
            _GuidanceSlideData(
              id: 'tutorial',
              icon: 'circle-play',
              title: 'Comment ça marche ?',
              subtitle: tutorial.title,
              ctaLabel: 'Voir le tuto',
              color: cs.secondary,
              onTap: () => _onTutorialTap(context, tutorial),
            ),
        ];

        if (slides.isEmpty) return const SizedBox.shrink();

        if (_lastSlideCount != slides.length) {
          _lastSlideCount = slides.length;
          if (_currentIndex >= slides.length) _currentIndex = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restartAutoplay(slides.length);
          });
        }
        final safeIndex = _currentIndex.clamp(0, slides.length - 1).toInt();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: DonySpacing.md,
          ),
          child: Column(
            children: [
              if (slides.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slides.length, (i) {
                      final active = i == safeIndex;
                      return AnimatedContainer(
                        duration: DonyDuration.base,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? cs.onSurface : cs.outline,
                          borderRadius: BorderRadius.circular(DonyRadius.full),
                        ),
                      );
                    }),
                  ),
                ),
              SizedBox(
                height: 172,
                child: PageView.builder(
                  key: const Key('evergreen-guidance-carousel'),
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) => _onPageChanged(i, slides.length),
                  itemBuilder: (context, i) => _SlideCard(data: slides[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GuidanceSlideData {
  const _GuidanceSlideData({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.color,
    required this.onTap,
  });

  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final Color color;
  final VoidCallback onTap;
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.data});

  final _GuidanceSlideData data;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      key: Key('guidance-slide-${data.id}'),
      margin: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Center(
              child: DonyIcon(data.icon, size: 26, color: Colors.white),
            ),
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                GestureDetector(
                  key: Key('guidance-slide-${data.id}-cta'),
                  onTap: data.onTap,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md,
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      '${data.ctaLabel} →',
                      style: tt.labelMedium?.copyWith(
                        color: data.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Lancer les tests et vérifier le succès**

Run: `flutter test test/features/home/presentation/widgets/evergreen_guidance_carousel_test.dart`
Expected: PASS — les 11 tests passent.

- [ ] **Step 6: Documenter l'event dans `dony_app/CLAUDE.md`**

Dans la table "Events actuellement implémentés", ajouter une ligne juste après celle de `home_matching_trips_filter_toggled` :

```markdown
| `home_guidance_carousel_cta_tapped` | HomeScreen — tap CTA d'une slide du carousel evergreen de l'écran Recherche (propriété `slide` : trip/parcel/alert/kyc/tutorial) |
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/presentation/widgets/evergreen_guidance_carousel.dart lib/core/services/analytics_events.dart dony_app/CLAUDE.md test/features/home/presentation/widgets/evergreen_guidance_carousel_test.dart
git commit -m "feat: carousel de guidance evergreen (EvergreenGuidanceCarousel)"
```

---

### Task 3: Brancher le carousel dans `home_screen.dart`

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart:10-11,47,1611-1635`
- Test: `test/features/home/presentation/home_screen_test.dart` (suite complète, run seulement — pas de nouveau test dédié, cet écran est déjà massivement couvert)

**Interfaces:**
- Consomme : `EvergreenGuidanceCarousel` (Task 2), `getIt<HiveService>()` (déjà importé), `context.watch<AuthBloc>().state.currentUser?.isKycVerified` (extension `AuthStateUser` existante sur `AuthState`, `UserModel.isKycVerified` existant).
- Ne produit rien de nouveau pour d'autres tâches — tâche terminale de câblage.

- [ ] **Step 1: Retirer les imports devenus inutiles et ajouter le nouveau**

Dans `lib/features/home/presentation/home_screen.dart`, ligne 10 (`import 'package:dony/core/widgets/role_guidance_banner.dart';`) et ligne 11 (`import 'package:dony/features/auth/bloc/active_role_cubit.dart';`) : les remplacer par :

```dart
import 'package:dony/features/home/presentation/widgets/evergreen_guidance_carousel.dart';
```

`ActiveRole` n'est utilisé nulle part ailleurs dans ce fichier (vérifié — seuls les 2 usages retirés à l'étape suivante y font référence), son import est donc supprimé sans remplacement. À la ligne 47 (`import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';`), supprimer la ligne : `ContextualTutorialCard` n'est plus utilisé dans ce fichier (il reste utilisé ailleurs dans l'app, son propre fichier n'est pas touché).

- [ ] **Step 2: Remplacer les deux blocs par le carousel**

Remplacer (lignes 1611-1635) :

```dart
                SliverToBoxAdapter(
                  child: RoleGuidanceBanner(
                    // Le CTA suit le mode affiché (cohérence titre ↔ bouton) :
                    // mode Trajets → « Publier mon trajet » ; mode Colis
                    // (demandes d'envoi) et expéditeur → « Publier ma demande ».
                    role: (_isTraveler && _mode.isTrips)
                        ? ActiveRole.traveler
                        : ActiveRole.sender,
                    hiveService: getIt<HiveService>(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      DonySpacing.sm,
                      DonySpacing.lg,
                      0,
                    ),
                    child: const ContextualTutorialCard(
                      context: TutorialContext.search,
                    ),
                  ),
                ),
```

par :

```dart
                SliverToBoxAdapter(
                  child: EvergreenGuidanceCarousel(
                    hiveService: getIt<HiveService>(),
                    isKycVerified: context
                            .watch<AuthBloc>()
                            .state
                            .currentUser
                            ?.isKycVerified ??
                        false,
                  ),
                ),
```

- [ ] **Step 3: Lancer la suite de tests complète de l'écran**

Run: `flutter test test/features/home/presentation/home_screen_test.dart`
Expected: la majorité passe sans changement. **Point d'attention explicite** : avant cette tâche, dans la plupart des scénarios de test, `RoleGuidanceBanner` était masqué (`hasPublished = true` via `_FakeBox`) mais `ContextualTutorialCard` pouvait s'afficher ou non selon la fixture `HelpCenterBloc` du test — après cette tâche, la même sheet affiche en plus la slide "Créer une alerte" (jamais testée avant, car `kHasActiveCorridorAlert` n'existait pas et `_FakeBox.get` par défaut renvoie `defaultValue` → `false` → slide visible) et potentiellement la slide KYC selon `kycStatus` de `_makeUser()`. Si un test échoue sur un `find.text()`/`find.byKey()` désormais ambigu à cause de la nouvelle carte visible, corriger ce test précis (pas de suppression de test — ajuster son scénario ou restreindre son `find` à la zone concernée), jamais désactiver la vérification.

- [ ] **Step 4: Corriger les éventuelles régressions identifiées à l'étape 3**

Pas de code générique ici : lire les échecs réels rapportés par `flutter test`, et pour chacun, ajuster soit le scénario du test (ex: stubber `MockHiveService`/`_FakeBox` pour `kHasActiveCorridorAlert: true` si le test ne porte pas sur le carousel), soit affiner le `find` utilisé (`findsWidgets` → `find.descendant` ciblé) si le nouveau texte entre en collision avec un texte préexistant ailleurs sur l'écran.

- [ ] **Step 5: Relancer la suite jusqu'au vert complet**

Run: `flutter test test/features/home/presentation/home_screen_test.dart`
Expected: PASS intégral.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/home_screen.dart test/features/home/presentation/home_screen_test.dart
git commit -m "feat: brancher EvergreenGuidanceCarousel sur l'écran Recherche"
```

---

### Task 4: Supprimer `RoleGuidanceBanner` (mort après Task 3)

**Files:**
- Delete: `lib/core/widgets/role_guidance_banner.dart`
- Delete: `test/core/widgets/role_guidance_banner_test.dart`

**Interfaces:**
- Ne consomme ni ne produit rien pour les autres tâches — nettoyage terminal. `ContextualTutorialCard` n'est PAS supprimé : il reste utilisé dans 13 autres écrans (`activites_hub_screen.dart`, `create_trip_screen.dart`, `payment_screen.dart`, `dispute_list_screen.dart`, etc. — seul son usage dans `home_screen.dart` a été retiré en Task 3).

- [ ] **Step 1: Vérifier qu'il n'y a plus aucun usage**

Run: `grep -rn "RoleGuidanceBanner" lib/ test/ --include="*.dart"`
Expected: uniquement les deux fichiers à supprimer eux-mêmes (leur propre déclaration/test), aucune autre référence.

- [ ] **Step 2: Supprimer les fichiers**

```bash
git rm lib/core/widgets/role_guidance_banner.dart test/core/widgets/role_guidance_banner_test.dart
```

- [ ] **Step 3: Vérifier qu'aucun import mort ne subsiste**

Run: `flutter analyze`
Expected: aucune erreur `unused_import` ni `uri_does_not_exist` liée à `role_guidance_banner.dart`.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: supprime RoleGuidanceBanner, remplacé par EvergreenGuidanceCarousel"
```

---

### Task 5: Vérification finale (analyse, couverture, format)

**Files:** aucun fichier de code — vérification uniquement, tout le repo `dony_app/`.

- [ ] **Step 1: Analyse statique**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Formatage**

Run: `dart format lib/ test/`
Expected: aucun fichier reformaté en dehors de ceux touchés par ce plan (sinon, `git diff --stat` pour vérifier qu'aucun fichier hors scope n'a été reformaté par erreur).

- [ ] **Step 3: Suite de tests complète avec couverture**

Run: `flutter test --coverage`
Expected: tous les tests passent (0 failure), y compris les ~2000+ tests préexistants non liés à cette feature.

- [ ] **Step 4: Vérifier la couverture des fichiers touchés**

Run: `genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html`
Expected: couverture globale du projet ≥ 90 % (règle `CLAUDE.md`) ; en particulier `evergreen_guidance_carousel.dart` et les portions modifiées de `corridor_alert_form_cubit.dart` et `home_screen.dart` doivent apparaître couvertes par les tests des Tasks 1-3. Si un chemin (ex: `_restartAutoplay` avec `disableAnimations: true`) n'est pas couvert, ajouter un test ciblé avant de continuer.

- [ ] **Step 5: Commit final si des ajustements de couverture ont été faits**

```bash
git add -A
git commit -m "test: complète la couverture du carousel de guidance evergreen"
```

(Ne committer que s'il y a effectivement eu des changements à l'étape 4 — sinon cette étape est un no-op.)

---

## Hors scope (rappel du spec)

- Pas de retouche au `SearchModeSelector` (toggle ✈️/📦) — le tuto explique son fonctionnement, on ne redessine pas le composant.
- Pas de changement du contenu des tutoriels distants (`HelpCenterConfig`) — seulement le point d'affichage de celui de `TutorialContext.search`.
- Pas de personnalisation par rôle actif ou par mode Trajets/Colis — mêmes slides dans les deux modes.

---

## Addendum — Task 6 (post-device feedback)

Après test sur device réel, le design "grande carte pleine couleur + CTA" a été
remplacé par des cartes compactes (taille `ContextualTutorialCard`), toute la
carte cliquable, plus de bouton CTA séparé. Voir
`lib/features/home/presentation/widgets/evergreen_guidance_carousel.dart` pour
l'implémentation actuelle — ce document décrit l'état pré-Task-6, gardé pour
l'historique de conception.
