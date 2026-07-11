# Statut DRAFT (brouillon) — dony_app (Flutter) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Câbler dans l'app mobile le statut DRAFT livré par le backend : enregistrer un trajet comme brouillon depuis le wizard de création, le filtrer/l'afficher dans « Mes trajets », le publier depuis le détail.

**Architecture:** Le backend (dony-back PR #95) accepte `saveAsDraft: true` dans le body de `POST /announcements` et expose `POST /announcements/{id}/publish`. Côté app : le statut reste un `String` (pas d'enum à créer — convention existante du modèle), extension datasource→repository→bloc→UI. Erreurs RFC 7807 via l'interceptor existant (`ApiClient` pose des exceptions typées portant `code`).

**Tech Stack:** Flutter, flutter_bloc, GoRouter, Dio, bloc_test + mocktail.

## Global Constraints

- Spec de référence : `dony-pro/docs/superpowers/specs/2026-07-11-trip-draft-status-design.md` (section 3).
- Branche : `feature/trip-draft-status` (à créer depuis main sur dony_app).
- Contrat backend : body `saveAsDraft: true` (booléen, omis = comportement actuel) sur `POST /announcements` ; `POST /announcements/{id}/publish` → 200 annonce détaillée. Codes d'erreur (champ `code` du ProblemDetail) : `draft-limit-reached` (403), `not-a-draft` (422), `publishing-suspended` (403), `kyc-not-verified` (403), `pro-limit-reached` (403), `departure-date-passed` (422).
- Le statut est un `String` (`AnnouncementModel.status`) — littéral `'DRAFT'`. NE PAS créer d'enum Dart.
- Règle repo OBLIGATOIRE : tout `DonyButton` dans un bottom sheet va dans `stickyBottom`, jamais dans le `child`.
- Pas de `setState` (BLoC only), pas de `Navigator.push` (GoRouter only).
- i18n : aucune — libellés français en dur, comme le reste de l'app.
- TDD strict : test rouge d'abord. Commandes : `flutter test <chemin>` ; fin de tâche `flutter test test/features/matching/` puis suite complète en T6.
- Pas de `Co-Authored-By` dans les commits. Messages français conventionnels.
- Écrans legacy à NE PAS toucher : `create_announcement_screen.dart`, `create_announcement_bottom_sheet.dart`, `announcement_detail_screen.dart` (non référencés par le flux courant).

---

### Task 1: Data — saveAsDraft + publishAnnouncement (datasource + repository)

**Files:**
- Modify: `lib/features/matching/data/datasources/announcement_remote_datasource.dart` (createAnnouncement ~l.36, body l.38-61)
- Modify: `lib/features/matching/data/repositories/announcement_repository.dart` (createAnnouncement l.13-57)
- Test: `test/features/matching/data/repositories/announcement_repository_test.dart` (existant — pattern `MockAnnouncementRemoteDatasource extends Mock implements AnnouncementRemoteDatasource`)

**Interfaces:**
- Produces: datasource et repository `createAnnouncement({..., bool saveAsDraft = false})` — le body POST contient `'saveAsDraft': true` UNIQUEMENT si le flag est vrai (rétro-compatibilité stricte) ; `Future<AnnouncementModel> publishAnnouncement(String id)` → `POST /announcements/$id/publish`.

- [ ] **Step 1: Tests qui échouent**

Dans `announcement_repository_test.dart`, en suivant le pattern de délégation existant du fichier (mêmes fixtures/`registerFallbackValue`) :

```dart
test('createAnnouncement propage saveAsDraft au datasource', () async {
  when(() => mockDatasource.createAnnouncement(
        // ... reprendre les named args any(named: ...) du test de délégation existant
        saveAsDraft: any(named: 'saveAsDraft'),
      )).thenAnswer((_) async => testAnnouncement);
  await repository.createAnnouncement(
    // ... mêmes args que le test existant,
    saveAsDraft: true,
  );
  final captured = verify(() => mockDatasource.createAnnouncement(
        // ... any(named: ...),
        saveAsDraft: captureAny(named: 'saveAsDraft'),
      )).captured;
  expect(captured.single, isTrue);
});

test('publishAnnouncement délègue au datasource', () async {
  when(() => mockDatasource.publishAnnouncement('a1'))
      .thenAnswer((_) async => testAnnouncement);
  final result = await repository.publishAnnouncement('a1');
  expect(result, testAnnouncement);
  verify(() => mockDatasource.publishAnnouncement('a1')).called(1);
});
```

(Reprendre les args exacts du test de délégation `createAnnouncement` déjà présent dans ce fichier — ne pas inventer de nouvelles fixtures.)

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/data/repositories/announcement_repository_test.dart`
Expected: FAIL — `saveAsDraft` n'est pas un paramètre, `publishAnnouncement` n'existe pas.

- [ ] **Step 3: Implémentation minimale**

Datasource — signature : ajouter `bool saveAsDraft = false` aux named params de `createAnnouncement` ; dans la construction du body (l.38-61) :

```dart
final body = <String, dynamic>{
  // ... champs existants inchangés
  if (saveAsDraft) 'saveAsDraft': true,
};
```

Nouvelle méthode (suivre le style des autres méthodes du fichier) :

```dart
Future<AnnouncementModel> publishAnnouncement(String id) async {
  final response = await _apiClient.dio.post('/announcements/$id/publish');
  return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
}
```

Repository — ajouter `bool saveAsDraft = false` à `createAnnouncement` et le passer au datasource ; ajouter :

```dart
Future<AnnouncementModel> publishAnnouncement(String id) =>
    _datasource.publishAnnouncement(id);
```

(Adapter le nom du champ datasource à celui du fichier.)

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/matching/data/`
Expected: PASS, zéro régression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data/ test/features/matching/data/
git commit -m "feat(matching): data — création en brouillon (saveAsDraft) et publication d'une annonce"
```

---

### Task 2: BLoC + catalogue d'erreurs — création brouillon et publication

**Files:**
- Modify: `lib/features/matching/bloc/announcement_event.dart` (AnnouncementCreateRequested + nouvel event)
- Modify: `lib/features/matching/bloc/announcement_state.dart` (nouveaux states)
- Modify: `lib/features/matching/bloc/announcement_bloc.dart` (_onCreateRequested l.29-85 + nouveau handler)
- Modify: `lib/core/error/error_catalog.dart` (section « Annonces / trajets », l.72-92)
- Test: `test/features/matching/bloc/announcement_bloc_test.dart`

**Interfaces:**
- Consumes: `repository.createAnnouncement(saveAsDraft:)` et `repository.publishAnnouncement(id)` (Task 1).
- Produces: `AnnouncementCreateRequested` a un champ `final bool saveAsDraft` (défaut `false`, ajouté aux props Equatable) ; event `AnnouncementPublishRequested(String id)` ; states `AnnouncementPublished(AnnouncementModel announcement)`, `AnnouncementDraftLimitReached(String message)`, `AnnouncementKycRequired(String message)`, `AnnouncementDepartureDatePassed(String message)` — consommés par Tasks 3 et 5.

- [ ] **Step 1: Tests qui échouent**

Dans `announcement_bloc_test.dart` (pattern `blocTest` + `when(() => mockRepo...)` du fichier) :

```dart
blocTest<AnnouncementBloc, AnnouncementState>(
  'création en brouillon propage saveAsDraft et ne marque pas kHasPublishedAsTraveler',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.createAnnouncement(
          /* ... any(named:) comme le test de création existant ... */
          saveAsDraft: any(named: 'saveAsDraft'),
        )).thenAnswer((_) async => testAnnouncement);
  },
  act: (bloc) => bloc.add(/* AnnouncementCreateRequested identique au test existant + */ saveAsDraft: true),
  expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementCreated>()],
  verify: (_) {
    final captured = verify(() => mockRepo.createAnnouncement(
          /* ... */
          saveAsDraft: captureAny(named: 'saveAsDraft'),
        )).captured;
    expect(captured.single, isTrue);
    verifyNever(() => mockUserPrefsBox.put(HiveService.kHasPublishedAsTraveler, true));
  },
);

blocTest<AnnouncementBloc, AnnouncementState>(
  'draft-limit-reached émet AnnouncementDraftLimitReached',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.createAnnouncement(/* ... */ saveAsDraft: any(named: 'saveAsDraft')))
        .thenThrow(const ForbiddenException('Limite de brouillons atteinte', code: 'draft-limit-reached'));
  },
  act: (bloc) => bloc.add(/* create avec saveAsDraft: true */),
  expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementDraftLimitReached>()],
);

blocTest<AnnouncementBloc, AnnouncementState>(
  'AnnouncementPublishRequested publie et émet AnnouncementPublished',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.publishAnnouncement('a1')).thenAnswer((_) async => testAnnouncement);
  },
  act: (bloc) => bloc.add(const AnnouncementPublishRequested('a1')),
  expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementPublished>()],
);

blocTest<AnnouncementBloc, AnnouncementState>(
  'publish kyc-not-verified émet AnnouncementKycRequired',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.publishAnnouncement('a1'))
        .thenThrow(const ForbiddenException('KYC requis', code: 'kyc-not-verified'));
  },
  act: (bloc) => bloc.add(const AnnouncementPublishRequested('a1')),
  expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementKycRequired>()],
);

blocTest<AnnouncementBloc, AnnouncementState>(
  'publish departure-date-passed émet AnnouncementDepartureDatePassed',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.publishAnnouncement('a1'))
        .thenThrow(const ValidationException('Date passée', code: 'departure-date-passed'));
  },
  act: (bloc) => bloc.add(const AnnouncementPublishRequested('a1')),
  expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementDepartureDatePassed>()],
);

blocTest<AnnouncementBloc, AnnouncementState>(
  'publish pro-limit-reached émet AnnouncementProLimitReached',
  build: buildBloc,
  setUp: () {
    when(() => mockRepo.publishAnnouncement('a1'))
        .thenThrow(const ForbiddenException('Limite', code: 'pro-limit-reached'));
  },
  act: (bloc) => bloc.add(const AnnouncementPublishRequested('a1')),
  expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementProLimitReached>()],
);
```

Adapter les constructeurs de `ForbiddenException`/`ValidationException` à leur vraie signature (`lib/core/error/app_exception.dart`) et le mock Hive à celui du fichier de test (si le test existant vérifie `kHasPublishedAsTraveler` autrement, suivre son pattern).

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/bloc/announcement_bloc_test.dart`
Expected: FAIL — champ `saveAsDraft` inexistant, event/states inexistants.

- [ ] **Step 3: Implémentation minimale**

`announcement_event.dart` : ajouter `final bool saveAsDraft;` (défaut `false`) à `AnnouncementCreateRequested` (+ props) et :

```dart
class AnnouncementPublishRequested extends AnnouncementEvent {
  final String id;
  const AnnouncementPublishRequested(this.id);
  @override
  List<Object?> get props => [id];
}
```

`announcement_state.dart` :

```dart
class AnnouncementPublished extends AnnouncementState {
  final AnnouncementModel announcement;
  const AnnouncementPublished(this.announcement);
  @override
  List<Object?> get props => [announcement];
}

class AnnouncementDraftLimitReached extends AnnouncementState {
  final String message;
  const AnnouncementDraftLimitReached(this.message);
  @override
  List<Object?> get props => [message];
}

class AnnouncementKycRequired extends AnnouncementState {
  final String message;
  const AnnouncementKycRequired(this.message);
  @override
  List<Object?> get props => [message];
}

class AnnouncementDepartureDatePassed extends AnnouncementState {
  final String message;
  const AnnouncementDepartureDatePassed(this.message);
  @override
  List<Object?> get props => [message];
}
```

(Adapter la classe de base/Equatable au style du fichier.)

`announcement_bloc.dart` — `_onCreateRequested` :
- passer `saveAsDraft: event.saveAsDraft` au repository ;
- `kHasPublishedAsTraveler` : n'écrire le flag Hive QUE si `!event.saveAsDraft` (un brouillon n'est pas une publication) ;
- analytics : ajouter `'is_draft': event.saveAsDraft` aux properties ;
- dans le catch, avant le cas `pro-limit-reached` :

```dart
if (error is ForbiddenException && error.code == 'draft-limit-reached') {
  emit(AnnouncementDraftLimitReached(error.message));
} else if (error is ForbiddenException && error.code == 'pro-limit-reached') {
  // ... existant
```

Nouveau handler (enregistré dans le constructeur) :

```dart
Future<void> _onPublishRequested(
  AnnouncementPublishRequested event,
  Emitter<AnnouncementState> emit,
) async {
  if (state is AnnouncementLoading) return;
  emit(AnnouncementLoading());
  try {
    final announcement = await _repository.publishAnnouncement(event.id);
    await _hive.userPrefs.put(HiveService.kHasPublishedAsTraveler, true);
    emit(AnnouncementPublished(announcement));
  } catch (e) {
    final error = unwrapDioError(e);
    if (error is ForbiddenException && error.code == 'kyc-not-verified') {
      emit(AnnouncementKycRequired(error.message));
    } else if (error is ForbiddenException && error.code == 'pro-limit-reached') {
      emit(AnnouncementProLimitReached(error.message));
    } else if (error is AppException && error.code == 'departure-date-passed') {
      emit(AnnouncementDepartureDatePassed(error.message));
    } else {
      emit(AnnouncementError(error));
    }
  }
}
```

`error_catalog.dart` — ajouter dans la section « Annonces / trajets » :

```dart
'draft-limit-reached': ErrorPresentation(
  title: 'Limite de brouillons atteinte',
  message: 'Passe en PRO pour créer davantage de brouillons.',
  severity: ErrorSeverity.warning,
  icon: Icons.drafts_outlined,
),
'not-a-draft': ErrorPresentation(
  title: 'Déjà publié',
  message: 'Ce trajet n\'est pas un brouillon.',
  severity: ErrorSeverity.warning,
  icon: Icons.info_outline_rounded,
),
'publishing-suspended': ErrorPresentation(
  title: 'Publication suspendue',
  message: 'La publication est suspendue sur ton compte. Contacte le support.',
  severity: ErrorSeverity.critical,
  icon: Icons.gpp_bad_rounded,
),
'kyc-not-verified': ErrorPresentation(
  title: 'Identité non vérifiée',
  message: 'Vérifie ton identité avant de publier un trajet.',
  severity: ErrorSeverity.warning,
  icon: Icons.badge_outlined,
),
'departure-date-passed': ErrorPresentation(
  title: 'Date de départ passée',
  message: 'Modifie la date de départ avant de publier ce trajet.',
  severity: ErrorSeverity.warning,
  icon: Icons.event_busy_rounded,
),
```

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/matching/bloc/`
Expected: PASS, zéro régression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/bloc/ lib/core/error/error_catalog.dart test/features/matching/bloc/
git commit -m "feat(matching): bloc — création en brouillon, publication et erreurs dédiées"
```

---

### Task 3: UI création — bouton « Enregistrer comme brouillon » dans l'aperçu

**Files:**
- Modify: `lib/features/matching/presentation/widgets/announcement_preview_sheet.dart` (show, stickyBottom l.28-43)
- Modify: `lib/features/matching/presentation/screens/create_trip_screen.dart` (`_submit` ~l.946, appel du sheet l.355-371, listener l.1167-1182)
- Test: `test/features/matching/presentation/announcement_preview_sheet_draft_test.dart` (créer, pattern widget test du dossier)

**Interfaces:**
- Consumes: `AnnouncementCreateRequested(saveAsDraft:)`, state `AnnouncementDraftLimitReached` (Task 2).
- Produces: `AnnouncementPreviewSheet.show(..., required VoidCallback onConfirm, VoidCallback? onSaveDraft)` — deux boutons dans `stickyBottom` (règle repo).

- [ ] **Step 1: Test qui échoue**

`announcement_preview_sheet_draft_test.dart` — widget test qui ouvre le sheet et vérifie les deux boutons (suivre le pattern d'un widget test existant du dossier pour le harnais MaterialApp/theme) :

```dart
testWidgets('l\'aperçu propose Publier et Enregistrer comme brouillon', (tester) async {
  var published = false;
  var savedDraft = false;
  await tester.pumpWidget(/* harnais MaterialApp du pattern existant */);
  // ouvrir via AnnouncementPreviewSheet.show(context, formState: fakeFormState,
  //   onConfirm: () => published = true, onSaveDraft: () => savedDraft = true)
  await tester.pumpAndSettle();
  expect(find.text('Publier l\'annonce'), findsOneWidget);
  expect(find.text('Enregistrer comme brouillon'), findsOneWidget);
  await tester.tap(find.text('Enregistrer comme brouillon'));
  await tester.pumpAndSettle();
  expect(savedDraft, isTrue);
  expect(published, isFalse);
});
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/presentation/announcement_preview_sheet_draft_test.dart`
Expected: FAIL — `onSaveDraft` n'existe pas / bouton absent.

- [ ] **Step 3: Implémentation minimale**

`announcement_preview_sheet.dart` — `show(...)` accepte `VoidCallback? onSaveDraft` ; `stickyBottom` devient une colonne de deux boutons (toujours dans `stickyBottom`, règle repo) :

```dart
stickyBottom: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    DonyButton(
      label: 'Publier l\'annonce',
      onPressed: isSubmitting ? null : onConfirm,
      isLoading: isSubmitting,
    ),
    if (onSaveDraft != null) ...[
      const SizedBox(height: DonySpacing.sm),
      DonyButton(
        label: 'Enregistrer comme brouillon',
        onPressed: isSubmitting ? null : onSaveDraft,
        // variante secondaire : utiliser le param du design system
        // (vérifier l'API de DonyButton — variant/type/secondary)
      ),
    ],
  ],
),
```

`create_trip_screen.dart` :
- `_submit({bool saveAsDraft = false})` → ajoute `saveAsDraft: saveAsDraft` à l'event `AnnouncementCreateRequested` (l.~994). Le brouillon n'est proposé qu'en mode création (pas en édition) : ne passe `onSaveDraft` que si `widget.args?.announcement == null` (adapter au vrai nom des args d'édition du fichier).
- Appel du sheet (l.355-371) : `onSaveDraft: () { context.pop(); _submit(saveAsDraft: true); }` (même fermeture du sheet que `onConfirm`).
- Listener (l.1167+) : ajouter la branche

```dart
if (state is AnnouncementDraftLimitReached) {
  // même pattern que AnnouncementProLimitReached : dialog upsell → /profile/upgrade-to-pro
}
```

(`AnnouncementCreated` couvre déjà le succès brouillon : `context.pop(true)` — la liste se rafraîchit.)

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/ test/features/matching/presentation/
git commit -m "feat(matching): bouton Enregistrer comme brouillon dans l'aperçu de création"
```

---

### Task 4: Liste « Mes trajets » — filtre, compteur et badge Brouillons

**Files:**
- Modify: `lib/features/matching/bloc/trip_filter_cubit.dart` (enum l.9, matchesStatus l.22-27)
- Modify: `lib/features/matching/presentation/screens/announcement_list_screen.dart` (chips l.341-372, counts l.33-48, tri l.22-29, vues vides)
- Modify: `lib/features/matching/presentation/widgets/trip_card.dart` (badge l.54-88, isPast l.49-50)
- Test: `test/features/matching/trip_filter_cubit_test.dart`, `test/features/matching/trip_card_test.dart`

**Interfaces:**
- Produces: `TripStatusFilter.draft` ; badge carte : `'DRAFT'` → label « Brouillon ».

- [ ] **Step 1: Tests qui échouent**

`trip_filter_cubit_test.dart` (pattern du fichier) :

```dart
test('draft ne matche que DRAFT', () {
  const state = TripFilterState(filter: TripStatusFilter.draft);
  expect(state.matchesStatus('DRAFT'), isTrue);
  expect(state.matchesStatus('ACTIVE'), isFalse);
});

test('all matche aussi DRAFT', () {
  const state = TripFilterState();
  expect(state.matchesStatus('DRAFT'), isTrue);
});
```

`trip_card_test.dart` (réutiliser le harnais/fixture du fichier) :

```dart
testWidgets('affiche le badge Brouillon pour un trajet DRAFT', (tester) async {
  // pump TripCard avec une annonce status: 'DRAFT' (copier la fixture existante)
  expect(find.text('Brouillon'), findsOneWidget);
});
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/trip_filter_cubit_test.dart test/features/matching/trip_card_test.dart`
Expected: FAIL — `TripStatusFilter.draft` inexistant, badge absent.

- [ ] **Step 3: Implémentation minimale**

`trip_filter_cubit.dart` :

```dart
enum TripStatusFilter { all, draft, active, completed, cancelled }
// matchesStatus :
TripStatusFilter.draft => status == 'DRAFT',
```

`trip_card.dart` — branche badge (au switch l.54-88, avant le défaut) :

```dart
'DRAFT' => (label: 'Brouillon', /* couleur neutre/ambre suivant la shape des autres branches */),
```

et exclure DRAFT de `isPast` (un brouillon n'est jamais « passé » visuellement).

`announcement_list_screen.dart` :
- `_buildChips` : chip `'Brouillons'` (clé `TripStatusFilter.draft`), placée après « Tous » ;
- `_counts()` : compteur des `status == 'DRAFT'` ;
- `_statusPriority` : DRAFT en tête (avant ACTIVE) pour que les brouillons soient visibles ;
- vue vide du filtre draft : texte « Aucun brouillon. Vos trajets enregistrés sans publication apparaîtront ici. » (suivre la structure `_EmptyView` existante).

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/matching/`
Expected: PASS, zéro régression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/bloc/trip_filter_cubit.dart lib/features/matching/presentation/ test/features/matching/
git commit -m "feat(matching): filtre, compteur et badge Brouillons dans Mes trajets"
```

---

### Task 5: Détail — bannière brouillon, action Publier, routage des erreurs

**Files:**
- Modify: `lib/features/matching/presentation/screens/trip_owner_detail_screen.dart` (_buildContent l.118-130, listener bloc)
- Modify: `lib/features/matching/presentation/widgets/owner_action_grid.dart` (gating l.63-67, tiles l.72-150)
- Modify: `lib/features/matching/presentation/widgets/announcement_detail_body.dart` (_StatusBadge l.267-280)
- Test: `test/features/matching/presentation/trip_owner_detail_draft_test.dart` (créer, pattern mocktail + BlocProvider de `create_announcement_capacity_submit_test.dart`)

**Interfaces:**
- Consumes: `AnnouncementPublishRequested`, states `AnnouncementPublished`, `AnnouncementKycRequired`, `AnnouncementDepartureDatePassed`, `AnnouncementProLimitReached` (Task 2). Bannière : `DonyStatusBanner` (`lib/core/design/widgets/dony_status_banner.dart`).

- [ ] **Step 1: Tests qui échouent**

`trip_owner_detail_draft_test.dart` — widget tests (harnais du pattern existant, repo mocké renvoyant une annonce `status: 'DRAFT'`) :

```dart
testWidgets('affiche la bannière brouillon et le bouton Publier pour un DRAFT', (tester) async {
  // pump TripOwnerDetailScreen avec detail DRAFT
  expect(find.textContaining('brouillon'), findsWidgets); // bannière
  expect(find.text('Publier'), findsOneWidget);           // tuile action
});

testWidgets('pas de bannière ni de bouton Publier pour un trajet ACTIVE', (tester) async {
  expect(find.text('Publier'), findsNothing);
});

testWidgets('taper Publier dispatch AnnouncementPublishRequested', (tester) async {
  // tap sur Publier → verify(() => bloc/repo publishAnnouncement) selon le harnais choisi
});
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/presentation/trip_owner_detail_draft_test.dart`
Expected: FAIL — bannière/tuile inexistantes.

- [ ] **Step 3: Implémentation minimale**

`trip_owner_detail_screen.dart` :
- Dans `_buildContent`, en tête de la `Column` (avant `AnnouncementDetailBody`) :

```dart
if (a.status == 'DRAFT')
  DonyStatusBanner(
    type: /* variante warning du widget */,
    title: 'Ce trajet est un brouillon',
    message: 'Il est invisible pour les expéditeurs tant qu\'il n\'est pas publié.',
  ),
```

- Listener bloc de l'écran (là où les autres states sont traités) :

```dart
if (state is AnnouncementPublished) {
  // snackbar succès « Trajet publié ! » (pattern snackbar du fichier)
  // puis recharger : context.read<AnnouncementBloc>().add(AnnouncementDetailRequested(id));
} else if (state is AnnouncementKycRequired) {
  // ErrorPresenter/snackbar + navigation : context.push('/kyc/status')
} else if (state is AnnouncementDepartureDatePassed) {
  // snackbar + ouvrir l'édition : context.push('/trips/create', extra: CreateTripArgs(announcement: a))
} else if (state is AnnouncementProLimitReached) {
  // réutiliser le pattern upsell existant (/profile/upgrade-to-pro)
}
```

(Adapter à la structure réelle du listener de l'écran — certains states sont peut-être déjà routés dans un `BlocListener` global.)

`owner_action_grid.dart` :
- Gating : `canEdit` doit inclure DRAFT (`(status == 'ACTIVE' || status == 'DRAFT') && bidsCount == 0`) — un brouillon est modifiable ; vérifier que la suppression est disponible pour un DRAFT (le backend l'autorise).
- Tuile « Publier » (icône envoi/upload du set d'icônes du fichier), visible seulement si `status == 'DRAFT'`, en première position :

```dart
if (a.status == 'DRAFT')
  _ActionTile(
    label: 'Publier',
    iconAsset: /* icône cohérente avec le set du fichier */,
    onTap: () => context.read<AnnouncementBloc>().add(AnnouncementPublishRequested(a.id)),
  ),
```

(Adapter `_ActionTile` au widget réel de la grille.)

`announcement_detail_body.dart` — branche `'DRAFT'` → « Brouillon » dans `_StatusBadge` (l.267-280), ton neutre/ambre cohérent avec la carte.

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/matching/`
Expected: PASS, zéro régression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/ test/features/matching/presentation/
git commit -m "feat(matching): bannière brouillon, action Publier et routage des erreurs au détail"
```

---

### Task 6: Analyse, suite complète, PR

- [ ] **Step 1: Analyse statique**

Run: `flutter analyze`
Expected: 0 issue (ou uniquement des infos préexistantes — ne pas introduire de nouveau warning).

- [ ] **Step 2: Suite complète**

Run: `flutter test`
Expected: 0 failure.

- [ ] **Step 3: Couverture**

Run: `flutter test --coverage`
Vérifier la couverture des fichiers touchés (≥ 90 % lignes sur les fichiers modifiés — `grep`/`lcov` sur `coverage/lcov.info`).

- [ ] **Step 4: Push + PR**

```bash
git push -u origin feature/trip-draft-status
gh pr create --title "feat(matching): statut DRAFT (brouillon) pour les trajets" --body "..."
```

Corps de PR : résumé, lien spec (`dony-pro/docs/.../2026-07-11-trip-draft-status-design.md`), liens PRs back (#95) et web (dony-pro#8), résultats tests + couverture.
