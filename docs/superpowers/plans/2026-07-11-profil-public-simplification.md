# Profil public — hero plat, bouton compact, signalement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplifier `ProfilePublicScreen` (hero plat sans bandeau bleu, bouton d'abonnement compact non pleine-largeur avec cloche de notification, stats à 2 colonnes) et ajouter un point d'entrée de signalement de l'utilisateur consulté, en réutilisant au maximum l'infra existante (`IncidentReportScreen`, `_SubscribedRow` pattern).

**Architecture:** Modifications localisées à `lib/features/profile/presentation/screens/profile_public_screen.dart` (widgets privés internes réécrits) et `lib/app/router.dart` (une route existante lit désormais `state.extra`). Aucun nouveau fichier, aucun changement de BLoC/backend — tout le state management (`ProfilePublicBloc`, `TravelerSubscribeBloc`, `IncidentReportCubit`) existe déjà.

**Tech Stack:** Flutter/Dart, flutter_bloc, GoRouter, mocktail + bloc_test (tests), design system dony (`lib/core/design/`).

## Global Constraints

- Design system dony : `DonyColors`/`DonySpacing`/`DonyRadius` via `Theme.of(context).colorScheme` en `build()` (jamais de couleur hardcodée) — voir `lib/core/design/CLAUDE.md`.
- `setState` interdit → tout passe par les BLoCs existants (`ProfilePublicBloc`, `TravelerSubscribeBloc`).
- `Navigator.push()` interdit → `context.push()`/`context.go()` (GoRouter) uniquement.
- Aucun `Co-Authored-By: Claude` dans les commits ; jamais de commit direct sur `main` (déjà sur la branche `docs/profil-public-simplification-spec` — continuer dessus ou créer `feature/profil-public-simplification` selon préférence de l'exécutant).
- Couverture de tests ≥ 90 % sur les fichiers modifiés ; tous les tests doivent passer avant de considérer une tâche terminée.
- Spec source : `docs/superpowers/specs/2026-07-11-profil-public-simplification-design.md`.

---

## Task 1: Route `report-incident` — accepter une cible contextuelle

**Files:**
- Modify: `lib/app/router.dart:1080-1089` (route `report-incident`) et son bloc d'imports (haut de fichier, à côté de `incident_report_cubit.dart` / `incident_report_screen.dart`, ~L143-145)
- Test: `test/app/router_extra_report_incident_test.dart` (nouveau)

**Interfaces:**
- Consomme : `IncidentReportScreen(targetType: IncidentTargetType, targetId: String?)` (existant, `lib/features/incident_report/presentation/screens/incident_report_screen.dart:21`), `IncidentTargetType` enum (existant, `lib/features/incident_report/data/repositories/incident_report_repository.dart:4`).
- Produit : la route GoRouter `/settings/report-incident` accepte désormais `extra: {'targetType': IncidentTargetType, 'targetId': String?}` — Task 5 en dépend pour naviguer depuis le profil public.

> Note : `lib/app/router.dart` expose un singleton top-level `final appRouter = GoRouter(...)` (L192), pas de factory paramétrable. Aucun test dédié n'existe aujourd'hui pour `router.dart` dans ce repo (`test/app/` ne contient aucun fichier `*router*`) — construire un `GoRouter` de test complet autour du singleton réel tirerait toute la DI de l'app (`getIt`) pour un seul `GoRoute`, ce qui n'est pas la convention ici. Cette tâche est donc validée par `flutter analyze` (le fichier compile, le pattern `state.extra as Map<String, dynamic>?` est déjà utilisé sans test dédié ailleurs dans ce même fichier — ex. L398, L681, L868) + le test d'intégration côté appelant (Task 5, qui vérifie que `profile_public_screen.dart` déclenche bien la navigation avec les bons `extra`) + la vérification manuelle bout-en-bout (Task 6).

- [ ] **Step 1: Modifier la route**

Dans `lib/app/router.dart`, ajouter l'import (à côté des imports `incident_report_*` existants, ~L143-145) :

```dart
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
```

Remplacer le bloc `GoRoute(path: 'report-incident', ...)` (L1080-1089) par :

```dart
        GoRoute(
          path: 'report-incident',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final targetType =
                extra?['targetType'] as IncidentTargetType? ??
                    IncidentTargetType.app;
            final targetId = extra?['targetId'] as String?;
            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => getIt<IncidentReportCubit>()),
                BlocProvider(create: (_) => getIt<IncidentPhotosCubit>()),
              ],
              child: IncidentReportScreen(
                targetType: targetType,
                targetId: targetId,
              ),
            );
          },
        ),
```

- [ ] **Step 2: Vérifier la compilation**

Run: `flutter analyze lib/app/router.dart`
Attendu : aucune erreur (0 issue sur ce fichier — des warnings préexistants sans rapport ailleurs dans le fichier ne bloquent pas cette tâche).

- [ ] **Step 3: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat(router): route report-incident accepte targetType/targetId via extra"
```

---

## Task 2: Hero plat — suppression du bandeau bleu et de la barre sticky

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_public_screen.dart` (`Scaffold.body`, L131-142 ; `_StickySubscribeBar`/`_SubscribeButton`, L148-211 — supprimés, remplacés par Task 3 ; `_HeroBand`/`_HeroAvatar`/`_HeroPill`, L353-587 — réécrits)
- Test: `test/features/profile/presentation/screens/profile_public_screen_test.dart` (existant — modifié)

**Interfaces:**
- Consomme : `ProfilePublicModel` (inchangé), `Theme.of(context).colorScheme`.
- Produit : `_ProfileHero` (nouveau nom, remplace `_HeroBand`) — `Widget _ProfileHero({required ProfilePublicModel profile, required Widget? subscribeAction})`, où `subscribeAction` est fourni par Task 3.

- [ ] **Step 1: Modifier le test existant qui vérifie l'absence du gradient et de la sticky bar**

Dans `test/features/profile/presentation/screens/profile_public_screen_test.dart`, ajouter après le test `'shows displayName when loaded'` (L304-315) :

```dart
  testWidgets('hero has no blue gradient background', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasBlueGradient = containers.any((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration && decoration.gradient != null;
    });
    expect(hasBlueGradient, isFalse);
  });

  testWidgets('no sticky bar container above the scroll area', (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The Scaffold body must be the scrollable content directly — no
    // Column([Expanded(body), stickyBar]) wrapper anymore.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.body, isA<CustomScrollView>());
  });
```

- [ ] **Step 2: Lancer les tests, vérifier l'échec**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart --plain-name "hero has no blue gradient"`
Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart --plain-name "no sticky bar container"`
Attendu : les deux échouent (le gradient existe encore, `scaffold.body` est un `Column`, pas un `CustomScrollView`, tant que `showSubscribe: true`).

- [ ] **Step 3: Retirer la sticky bar du `Scaffold.body`**

Dans `profile_public_screen.dart`, remplacer (L129-142) :

```dart
        // Use a raw Scaffold so the hero band can be truly edge-to-edge
        // (DonyPageScaffold wraps the body in a Padding which would indent it).
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DonyAppBar(title: appBarTitle),
          body: showButton
              ? Column(
                  children: [
                    Expanded(child: body),
                    _StickySubscribeBar(),
                  ],
                )
              : body,
        );
```

par :

```dart
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DonyAppBar(title: appBarTitle),
          body: body,
        );
```

Supprimer entièrement les classes `_StickySubscribeBar` et `_SubscribeButton` (L148-211) — leur logique est reprise et adaptée dans Task 3, directement dans le hero.

`_LoadedView` doit maintenant recevoir `showButton` pour le transmettre au hero (Task 3 branchera dessus). Modifier sa signature (L237-246) :

```dart
class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.userId,
    required this.profile,
    required this.recentRatings,
    required this.showSubscribeButton,
  });

  final String userId;
  final ProfilePublicModel profile;
  final RatingSummary recentRatings;
  final bool showSubscribeButton;
```

Et son instanciation (L119-124) :

```dart
        } else if (state is ProfilePublicLoaded) {
          body = _LoadedView(
            userId: viewedUserId,
            profile: state.profile,
            recentRatings: state.recentRatings,
            showSubscribeButton: showButton,
          );
```

- [ ] **Step 4: Réécrire le hero sans gradient, centré**

Remplacer `_HeroBand` et `_HeroAvatar`/`_HeroPill` (L351-587) par :

```dart
// ─── Profile hero — flat background, centered ────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, this.subscribeAction});

  final ProfilePublicModel profile;
  final Widget? subscribeAction;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final ratingStr = profile.averageRating > 0
        ? profile.averageRating.toStringAsFixed(1)
        : '—';
    final metaLine =
        '⭐ $ratingStr · ${profile.ratingCount} avis · ${profile.memberSince}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: Column(
        children: [
          _HeroAvatar(
            name: profile.displayName,
            imageUrl: profile.avatarUrl,
            verified: profile.kycVerified,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            profile.displayName,
            style: tt.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (profile.kycVerified || profile.isProAccount || profile.isKiloPro) ...[
            const SizedBox(height: DonySpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: DonySpacing.xs,
              runSpacing: DonySpacing.xs,
              children: [
                if (profile.kycVerified) const _HeroPill(label: '✓ Vérifié'),
                if (profile.isProAccount) const _HeroPill(label: 'PRO'),
                if (profile.isKiloPro) const _HeroPill(label: 'Kilo Pro'),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.xs),
          Text(
            metaLine,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subscribeAction != null) ...[
            const SizedBox(height: DonySpacing.base),
            subscribeAction!,
          ],
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.name,
    required this.verified,
    this.imageUrl,
  });

  final String name;
  final bool verified;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 64.0;
    final initials = _initials(name);

    Widget avatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsCircle(initials, size),
        ),
      );
    } else {
      avatar = _initialsCircle(initials, size);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size + 4,
          height: size + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipOval(child: avatar),
          ),
        ),
        if (verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: DonyColors.warning500,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text(
                '✓',
                style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _initialsCircle(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DonyColors.terra400, DonyColors.terra600],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
      ),
    );
  }
}
```

> Note : `_ProfileHero` a un paramètre `subscribeAction` branché en Task 3. Tant que Task 3 n'est pas faite, appeler `_ProfileHero(profile: profile)` sans second argument (défaut `null`) dans `_LoadedView` — voir Step 5.

- [ ] **Step 5: Brancher `_ProfileHero` dans `_LoadedView`**

Dans `_LoadedView.build` (L248-258), remplacer :

```dart
        SliverToBoxAdapter(
          child: _HeroBand(profile: profile)
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
```

par :

```dart
        SliverToBoxAdapter(
          child: _ProfileHero(profile: profile)
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
```

(Task 3 réinjectera `subscribeAction:` ici.)

- [ ] **Step 6: Lancer les tests, vérifier le succès**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart`
Attendu : PASS pour tous les tests SAUF ceux de la section "9. Subscribe button gating" (L489-573) — normal, ils seront réécrits en Task 3. Noter les échecs, ne pas s'en inquiéter à cette étape.

- [ ] **Step 7: Commit**

```bash
git add lib/features/profile/presentation/screens/profile_public_screen.dart test/features/profile/presentation/screens/profile_public_screen_test.dart
git commit -m "refactor(profile): hero plat sans bandeau bleu, sticky bar retirée"
```

---

## Task 3: Bouton d'abonnement compact + cloche interactive dans le hero

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_public_screen.dart` (imports en tête ; `_LoadedView.build` pour brancher `subscribeAction` ; nouvelle classe `_SubscribeAction`)
- Test: `test/features/profile/presentation/screens/profile_public_screen_test.dart` (section "9. Subscribe button gating", L489-573 — réécrite)

**Interfaces:**
- Consomme : `TravelerSubscribeBloc`/`TravelerSubscribeState` (`subscribed`, `pushEnabled`, `status`), events `SubscribePressed`, `UnsubscribePressed`, `TogglePushPressed(bool)` (tous existants, `lib/features/subscriptions/bloc/`).
- Produit : `_SubscribeAction` — `Widget` sans état exposé, consommé uniquement par `_LoadedView` (Task 2, Step 5).

- [ ] **Step 1: Réécrire la section de test "Subscribe button gating"**

Dans `test/features/profile/presentation/screens/profile_public_screen_test.dart`, remplacer entièrement le bloc `// ── 9. Subscribe button gating ──` jusqu'à la fin du fichier (L489-573, dernier `}` du `main()` exclu) par :

```dart
  // ── 9. Subscribe action — compact, in-hero ────────────────────────────────

  testWidgets(
      'subscribe button appears when showSubscribe=true and userId != currentUser',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsOneWidget);
  });

  testWidgets('subscribe button absent when showSubscribe=false', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        showSubscribe: false,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsNothing);
    expect(find.text('Abonné ✓'), findsNothing);
  });

  testWidgets('subscribe button absent when viewing own profile', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _userId, // same → own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsNothing);
    expect(find.text('Abonné ✓'), findsNothing);
  });

  testWidgets('shows "Abonné ✓" + bell icon when already subscribed',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Abonné ✓'), findsOneWidget);
    expect(find.text("S'abonner"), findsNothing);
    expect(find.byIcon, findsNothing); // sanity: no stray Icon-based check
  });

  testWidgets('tapping subscribe dispatches SubscribePressed', (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text("S'abonner"));
    verify(() => subBloc.add(const SubscribePressed())).called(1);
  });

  testWidgets('tapping bell dispatches TogglePushPressed(!pushEnabled)',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Désactiver les notifications'));
    verify(() => subBloc.add(const TogglePushPressed(false))).called(1);
  });

  testWidgets('tapping "Abonné ✓" opens confirm dialog, confirming unsubscribes',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Abonné ✓'));
    await tester.pumpAndSettle();

    expect(find.text('Se désabonner ?'), findsOneWidget);

    await tester.tap(find.text('Se désabonner'));
    await tester.pumpAndSettle();

    verify(() => subBloc.add(const UnsubscribePressed())).called(1);
  });
}
```

Retirer la ligne `expect(find.byIcon, findsNothing);` du test "shows Abonné ✓ + bell icon" si `flutter analyze` la signale invalide (`find.byIcon` attend un argument) — cette ligne est un garde-fou optionnel, la remplacer simplement par la suppression de la ligne si elle ne compile pas telle quelle.

- [ ] **Step 2: Lancer les tests, vérifier l'échec**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart`
Attendu : tous les tests de la section 9 échouent (aucun `_SubscribeAction`, aucun bouton dans le hero).

- [ ] **Step 3: Ajouter les imports nécessaires**

En tête de `profile_public_screen.dart`, ajouter :

```dart
import 'package:go_router/go_router.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
```

(Le second import sert Task 5 — l'ajouter ici évite un aller-retour ; s'il n'est pas encore utilisé à la fin de cette tâche, `flutter analyze` le signalera comme inutilisé — c'est attendu, Task 5 le consomme.)

- [ ] **Step 4: Écrire `_SubscribeAction`**

Ajouter à la fin du fichier (après `_InitialsCircle`, dernière classe) :

```dart
// ─── Subscribe action — compact button + interactive bell (in-hero) ──────────

class _SubscribeAction extends StatelessWidget {
  const _SubscribeAction();

  Future<void> _confirmUnsubscribe(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Se désabonner ?',
      message: 'Vous ne recevrez plus les notifications de ce voyageur.',
      confirmLabel: 'Se désabonner',
      cancelLabel: 'Annuler',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'bell-off',
    );
    if ((confirmed ?? false) && context.mounted) {
      context.read<TravelerSubscribeBloc>().add(const UnsubscribePressed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<TravelerSubscribeBloc, TravelerSubscribeState>(
      builder: (context, state) {
        final isLoading = state.status == TravelerSubscribeStatus.loading ||
            state.status == TravelerSubscribeStatus.initial;

        if (state.subscribed) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyButton(
                label: 'Abonné ✓',
                variant: DonyButtonVariant.secondary,
                fullWidth: false,
                isLoading: isLoading,
                onPressed:
                    isLoading ? null : () => _confirmUnsubscribe(context),
              ),
              const SizedBox(width: DonySpacing.sm),
              IconButton(
                tooltip: state.pushEnabled
                    ? 'Désactiver les notifications'
                    : 'Activer les notifications',
                icon: DonyIcon(
                  state.pushEnabled ? 'bell' : 'bell-off',
                  color: cs.primary,
                ),
                onPressed: isLoading
                    ? null
                    : () => context
                        .read<TravelerSubscribeBloc>()
                        .add(TogglePushPressed(!state.pushEnabled)),
              ),
            ],
          );
        }

        return DonyButton(
          label: "S'abonner",
          iconAsset: 'bell',
          fullWidth: false,
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () =>
                  context.read<TravelerSubscribeBloc>().add(const SubscribePressed()),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Brancher dans `_LoadedView`**

Modifier l'instanciation du hero (Task 2, Step 5) pour passer `subscribeAction` conditionnellement :

```dart
        SliverToBoxAdapter(
          child: _ProfileHero(
            profile: profile,
            subscribeAction:
                showSubscribeButton ? const _SubscribeAction() : null,
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
```

- [ ] **Step 6: Lancer les tests, vérifier le succès**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart`
Attendu : PASS (tous les tests, y compris la section 9 réécrite).

- [ ] **Step 7: Commit**

```bash
git add lib/features/profile/presentation/screens/profile_public_screen.dart test/features/profile/presentation/screens/profile_public_screen_test.dart
git commit -m "feat(profile): bouton abonnement compact + cloche notification interactive dans le hero"
```

---

## Task 4: Stats row — retrait de "Répond en"

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_public_screen.dart` (`_StatsRow`, L591-647)
- Test: `test/features/profile/presentation/screens/profile_public_screen_test.dart` (section "7. Stats row", L401-413)

**Interfaces:**
- Consomme : `ProfilePublicModel.averageRating`, `.completedBidsCount` (inchangés — `.responseDelayHours` n'est plus lu par ce widget).
- Produit : `_StatsRow` toujours instanciée sans paramètre supplémentaire (signature inchangée : `_StatsRow({required this.profile})`).

- [ ] **Step 1: Modifier le test existant**

Remplacer (L401-413) :

```dart
  // ── 7. Stats row: 3 cols, no "Membre depuis" stat ────────────────────────

  testWidgets('stats row shows Note, Livraisons, Répond en (3 columns)',
      (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Note', skipOffstage: false), findsOneWidget);
    expect(find.text('Livraisons', skipOffstage: false), findsOneWidget);
    expect(find.text('Répond en', skipOffstage: false), findsOneWidget);
    // "Membre depuis" should NOT appear as a stat column
    expect(find.text('Membre depuis', skipOffstage: false), findsNothing);
  });
```

par :

```dart
  // ── 7. Stats row: 2 cols, no "Répond en" / "Membre depuis" stat ──────────

  testWidgets('stats row shows Note and Livraisons only (2 columns)',
      (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Note', skipOffstage: false), findsOneWidget);
    expect(find.text('Livraisons', skipOffstage: false), findsOneWidget);
    expect(find.text('Répond en', skipOffstage: false), findsNothing);
    expect(find.text('Membre depuis', skipOffstage: false), findsNothing);
  });
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart --plain-name "stats row shows Note and Livraisons only"`
Attendu : FAIL (`find.text('Répond en')` trouve toujours un widget).

- [ ] **Step 3: Retirer la colonne "Répond en"**

Dans `_StatsRow.build` (L604-646), remplacer :

```dart
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: profile.averageRating > 0
                  ? profile.averageRating.toStringAsFixed(1)
                  : '—',
              label: 'Note',
              iconAsset: 'star',
              iconColor: DonyColors.warning500,
            ),
          ),
          VerticalDivider(
            color: cs.outline.withValues(alpha: 0.6),
            width: 1,
            thickness: 1,
          ),
          Expanded(
            child: _StatItem(
              value: '${profile.completedBidsCount}',
              label: 'Livraisons',
              iconAsset: 'package',
              iconColor: cs.primary,
            ),
          ),
          VerticalDivider(
            color: cs.outline.withValues(alpha: 0.6),
            width: 1,
            thickness: 1,
          ),
          Expanded(
            child: _StatItem(
              value: delayLabel,
              label: 'Répond en',
              iconAsset: 'timer',
              iconColor: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
```

par :

```dart
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: profile.averageRating > 0
                  ? profile.averageRating.toStringAsFixed(1)
                  : '—',
              label: 'Note',
              iconAsset: 'star',
              iconColor: DonyColors.warning500,
            ),
          ),
          VerticalDivider(
            color: cs.outline.withValues(alpha: 0.6),
            width: 1,
            thickness: 1,
          ),
          Expanded(
            child: _StatItem(
              value: '${profile.completedBidsCount}',
              label: 'Livraisons',
              iconAsset: 'package',
              iconColor: cs.primary,
            ),
          ),
        ],
      ),
    );
```

Retirer aussi la variable devenue inutile juste au-dessus (L600-602) :

```dart
    final delayLabel = profile.responseDelayHours != null
        ? '~${profile.responseDelayHours}h'
        : '—';
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart`
Attendu : PASS (tous les tests du fichier).

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/screens/profile_public_screen.dart test/features/profile/presentation/screens/profile_public_screen_test.dart
git commit -m "refactor(profile): stats row réduite à Note + Livraisons"
```

---

## Task 5: Signalement — action ⋮ dans la navbar

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_public_screen.dart` (`DonyAppBar` instanciation, L133 ; imports déjà ajoutés en Task 3, Step 3)
- Test: `test/features/profile/presentation/screens/profile_public_screen_test.dart` (nouvelle section)

**Interfaces:**
- Consomme : route `/settings/report-incident` (Task 1) via `context.push(String, {Object? extra})` ; `IncidentTargetType.user` (existant).
- Produit : aucune nouvelle interface exposée — comportement terminal de l'écran.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter à la fin de `test/features/profile/presentation/screens/profile_public_screen_test.dart`, dans `main()`, avant l'accolade fermante (après la section 9 de Task 3) :

```dart
  // ── 10. Report action (⋮) ─────────────────────────────────────────────────

  testWidgets('report icon absent when viewing own profile', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        screenUserId: _userId,
        authUserId: _userId, // own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Signaler'), findsNothing);
  });

  testWidgets(
      'report icon present, tap navigates to report-incident with user target',
      (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        screenUserId: _userId,
        authUserId: _currentUserId, // different user → not own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Signaler'), findsOneWidget);

    await tester.tap(find.byTooltip('Signaler'));
    await tester.pumpAndSettle();

    expect(find.text('Reported: user-1'), findsOneWidget);
  });
}
```

Ajouter la route stub correspondante dans le helper `_wrap` (`GoRoute(path: '/settings/report-incident', ...)`), juste après la route `/profile/reviews` existante (~L164-167) :

```dart
          GoRoute(
            path: '/profile/reviews',
            builder: (_, _) => const Scaffold(body: Text('Reviews')),
          ),
          GoRoute(
            path: '/settings/report-incident',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return Scaffold(
                body: Text('Reported: ${extra?['targetId']}'),
              );
            },
          ),
```

- [ ] **Step 2: Lancer les tests, vérifier l'échec**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart --plain-name "report icon"`
Attendu : FAIL (`find.byTooltip('Signaler')` ne trouve rien — l'action n'existe pas encore dans `DonyAppBar`).

- [ ] **Step 3: Ajouter l'action ⋮ dans `DonyAppBar`**

Dans `profile_public_screen.dart`, `build()` de `_ProfilePublicScreenState` (L85-145), extraire `cs` et construire `actions` avant le `return Scaffold(...)` :

```dart
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DonyAppBar(
            title: appBarTitle,
            actions: isOwnProfile
                ? null
                : [
                    IconButton(
                      tooltip: 'Signaler',
                      icon: DonyIcon('flag', color: cs.onSurfaceVariant),
                      onPressed: () => context.push(
                        '/settings/report-incident',
                        extra: {
                          'targetType': IncidentTargetType.user,
                          'targetId': viewedUserId,
                        },
                      ),
                    ),
                  ],
          ),
          body: body,
        );
```

- [ ] **Step 4: Lancer les tests, vérifier le succès**

Run: `flutter test test/features/profile/presentation/screens/profile_public_screen_test.dart`
Attendu : PASS (tous les tests du fichier, section 10 incluse).

- [ ] **Step 5: Vérifier l'ensemble du fichier + couverture**

Run: `flutter analyze lib/features/profile/presentation/screens/profile_public_screen.dart lib/app/router.dart`
Attendu : aucune erreur. Si un import est signalé inutilisé (ex: `go_router` si un des imports Task 3/5 n'était finalement pas nécessaire), le retirer.

Run: `flutter test --coverage test/features/profile/presentation/screens/profile_public_screen_test.dart test/app/router_extra_report_incident_test.dart`
Attendu : tous PASS. Ouvrir `coverage/lcov.info` (ou `genhtml coverage/lcov.info -o coverage/html`) et vérifier que `profile_public_screen.dart` est ≥ 90 % couvert ; sinon ajouter les cas manquants (ex: `isLoading` state du bouton, avatar avec `imageUrl` réseau qui échoue → `errorBuilder`).

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/presentation/screens/profile_public_screen.dart test/features/profile/presentation/screens/profile_public_screen_test.dart
git commit -m "feat(profile): action Signaler (⋮) vers IncidentReportScreen ciblé USER"
```

---

## Task 6: Vérification manuelle (QA visuelle)

**Files:** aucun (validation uniquement).

- [ ] **Step 1: Lancer l'app en dev**

```bash
flutter run --dart-define-from-file=env.dev.json
```

- [ ] **Step 2: Naviguer vers un profil public d'un autre utilisateur**

Depuis un écran qui pousse `/profile/public` avec `ProfilePublicArgs(userId: ..., showSubscribe: true)` (ex: carte voyageur dans le matching). Vérifier :
- Pas de bandeau bleu — fond uni du haut en bas.
- Le bouton d'abonnement est centré, largeur au contenu (pas pleine largeur), plus de barre fixée en bas d'écran.
- Scroll : la navbar (‹ retour, nom, ⋮) reste fixe ; avatar/bouton/stats/sections défilent normalement.
- Tap "S'abonner" → bouton passe en "Abonné ✓" + cloche apparaît à côté.
- Tap la cloche → tooltip et icône basculent `bell`/`bell-off`.
- Tap "Abonné ✓" → dialog de confirmation "Se désabonner ?" ; confirmer désabonne.
- Tap ⋮ → navigue vers l'écran "Signaler un problème", motif/description/photos, soumission fonctionne (toast succès).
- Sur son propre profil (`/profile/public` sans `userId` ou avec son propre id) : pas de bouton d'abonnement, pas d'icône ⋮.

- [ ] **Step 3: Documenter les écarts éventuels**

Si un écart de rendu est constaté (espacement, couleur, alignement), corriger directement dans `profile_public_screen.dart` — pas de nouvelle tâche nécessaire pour des ajustements mineurs de style, ils rentrent dans le scope de Task 2/3/4.

---

## Self-Review

**Couverture de la spec :**
- §1 (suppression bandeau + sticky bar) → Task 2 ✅
- §2 (hero plat + bouton compact + cloche interactive) → Task 2 (hero) + Task 3 (bouton/cloche) ✅
- §2 stats 2 colonnes → Task 4 ✅
- §3 (signalement, route report-incident, navigation) → Task 1 + Task 5 ✅
- §4 (sections À propos/Langues/Transport/Badges/Disponibilité/Avis inchangées) → non touchées par aucune tâche, confirmé par absence de modification dans les tâches 2-5 ✅
- §5 (tests) → couverts par les steps de test de chaque tâche + Task 5 Step 5 (couverture globale) ✅

**Placeholder scan :** aucun "TBD"/"TODO" — tous les blocs de code sont complets et compilables en l'état. Task 1 n'a pas de test dédié (justifié explicitement dans sa note d'introduction : pas de convention de test router existante dans ce repo) mais reste vérifiée par `flutter analyze` + le test d'intégration de Task 5 + la QA manuelle de Task 6.

**Cohérence des types :** `TravelerSubscribeState.pushEnabled` (bool, existant) utilisé identiquement dans Task 3 Step 4 et les tests Step 1 — `TogglePushPressed(bool enabled)` signature respectée partout. `IncidentTargetType.user`/`targetId: String?` cohérents entre Task 1 (route) et Task 5 (appel `context.push`).
