# Rematch bid-only (frontend) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Router la notification `BID_REJECTED` enrichie vers l'écran alternatives et afficher le CTA « Voir les trajets alternatifs » sur un bid REJETÉ éligible.

**Architecture:** Le back (PR #113) envoie `data = {type: BID_REJECTED, bidId, cancellationId}` quand des alternatives existent, et peuple `BidResponse.tripCancellationId`/`tripCancellationRematchStatus` aussi pour les bids annulés/refusés par le voyageur (reasons bid-only). Le front étend le routing des 2 tables + duplique le CTA existant du bloc CANCELLED sur le bloc REJECTED. Aucun changement de modèle ni d'écran.

**Tech Stack:** Flutter, BLoC, GoRouter. Repo `dony_app`, branche `feature/rematch-auto` (PR #158 existante).

**Spec :** `docs/superpowers/specs/2026-07-18-rematch-bid-only-design.md` §4

## Global Constraints

- `BID_REJECTED` + `cancellationId` UUID valide (`_isUuid`) → `/cancellations/{id}/rematch` ; sinon comportement ACTUEL (`/bids/{bidId}`) — dans LES DEUX tables de routing.
- CTA billet REJECTED : condition EXACTE `isSender && bid.tripCancellationId != null && bid.tripCancellationRematchStatus == 'SUGGESTED'`, même libellé/style/navigation que le CTA du bloc CANCELLED.
- BLoC only, GoRouter only, tokens theme-aware, fontSize ≥ 12, pas Icons.local_shipping*.
- `flutter analyze` sans issue nouvelle, `flutter test` vert. Jamais commit sur main. Pas de Co-Authored-By.

---

### Task 1: Routing notification BID_REJECTED enrichi (2 tables)

**Files:**
- Modify: `lib/features/notifications/data/notification_service.dart` (`_routeForMessage`, cas `'BID_REJECTED'` ~:250)
- Modify: `lib/features/notifications/presentation/notification_bottom_sheet.dart` (`routeForNotification`, cas `'BID_REJECTED'`)
- Test: `test/features/notifications/data/notification_service_test.dart` + le fichier de test existant de la bottom sheet (même dossier que pour TRIP_CANCELLED en F2 rematch)

**Interfaces:**
- Consumes: garde `_isUuid` existante dans chaque fichier (F2 rematch) ; payload back `{type: BID_REJECTED, bidId, cancellationId?}`.

- [ ] **Step 1: Tests qui échouent** — dans chacun des 2 fichiers de test, groupe BID_REJECTED (calquer le groupe TRIP_CANCELLED existant) :

```dart
// cancellationId UUID valide → '/cancellations/<id>/rematch'
// cancellationId absent → '/bids/<bidId>' (comportement actuel préservé)
// cancellationId non-UUID ('../../evil') → '/bids/<bidId>' (fallback actuel, PAS null)
// cancellationId valide mais bidId absent → '/cancellations/<id>/rematch' (le rematch ne dépend pas de bidId)
```

- [ ] **Step 2: Run FAIL** — `flutter test test/features/notifications/`.

- [ ] **Step 3: Implémenter** — dans les 2 tables, remplacer le cas `'BID_REJECTED'` :

```dart
'BID_REJECTED' => switch (data['cancellationId'] as String?) {
      final id? when _isUuid(id) => '/cancellations/$id/rematch',
      _ => data['bidId'] != null ? '/bids/${data['bidId']}' : null,
    },
```

(Adapter à la syntaxe réelle du switch de chaque fichier — reproduire la forme du cas TRIP_CANCELLED voisin ; conserver exactement le fallback bidId actuel du fichier.)

- [ ] **Step 4: Run vert** — `flutter test test/features/notifications/` → PASS.

- [ ] **Step 5: Commit** — `feat(notifications): deep link rematch sur BID_REJECTED enrichi`

---

### Task 2: CTA « Voir les trajets alternatifs » sur bid REJECTED

**Files:**
- Modify: `lib/features/matching/presentation/widgets/billet/billet_talon.dart` (bloc du statut REJECTED — repérer le dispatcher de statut dans `BilletTalon.build` ~:58-97 ; le CTA CANCELLED existant est dans `_CancelledBlock` ~:107-151, à reproduire)
- Test: `test/features/matching/presentation/widgets/billet/billet_talon_test.dart`

**Interfaces:**
- Consumes: `bid.tripCancellationId` + `bid.tripCancellationRematchStatus` (déjà dans BidModel — AUCUN changement de modèle) ; route `/cancellations/:id/rematch` (existante).

- [ ] **Step 1: Repérer le bloc REJECTED** — lire `BilletTalon.build` : identifier le widget rendu pour `status == 'REJECTED'` côté sender. S'il n'existe pas de bloc dédié (fallthrough vers un bloc générique), ajouter le CTA dans ce bloc générique gardé par `status == 'REJECTED'` — ne PAS créer de nouveau bloc si un existant convient.

- [ ] **Step 2: Tests qui échouent** (calquer les 7 tests du CTA CANCELLED existants) :

```dart
// sender + REJECTED + tripCancellationId + SUGGESTED → CTA visible
// voyageur (isSender false) → absent
// tripCancellationId null (+SUGGESTED) → absent   // clause 2 isolée
// rematchStatus null → absent
// rematchStatus 'EXHAUSTED' → absent
// sender + CANCELLED (bloc existant) → toujours visible (non-régression)
```

- [ ] **Step 3: Run FAIL** — `flutter test test/features/matching/presentation/widgets/billet/billet_talon_test.dart`.

- [ ] **Step 4: Implémenter** — même widget bouton que le CTA CANCELLED (`OutlinedButton.icon` + `DonyIcon('route')` + `context.push('/cancellations/${bid.tripCancellationId}/rematch')`), même condition 3 clauses. Factoriser le bouton en widget privé partagé (`_RematchCta`) utilisé par les deux blocs plutôt que dupliquer.

- [ ] **Step 5: Run vert** — même commande → PASS (nouveaux + 31 existants).

- [ ] **Step 6: Commit** — `feat(matching): CTA trajets alternatifs sur bid refusé/annulé par le voyageur`

---

### Task 3: Vérification globale + push

- [ ] **Step 1:** `flutter analyze` sur les fichiers touchés — 0 issue nouvelle.
- [ ] **Step 2:** `flutter test` — suite complète, 0 échec (foreground, attendre la fin).
- [ ] **Step 3:** `git push` (PR #158 existante — pas de nouvelle PR). Mettre à jour la description de la PR #158 (section « Extension bid-only ») via `gh pr edit 158 --body ...`.

## Self-review

- Spec §4 : routing (T1), CTA REJECTED (T2), écran inchangé ✓, modèle inchangé ✓.
- Types inter-tasks : aucun nouveau type ; T2 dépend uniquement de champs BidModel existants.
- Fallback routing : le cas `BID_REJECTED` sans cancellationId conserve LE comportement actuel du fichier (route `/bids/{id}`) — vérifié en Step 3 T1 (« conserver exactement le fallback actuel »).
- Marche dégradée sans back : payload sans cancellationId → route bid actuelle ; champs BidResponse absents → CTA jamais affiché.
