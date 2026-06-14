# Phase 3 — Suivi (additif + ScanHub réel)

**Date :** 2026-06-09 | **Statut :** ✅ Design validé (brainstorming) — en attente du plan d'implémentation
**Fondation :** `2026-06-08-navigation-additive-model-foundation.md`

---

## Objectif & gain UX

Faire de l'onglet **Suivi** une surface **additive** et **in-shell**, calquée sur la Phase 2 :
- socle (tout le monde) = **suivre mes colis** ;
- ajout voyageur = **scanner mes trajets** ;
- présentation pilotée par le profil (`isProAccount`), sans switch.

Et surtout : **le ScanHub affiche un vrai trajet**, plus le placeholder codé en dur (`_TripStub`). Un voyageur sans trajet voit un **vrai état vide**, pas un faux « Paris → Dakar ».

## État actuel (pour mémoire)

- **Expéditeur** : l'onglet Suivi fait `context.push('/tracking/search')` → **hors-shell**, plein écran (`TrackingSearchScreen` : recherche DON-XXXXXX + timeline). Icône d'onglet `track_changes_rounded`.
- **Voyageur** : reste in-shell sur `/tracking` → `ScanHubScreen`, mais **placeholder** : `_TripStub` est **codé en dur** (`scan_hub_screen.dart:5-10`), aucun BLoC, aucun état vide. Icône d'onglet `qr_code_scanner_rounded`.
- File offline QR (NFR1) : `offline_sync_service.dart` (Hive + sync auto à la reconnexion).

Problèmes : switch (active_role), comportement de nav incohérent (hors-shell vs in-shell), et données de scan factices.

## Design cible — composition par profil

Principe identique à la Phase 2 (**un primaire + une entrée secondaire**, écrans réutilisés, widget `SecondaryActivityEntry` réutilisé).

| Profil | Signal | Primaire (Suivi) | Entrée secondaire |
|---|---|---|---|
| Pur expéditeur | `!isTraveler` | `TrackingSearchScreen` (suivre un colis) | **aucune** |
| Voyageur occasionnel | `isTraveler && !isProAccount` | `TrackingSearchScreen` (suivre un colis) | **« 📷 Scanner un trajet »** → `ScanHubScreen` |
| Voyageur pro | `isProAccount` | `ScanHubScreen` (Scan & Suivi) **réel** | **« 📦 Suivre un colis »** → `TrackingSearchScreen` |

- Fonction pure de décision `suiviLayoutFor({isTraveler, isPro})` → `senderOnly / occasionalTraveler / proTraveler` (cœur testable, analogue à `annoncesLayoutFor`).
- **Suivi toujours in-shell** : on supprime le `context.push('/tracking/search')` du bouton d'onglet. `/tracking/search` reste une **route** (destination poussée de l'entrée secondaire « Suivre un colis » + deep-link).
- **Bottom-nav** : onglet Suivi **label + icône figés** (fin de la dépendance `ActiveRoleCubit`). `main_shell.dart`.

## ScanHub réel (option B) — câblage aux vraies données

Remplacer `_TripStub` par un vrai chargement, **sans nouvel endpoint backend** (tout est atteignable via les BLoCs/repos existants).

### Sources de données
- **Trajet à scanner :** `AnnouncementRepository.getMyAnnouncements()` (via `AnnouncementBloc` / `AnnouncementListRequested`). Règle de sélection :
  > le trajet `IN_PROGRESS` s'il existe ; sinon le prochain trajet à venir (`ACTIVE`/`FULL`, par date de départ) ayant ≥1 colis `ACCEPTED` ; sinon → **aucun** (état vide).
- **Colis confirmés & progression :** `BidRepository.getBidsForAnnouncement(announcementId)` (via `BidBloc` / `BidListRequested`). On **dérive** tout du **statut des bids** (pas de requête tracking par colis, pas de N+1) :
  - confirmés = bids `ACCEPTED` / `HANDED_OVER` / `IN_TRANSIT` / `COMPLETED`
  - scannés au départ = bids `HANDED_OVER` / `IN_TRANSIT` / `COMPLETED`
  - (transit / arrivée idem selon le statut)
  > ⚠ Sémantique exacte du cycle de vie bid (`HANDED_OVER` = scanné au départ ?) **à confirmer** côté backend avant implémentation finale.

### Orchestration — `ScanHubCubit` (nouveau)
- Dépend de `AnnouncementRepository` + `BidRepository` (+ `AnalyticsService` injecté, règle projet).
- Charge mes trajets → sélectionne le trajet à scanner → charge ses bids → calcule `{trip, confirmedColis, scannedDepart, scannedTransit, scannedArrivee}`.
- États : `ScanHubLoading` / `ScanHubLoaded(trip, counts)` / `ScanHubEmpty` / `ScanHubError`.
- La **logique pure** (sélection du trajet + calcul des compteurs depuis les statuts) est extraite et **testée en TDD**.

### UI
- **Hero réel** : corridor + date + « X colis confirmés » + progression réelle (au lieu de `_TripStub`).
- **État vide réel** : « Aucun trajet à scanner — tu pourras scanner les colis dès qu'une demande sera acceptée sur l'un de tes trajets » + CTA « Voir mes trajets » (`/announcements/trips`).
- **On garde** les chips d'étape (DÉPART/TRANSIT/ARRIVÉE) et les actions « Scanner QR / Numéro » existantes — elles routent déjà vers le vrai flux (`/tracking/scan/identify`, `TrackingBloc`).
- **Multi-trajets** : si plusieurs `IN_PROGRESS`, afficher le plus proche par date (sélecteur = décision ouverte, hors v1).

### Préservé (zéro régression)
- Flux de scan complet (`/tracking/scan*`, `TrackingBloc`, `QrScanSubmitRequested`).
- **File offline QR** (`offline_sync_service.dart`, Hive, sync auto) — NFR1 intacte.
- `TrackingSearchScreen` (recherche + timeline) réutilisé tel quel.

## Cohérence avec le séquencement (fondation)

- Après Phase 3, **Suivi ne lit plus `active_role`** → Home, Annonces, Suivi tous migrés.
- Le **switch du Profil** ne pilote plus que le sous-onglet Activité du Profil ; il est **retiré en Phase 4** avec la suppression de `ActiveRoleCubit`.

## Cards & composants

- **Réutilisés tels quels :** `TrackingSearchScreen`, le flux `/tracking/scan*`, les chips d'étape et actions du ScanHub, `SecondaryActivityEntry` (créé en Phase 2).
- **Nouveau :** `ScanHubCubit` + ses états ; le **dispatcher Suivi** (composition par profil) ; le **vrai hero + état vide** du ScanHub.

## Périmètre

### Dans le scope (Phase 3)
- Dispatcher Suivi (composition par profil via `AuthBloc`), in-shell.
- Entrées secondaires (`SecondaryActivityEntry`) : « Scanner un trajet » (occasionnel) / « Suivre un colis » (pro).
- Bottom-nav Suivi figé + suppression du push hors-shell.
- **ScanHub câblé aux vraies données** (`ScanHubCubit`) : hero réel + état vide réel ; suppression de `_TripStub`.
- Analytics des entrées + maj `CLAUDE.md`. Tests + couverture ≥ 90 %.

### Hors scope
- Endpoint backend d'agrégat de scans (inutile : dérivé des statuts bids).
- Refonte du flux de scan lui-même (`/tracking/scan*`) — réutilisé.
- Liste détaillée des colis du trajet avec statut par colis (option/polish, pas v1).
- Sélecteur multi-trajets IN_PROGRESS (v1 = le plus proche).

## Inventaire zéro-régression (Suivi)

- **Pur expéditeur :** suivre un colis (DON-XXXXXX + timeline) → conservé, désormais **in-shell** (amélioration, pas régression).
- **Voyageur :** scan QR (étapes, photo, GPS), identification par numéro, **file offline** → tous conservés. Le ScanHub passe du **placeholder au réel** (le faux trajet disparaît).
- `TrackingSearchScreen`, flux de scan, offline sync : inchangés fonctionnellement.

## Fichiers touchés (prévisionnel)

| Fichier | Changement |
|---|---|
| `lib/features/tracking/presentation/suivi_layout.dart` | **Créé.** `SuiviLayout` + `suiviLayoutFor()` pur |
| `lib/features/tracking/presentation/screens/suivi_screen.dart` (ou dispatcher) | **Créé.** Composition par profil (primaire + entrée secondaire), in-shell |
| `lib/features/tracking/bloc/scan_hub_cubit.dart` (+ state) | **Créé.** Orchestration trajet+bids → compteurs ; logique pure testable |
| `lib/features/tracking/presentation/screens/scan_hub_screen.dart` | **Modifié.** Suppression `_TripStub` ; hero + état vide pilotés par `ScanHubCubit` ; chips/actions conservés |
| `lib/app/main_shell.dart` | **Modifié.** Onglet Suivi : icône figée, toujours `onTap(2)` (in-shell), fin du push `/tracking/search` |
| `lib/app/router.dart` | **Modifié.** Branche `/tracking` → nouveau dispatcher Suivi ; `/tracking/search` conservée comme route poussée |
| `lib/core/di/injection.dart` | **Modifié.** Enregistrer `ScanHubCubit` (+ `AnalyticsService`) |
| `lib/core/services/analytics_events.dart` | **Modifié.** Events des entrées (scan/track ouverts) |
| `CLAUDE.md` | **Modifié.** Table des events |

*(Affiné dans le plan d'implémentation.)*

## Analytics
- Events d'ouverture des activités secondaires (ex. `suivi_scan_opened`, `suivi_track_opened`), déclarés dans `AnalyticsEvents`, `unawaited`, sans PII.
- Events scan existants (`qrScanSuccess`, `deliveryConfirmed`) **préservés**.

## Tests
- `suiviLayoutFor()` : 3 profils (TDD unit).
- `ScanHubCubit` / logique pure : sélection du trajet à scanner (IN_PROGRESS > prochain avec colis acceptés > aucun) + calcul des compteurs depuis statuts bids (TDD unit avec repos mockés).
- ScanHub : rendu hero réel vs état vide selon l'état du cubit (widget test ciblé).
- `SecondaryActivityEntry` : déjà testé (Phase 2).
- Non-régression : suites tracking / offline existantes passent.
- Couverture ≥ 90 %.

## Cas limites
- **Aucun trajet à scanner :** état vide + CTA « Voir mes trajets ».
- **Trajet sans colis accepté :** état vide (rien à scanner) ou hero « 0 colis confirmé » — *décision ouverte* (préférence : état vide).
- **Plusieurs trajets IN_PROGRESS :** afficher le plus proche par date (sélecteur = hors v1).
- **Hors-ligne :** scan mis en file (Hive) ; le hero peut être indisponible si les trajets ne sont pas en cache — afficher un état dégradé sans bloquer la mise en file.
- **Perte du rôle voyageur :** Suivi redevient « suivre un colis » pur, aucune entrée scan.

## Décisions ouvertes (à confirmer)
- Sémantique exacte du cycle de vie des bids (`HANDED_OVER`/`IN_TRANSIT`/`COMPLETED` ↔ DÉPART/TRANSIT/ARRIVÉE) — **à valider backend** avant le calcul de progression.
- Trajet sans colis accepté : état vide vs hero « 0 colis ».
- Sélecteur multi-trajets (futur).
- Wording du label d'onglet figé + noms d'events.
