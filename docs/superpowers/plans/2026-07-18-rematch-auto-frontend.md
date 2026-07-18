# Rematch automatique — Plan d'implémentation FRONTEND (dony_app)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Câbler la chaîne expéditeur complète : notification `TRIP_CANCELLED` → écran alternatives self-fetching → envoi d'une nouvelle demande (+ CTA depuis l'envoi annulé, analytics `rematch_accepted`).

**Architecture:** Route paramétrée `/cancellations/:id/rematch` self-fetching via le `CancellationBloc` existant (`RematchSuggestionsRequested`/`RematchSuggestionsLoaded` déjà implémentés). Les deux tables de routing notifications gagnent le cas `TRIP_CANCELLED`+`cancellationId`. Le billet talon `_CancelledBlock` gagne un CTA sender basé sur les nouveaux champs `BidResponse.tripCancellationId`/`tripCancellationRematchStatus` (PR back rematch). Écran refondu sur `TravelerCard`.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, GetIt, mocktail.

## Global Constraints

- Repo : `/Users/aboubakardiakite/Desktop/dony/dony_app`. Branche : `feature/rematch-auto`.
- Textes état vide : « Aucun voyageur disponible dans les 72h — votre remboursement est traité ».
- Pas de setState nouveau hors conventions du fichier, pas de Navigator.push, pas de `Icons.local_shipping*`, couleurs theme-aware.
- Analytics : event déjà déclaré `AnalyticsEvents.rematchAccepted` (`analytics_events.dart:75`) — à tirer au tap « Envoyer une demande », précédent widget-level = `trip_parcels_filtered` (TripParcelsSection). Aucune PII. Mettre à jour la table events de `CLAUDE.md` (retirer « à implémenter »).
- `flutter analyze` : 0 issue nouvelle. `flutter test` vert. Couverture des nouveaux blocs/écrans. Jamais commit sur `main`, jamais de Co-Authored-By.

---

### Task F1: Modèles + route self-fetching

**Files:**
- Modify: `lib/features/cancellation/data/models/cancellation_model.dart` (RematchSuggestionModel : +3 champs nullable)
- Modify: `lib/app/router.dart:354-361` (route `/cancellations/rematch`)
- Modify: `lib/features/cancellation/presentation/screens/rematch_search_screen.dart`
- Test: `test/features/cancellation/data/models/cancellation_model_test.dart`, `test/features/cancellation/presentation/screens/rematch_search_screen_test.dart` (créer si absent)

**Interfaces:**
- Consumes: `CancellationBloc` existant (`RematchSuggestionsRequested(cancellationId)` → `RematchSuggestionsLoaded(List<RematchSuggestionModel>)`), `CancellationError`.
- Produces: route `/cancellations/:id/rematch` (id = cancellationId UUID) ; `RematchSuggestionModel.{travelerFirstName, travelerRating, travelerRatingCount}` nullable (fromJson tolère l'absence — back pas encore déployé).

- [ ] **Step 1: Test modèle (échoue)** — `RematchSuggestionModel.fromJson` avec et sans `travelerFirstName`/`travelerRating`/`travelerRatingCount` (null tolérés).

- [ ] **Step 2: Implémenter les 3 champs nullable** (`String? travelerFirstName`, `double? travelerRating`, `int? travelerRatingCount`) + fromJson (`(json['travelerRating'] as num?)?.toDouble()`).

- [ ] **Step 3: Route paramétrée**

Remplacer la route existante :

```dart
GoRoute(
  path: '/cancellations/:id/rematch',
  builder: (context, state) {
    final cancellationId = state.pathParameters['id']!;
    final cancellation = state.extra as CancellationModel?;
    return BlocProvider(
      create: (_) => getIt<CancellationBloc>(),
      child: RematchSearchScreen(
        cancellationId: cancellationId,
        cancellation: cancellation,
      ),
    );
  },
),
```

ATTENTION : chercher les appelants existants de `'/cancellations/rematch'` (grep) — l'écran voyageur post-annulation (`cancellation_screen.dart`/`cancellation_bottom_sheet.dart`) n'y navigue PAS aujourd'hui (le voyageur retourne à `/announcements`), mais vérifier et adapter tout `context.push('/cancellations/rematch', ...)` trouvé vers la nouvelle forme avec id. La `CancellationResponse` back n'expose pas de cancellationId global (une par bid) — si un appelant voyageur existe, lui garder un comportement raisonnable (extra-only n'est plus possible : router exige un id ; utiliser l'announcementId n'est PAS valide — dans le doute, supprimer la navigation voyageur, conforme au commentaire existant du code).

- [ ] **Step 4: Écran self-fetching (échoue puis passe)**

`RematchSearchScreen` devient StatefulWidget : `cancellationId` requis, `cancellation` optionnel. `initState` : si `cancellation == null` → `context.read<CancellationBloc>().add(RematchSuggestionsRequested(cancellationId))`. `build` : si `cancellation != null` → rendu direct actuel (chemin interne) ; sinon `BlocBuilder<CancellationBloc, CancellationState>` : `CancellationLoading` → loader centré ; `RematchSuggestionsLoaded` → même corps (bannière générique « Votre remboursement est en cours » sans compteur — `affectedBidsCount` inconnu dans ce chemin) ; `CancellationError` → état erreur standard avec retry.

Tests widget : fetch déclenché avec le bon id ; loader ; liste rendue sur Loaded ; erreur avec retry.

- [ ] **Step 5: Vérifier + commit**

Run: `flutter test test/features/cancellation/ && flutter analyze`
Expected: PASS, 0 issue nouvelle.

```bash
git add lib/ test/
git commit -m "feat(cancellation): écran rematch self-fetching sur route paramétrée"
```

---

### Task F2: Deep links notification

**Files:**
- Modify: `lib/features/notifications/data/notification_service.dart:270-272` (`_routeForMessage`)
- Modify: `lib/features/notifications/presentation/notification_bottom_sheet.dart:14-33` (`routeForNotification`)
- Test: tests existants de ces deux tables (chercher `_routeForMessage`/`routeForNotification` dans test/) — ajouter les cas.

**Interfaces:**
- Consumes: payload back `data = {type: TRIP_CANCELLED, cancellationId}` (PR back rematch) ; `_isUuid` existant.

- [ ] **Step 1: Tests (échouent)** — `TRIP_CANCELLED` + `cancellationId` UUID valide → `/cancellations/<id>/rematch` ; sans `cancellationId` → `null` ; `cancellationId` non-UUID → `null` (anti path-traversal, comme les autres cas).

- [ ] **Step 2: Implémenter**

`notification_service.dart` — remplacer la ligne `'TRIP_CANCELLED' => null,` :

```dart
      // Trajet annulé → alternatives rematch si le back en a trouvé
      'TRIP_CANCELLED' when _isUuid(data['cancellationId'] as String?) =>
          '/cancellations/${data['cancellationId']}/rematch',
      'TRIP_CANCELLED'                           => null,
```

`notification_bottom_sheet.dart` — ajouter dans le switch (extraire `final cancellationId = n.data['cancellationId'] as String?;` en tête) :

```dart
    'TRIP_CANCELLED' when cancellationId != null => '/cancellations/$cancellationId/rematch',
```

- [ ] **Step 3: Vérifier + commit**

Run: `flutter test test/features/notifications/ && flutter analyze`

```bash
git add lib/features/notifications/ test/features/notifications/
git commit -m "feat(notifications): deep link TRIP_CANCELLED vers l'écran des alternatives"
```

---

### Task F3: Champs BidModel + CTA sur l'envoi annulé

**Files:**
- Modify: `lib/features/matching/data/models/bid_model.dart` (+2 champs nullable + fromJson)
- Modify: `lib/features/matching/presentation/widgets/billet/billet_talon.dart:107-145` (`_CancelledBlock`)
- Test: `test/features/matching/data/models/bid_model_test.dart` (ou fichier réel), tests billet_talon existants.

**Interfaces:**
- Consumes: `BidResponse.tripCancellationId`/`tripCancellationRematchStatus` (PR back), route F1.
- Produces: `BidModel.tripCancellationId` (String?), `BidModel.tripCancellationRematchStatus` (String?).

- [ ] **Step 1: Tests modèle (échouent)** — fromJson avec/sans les 2 champs.

- [ ] **Step 2: Ajouter les champs à BidModel** (nullable, fromJson tolérant, même style que `cancellationNoShowStatus` ligne ~105/202).

- [ ] **Step 3: CTA dans _CancelledBlock (échoue puis passe)**

Dans la branche terminale (`!isParcelReturned && !isAwaitingReturn`), remplacer `return const _TerminalBlock();` par :

```dart
    if (isSender &&
        bid.tripCancellationId != null &&
        bid.tripCancellationRematchStatus == 'SUGGESTED') {
      final cs = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TerminalBlock(),
          const SizedBox(height: DonySpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/cancellations/${bid.tripCancellationId}/rematch'),
            icon: DonyIcon('route', size: 20, color: cs.primary),
            label: const Text('Voir les trajets alternatifs',
                textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary),
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
            ),
          ),
        ],
      );
    }
    return const _TerminalBlock();
```

(Icône : vérifier que `'route'` existe dans DonyIcon ; sinon prendre une icône existante cohérente — `'plane'`/`'search'` — jamais local_shipping.) Tests widget : CTA visible sender+SUGGESTED ; absent voyageur ; absent si rematchStatus null ; absent si flux retour (isAwaitingReturn).

- [ ] **Step 4: Vérifier + commit**

Run: `flutter test test/features/matching/ && flutter analyze`

```bash
git add lib/features/matching/ test/features/matching/
git commit -m "feat(matching): CTA trajets alternatifs sur l'envoi annulé"
```

---

### Task F4: Écran alternatives sur TravelerCard + analytics + état vide conforme

**Files:**
- Modify: `lib/features/cancellation/presentation/screens/rematch_search_screen.dart`
- Modify: `CLAUDE.md` (table events : `rematch_accepted` — retirer « à implémenter »)
- Test: `test/features/cancellation/presentation/screens/rematch_search_screen_test.dart`

**Interfaces:**
- Consumes: `TravelerCard` (`lib/features/matching/presentation/widgets/traveler_card.dart`, prend un `AnnouncementModel`), mapping partiel `RematchSuggestionModel → AnnouncementModel` déjà présent dans `_SuggestionCard` (~lignes 184-199) pour le push vers le flux bid, `AnalyticsEvents.rematchAccepted`, `getIt<AnalyticsService>`.

- [ ] **Step 1: Tests (échouent)** — l'écran rend des `TravelerCard` (find.byType) ; note voyageur affichée quand `travelerRating` non null ; état vide = texte exact « Aucun voyageur disponible dans les 72h — votre remboursement est traité » ; tap « Envoyer une demande » → `logEvent(AnalyticsEvents.rematchAccepted, properties: {'count': N})` vérifié via `MockAnalyticsService`.

- [ ] **Step 2: Refondre le corps de l'écran**

- Remplacer `_SuggestionCard` par `TravelerCard` : étendre le mapping `RematchSuggestionModel → AnnouncementModel` existant (mêmes champs que l'actuel push + `travelerFirstName`/`travelerRating` désormais disponibles — regarder les champs REQUIS de `AnnouncementModel` et garder les mêmes valeurs par défaut que le mapping actuel pour ceux que la suggestion n'a pas). `onTap` de la carte = l'actuel `context.push('/search/{announcementId}/bid', extra: <AnnouncementModel mappé>)`.
- Avant le push, tirer l'event :

```dart
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.rematchAccepted,
  properties: {'count': suggestions.length},
));
```

(précédent widget-level : TripParcelsSection — copier son mécanisme d'injection exact.)
- État vide : `DonyEmptyState` avec le texte exact de la spec (remplacer la description actuelle « Aucun voyageur alternatif disponible dans les 72h sur ce corridor. »).
- Mettre à jour la ligne CLAUDE.md : `| rematch_accepted | RematchSearchScreen — tap « Envoyer une demande » sur une alternative (propriété count) |`.

- [ ] **Step 3: Vérifier + commit**

Run: `flutter test test/features/cancellation/ && flutter analyze`

```bash
git add lib/ test/ CLAUDE.md
git commit -m "feat(cancellation): écran alternatives sur TravelerCard + analytics rematch_accepted"
```

---

### Task F5: Vérification globale + push + PR

- [ ] **Step 1: Suite complète + analyze**

Run: `flutter test` puis `flutter analyze`
Expected: tout vert, 0 issue nouvelle.

- [ ] **Step 2: Push + PR draft**

```bash
git push -u origin feature/rematch-auto
gh pr create --draft --title "feat: rematch — alternatives proposées à l'expéditeur après annulation" --body "Pendant back : dony-back PR rematch. Route /cancellations/:id/rematch self-fetching, deep links TRIP_CANCELLED (2 tables), CTA sur l'envoi annulé (BidResponse.tripCancellationId), écran refondu sur TravelerCard, analytics rematch_accepted."
```

## Self-review effectué

- Spec §4.1–4.5 couverts : F1 (route+fetch), F2 (deep links), F3 (CTA), F4 (écran+analytics+vide). ✓
- Textes exacts état vide = notification back (spec §2). ✓
- Types inter-tasks : route F1 consommée par F2/F3 sous la même forme `/cancellations/{id}/rematch`. ✓
- Le CTA « Voir d'autres trajets » depuis l'état vide (spec §4.4 nice-to-have) est volontairement omis (YAGNI, retour = bouton existant « Retour à l'accueil »). ✓
