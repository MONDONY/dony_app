# Classement des annonces (app Flutter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Afficher dans la recherche de trajets le bloc « Autres annonces sur ce trajet » avec la raison de chaque écart, envoyer le tri par score, et retirer l'affichage des incidents expéditeur.

**Architecture:** Le back (MONDONY/yadony-back#634) ajoute `similarAnnouncements` à `GET /announcements`. L'app le lit dans `AnnouncementSearchPage`, le porte dans `AnnouncementSearchLoaded`, et `home_screen.dart` le rend sous la liste exacte via un widget dédié. Un formateur traduit chaque code d'écart en phrase localisée. Le champ `senderIncidentCount` et son libellé disparaissent.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, Dio, json_serializable (+ build_runner), ARB (`flutter gen-l10n`), mocktail + bloc_test.

**Spec:** back `dony-back/docs/superpowers/specs/2026-10-21-classement-annonces-design.md` (§ Objectifs 1 à 5, Décisions du propriétaire). Contrat : description de MONDONY/yadony-back#634.

## Global Constraints

- Contrat back (#634), tout est additif :
  - `GET /announcements` renvoie en plus `similarAnnouncements: [{announcement: <même objet que content[]>, unmet: [{code, requested, actual}]}]`. Absent du JSON quand vide, présent seulement sur la page 0 d'une page de taille supérieure à 1, avec au moins une ville, et moins de 7 trajets réservables exacts. Jamais plus de 20.
  - Codes `unmet.code` : `DATE`, `AVAILABLE_KG` (minimum), `MAX_AVAILABLE_KG` (maximum), `TRANSPORT_MODE`, `MIN_RATING`, `CONTENT_TYPE`, `RADIUS`, `WEEKEND_ONLY`, `URGENT`, `KILO_PRO_ONLY`. Dates en ISO `yyyy-MM-dd`, kilos en décimaux sans zéros finaux. `RADIUS` et `KILO_PRO_ONLY` ont `requested` et `actual` vides ; `WEEKEND_ONLY` a `requested` vide et `actual` = jour en anglais majuscules (`THURSDAY`).
  - `sortBy` accepte `score` (défaut serveur), `date`, `price`. Un back antérieur traite une valeur inconnue comme `date`.
  - `senderIncidentCount` (profil public, bids, demandes) et `incidentCount` (profil expéditeur de la recherche de colis) ne sont plus servis. `reliabilityPercent` reste servi et reste affiché : ne pas y toucher.
- Un back antérieur (sans `similarAnnouncements`, avec `senderIncidentCount`) ne casse aucun parcours : tout nouveau champ est lu avec une valeur par défaut, un code inconnu a un libellé de repli.
- Copie : « Yadony » (jamais « Dony » visible), vouvoiement, pas de tiret cadratin dans les textes, `context.l10n` partout (garde-fou `tool/check_hardcoded_strings.dart` à 0). Après toute clé ARB : `flutter gen-l10n` puis `dart run tool/gen_l10n_catalog.dart`.
- Règles projet : pas de `setState` (BLoC), GoRouter seulement, aucun dégradé, `DonyButton` jamais dans le `child` d'un bottom sheet. UI : appliquer `~/.agents/skills/make-interfaces-feel-better/SKILL.md`.
- Un seul `flutter test` / `flutter analyze` à la fois. Couverture globale ≥ 90 % ; chaque fichier nouveau ou touché a ses tests. Pas de build IPA/AAB sans accord explicite.
- Branche et worktree dédiés (`dony_app-worktrees/classement-annonces`, `feature/classement-annonces`), jamais sur `main`, pas de `Co-Authored-By`.

## Review Focus

- Réponse sans `similarAnnouncements` (back antérieur) : liste exacte seule, aucun bloc, aucun crash.
- Code d'écart inconnu ou `requested`/`actual` vides : phrase de repli lisible, jamais de chaîne brute ni de `null` affichés.
- Charger la page suivante conserve le bloc 2 déjà reçu (le back ne le renvoie qu'en page 0) et ne le duplique pas.
- Zéro trajet exact et bloc 2 non vide : pas l'état vide pleine page qui dit « aucun résultat » ; le bloc 2 est visible.
- Un trajet présent dans les deux listes n'apparaît qu'une fois (dédoublonnage par `id`, l'exact gagne).
- Le compteur « N trajets » (page 0, taille 1) continue de lire `totalElements`/`bookableElements` et n'affiche jamais le bloc 2.
- `SenderReliabilityLabel` retiré : plus aucune référence à `senderIncidentCount` / `incidentCount` ; le profil public garde `reliabilityPercent`.

---

### Task 1: Modèles `SimilarAnnouncement` et `UnmetCriterion`

**Files:**
- Create: `lib/features/matching/data/models/similar_announcement.dart`
- Modify: `lib/features/matching/data/models/announcement_search_page.dart`
- Test: `test/features/matching/data/models/similar_announcement_test.dart`, `test/features/matching/data/models/announcement_search_page_test.dart`

**Interfaces:**
- Produces: `class UnmetCriterion { final String code; final String requested; final String actual; factory UnmetCriterion.fromJson(Map<String, dynamic>) }` (valeurs absentes lues `''`) ; `class SimilarAnnouncement { final AnnouncementModel announcement; final List<UnmetCriterion> unmet; factory SimilarAnnouncement.fromJson(Map<String, dynamic>) }` ; `AnnouncementSearchPage.similar: List<SimilarAnnouncement>` (défaut `const []`, lu depuis `json['similarAnnouncements']`, entrées illisibles ignorées).

- [ ] **Step 1: Tests** : `parses_code_requested_actual`, `missing_requested_actual_default_to_empty`, `search_page_without_similar_key_is_empty`, `search_page_parses_similar_with_announcement_and_unmet`, `malformed_similar_entry_is_skipped`.
- [ ] **Step 2: Run** `flutter test test/features/matching/data/models/similar_announcement_test.dart test/features/matching/data/models/announcement_search_page_test.dart` → FAIL.
- [ ] **Step 3: Implement** les deux classes à la main (pas de json_serializable) et `similar` dans `AnnouncementSearchPage`.
- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(matching): modèles du bloc autres annonces`.

### Task 2: Bloc, état et tri par défaut

**Files:**
- Modify: `lib/features/matching/bloc/announcement_state.dart` (`AnnouncementSearchLoaded`), `lib/features/matching/bloc/announcement_bloc.dart` (`_onSearchRequested`, `_onSearchMoreRequested`), `lib/features/matching/bloc/announcement_event.dart` (`sortBy`), `lib/features/matching/data/repositories/announcement_repository.dart` et `announcement_remote_datasource.dart` (défauts `sortBy`)
- Test: `test/features/matching/bloc/announcement_bloc_test.dart`

**Interfaces:**
- Consumes: `AnnouncementSearchPage.similar` (Task 1).
- Produces: `AnnouncementSearchLoaded.similar: List<SimilarAnnouncement>` (paramètre nommé, défaut `const []`) ; `AnnouncementSearchRequested.sortBy` vaut `'score'` par défaut (commentaire : `score | date | price`) ; les défauts `sortBy` du repository et du datasource passent aussi à `'score'`. `countAnnouncements` n'envoie toujours pas `sortBy`.

- [ ] **Step 1: Tests** : `search_emits_similar_from_first_page`, `load_more_keeps_similar_from_first_page`, `load_more_does_not_duplicate_similar`, `similar_ids_already_in_results_are_dropped`, `default_sort_is_score` (le datasource reçoit `score`), `reload_keeps_previous_similar_while_reloading`.
- [ ] **Step 2: Run** `flutter test test/features/matching/bloc/announcement_bloc_test.dart` → FAIL.
- [ ] **Step 3: Implement** : `similar` dans l'état (reporté dans chaque `emit` de `AnnouncementSearchLoaded`, y compris `isLoadingMore` et `isReloading`) ; dédoublonnage par `id` en gardant l'exact.
- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(matching): bloc des autres annonces et tri par score`.

### Task 3: Libellés des écarts et textes ARB

**Files:**
- Create: `lib/features/matching/presentation/unmet_criterion_label.dart`
- Modify: `lib/l10n/app_fr.arb`, `lib/l10n/app_en.arb` (+ fichiers générés et catalogue)
- Test: `test/features/matching/presentation/unmet_criterion_label_test.dart`

**Interfaces:**
- Produces: `String unmetCriterionLabel(AppLocalizations l, UnmetCriterion c, {required String localeName})` ; clés ARB `similarTripsTitle` (« Autres annonces sur ce trajet »), `similarTripsSubtitle` (« Ces trajets ne correspondent pas exactement à vos critères. »), `similarTripsNoExactMatch` (« Aucun trajet ne correspond exactement à votre recherche. »), et une clé par code : `unmetDate(requested, actual)` « Départ le {actual} au lieu du {requested} », `unmetMinKg` « {actual} kg disponibles au lieu de {requested} », `unmetMaxKg` « {actual} kg disponibles, plus que les {requested} kg souhaités », `unmetTransport(requested, actual)`, `unmetMinRating(requested, actual)` « Note de {actual} au lieu de {requested} minimum », `unmetContentType(requested)` « N'accepte pas : {requested} », `unmetRadius` « Hors de la zone de retrait choisie », `unmetWeekend(actual)` « Départ un {actual} (pas un week-end) », `unmetUrgent` « Départ hors de la fenêtre urgente », `unmetGpPro` « Voyageur non GP Pro », `unmetGeneric` « Ne correspond pas à l'un de vos critères ». Équivalents anglais dans `app_en.arb`.

- [ ] **Step 1: Tests** : une assertion par code avec les valeurs du contrat (`DATE` requested `2026-11-10` actual `2026-11-12` → date localisée, jamais la chaîne ISO brute) ; `unknown_code_uses_generic` ; `empty_values_never_print_null_or_blank_placeholders` ; `weekend_maps_english_day_name_to_localized_day` (`THURSDAY` → « jeudi » en `fr`, « Thursday » en `en`) ; `unparseable_date_falls_back_to_raw_text_without_crash`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** le formateur (dates et jours via `intl` `DateFormat` avec la locale ; un `switch` sur `code`, `unmetGeneric` par défaut) et ajouter les clés, puis `flutter gen-l10n` et `dart run tool/gen_l10n_catalog.dart`.
- [ ] **Step 4: Run** le test + `dart run tool/check_hardcoded_strings.dart` → PASS. **Step 5: Commit** `feat(matching): libellés des critères non respectés`.

### Task 4: Affichage du bloc dans la recherche

**Files:**
- Create: `lib/features/matching/presentation/widgets/similar_trips_section.dart`
- Modify: `lib/features/matching/presentation/widgets/traveler_card.dart` (paramètre optionnel `unmetReasons`), `lib/features/home/presentation/home_screen.dart` (rendu trajets, ~lignes 2380 à 2540)
- Test: `test/features/matching/presentation/widgets/similar_trips_section_test.dart`, `test/features/matching/presentation/widgets/traveler_card_test.dart` (étendre)

**Interfaces:**
- Consumes: `AnnouncementSearchLoaded.similar` (Task 2), `unmetCriterionLabel` (Task 3).
- Produces: `TravelerCard.unmetReasons: List<String>` (défaut `const []`, une ligne d'avertissement par raison, couleur `cs.warning`, aucune ligne si vide) ; `SimilarTripsSection({required List<SimilarAnnouncement> items, required Widget Function(SimilarAnnouncement, int index) cardBuilder, bool showNoExactMatch})` : sliver avec titre `similarTripsTitle`, sous-titre `similarTripsSubtitle`, et, si `showNoExactMatch`, la ligne `similarTripsNoExactMatch` au-dessus ; rien du tout si `items` est vide.

- [ ] **Step 1: Tests** : `renders_title_subtitle_and_one_card_per_item` ; `empty_items_render_nothing` ; `card_shows_one_warning_line_per_reason` ; `no_exact_match_line_shown_only_when_flagged` ; test du home (ou d'un widget extrait) : `zero_exact_with_similar_shows_block_not_full_empty_state`, `exact_results_and_similar_show_block_below_list`, `block_hidden_for_parcels_mode`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** : dans le rendu trajets de `home_screen.dart`, quand `AnnouncementSearchLoaded.similar` n'est pas vide, ajouter `SimilarTripsSection` après la liste exacte avec les mêmes `TravelerCard` (mêmes actions `onTap`, favori, offre existante) ; si la liste exacte est vide et `similar` ne l'est pas, remplacer l'état vide pleine page par ce bloc avec `showNoExactMatch: true`. Extraire le constructeur de carte pour ne pas le dupliquer.
- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(home): bloc autres annonces sur ce trajet`.

### Task 5: Analytics du bloc

**Files:**
- Modify: `lib/core/services/analytics_events.dart`, `lib/features/matching/bloc/announcement_bloc.dart` (il reçoit déjà `AnalyticsService`), `CLAUDE.md` (ajouter une ligne `search_similar_shown` à la table « Events actuellement implémentés », obligation du projet)
- Test: `test/features/matching/bloc/announcement_bloc_test.dart`

**Interfaces:**
- Produces: `AnalyticsEvents.searchSimilarShown = 'search_similar_shown'`, envoyé une fois par recherche relancée (page 0) quand `similar` n'est pas vide, avec `{'similar_count': int, 'exact_count': int}` ; aucun envoi sur les pages suivantes ni pour le compteur.

- [ ] **Step 1: Tests** : `logs_once_when_similar_present`, `does_not_log_without_similar`, `does_not_log_on_load_more`. **Step 2: Run** → FAIL. **Step 3: Implement** avec le même `_analytics.logEvent` que `tripGroupCreated`. **Step 4: Run** → PASS. **Step 5: Commit** `feat(analytics): affichage du bloc autres annonces`.

### Task 6: Retrait de l'affichage des incidents expéditeur

**Files:**
- Delete: `lib/core/widgets/sender_reliability_label.dart` (et son test)
- Modify: `lib/features/matching/presentation/widgets/expediteur_card.dart`, `lib/features/matching/presentation/widgets/sender_profile_sheet.dart`, `lib/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart`, `lib/features/package_request/presentation/widgets/package_request_list_card.dart`, `lib/features/package_request/presentation/widgets/sender_public_profile_sheet.dart`, `lib/features/package_request/bloc/request_sender_cubit.dart` (+ état), `lib/features/matching/data/models/bid_model.dart` (+ `.g.dart`), `lib/features/package_request/data/models/package_request.dart`, `lib/features/package_request/data/models/package_request_search_item.dart`, `lib/features/profile/data/models/profile_public_model.dart`, `lib/l10n/app_fr.arb`, `lib/l10n/app_en.arb` (clés `senderReliabilityLabel`, `senderReliabilityTooltip`)
- Test: adapter chaque test qui lit `senderIncidentCount` / `incidentCount` ou cherche `Key('sender-reliability-label')` ; ne supprimer aucun test sans le remplacer par une assertion d'absence.

**Interfaces:**
- Produces: plus aucun champ `senderIncidentCount` / `incidentCount` dans les modèles ; `ProfilePublicModel.reliabilityPercent` et `ProfileReliabilityLabel` inchangés.

- [ ] **Step 1: Tests** : pour chaque écran ou fiche touchés, `does_not_render_sender_incident_label` (aucun widget avec la clé `sender-reliability-label`, même avec un JSON contenant encore `senderIncidentCount: 3`) ; pour les modèles, `ignores_legacy_sender_incident_count_in_json`.
- [ ] **Step 2: Run** `flutter test test/features/matching test/features/package_request test/features/profile` → FAIL.
- [ ] **Step 3: Implement** : retirer le widget, ses 6 usages, les champs et leurs lectures JSON, les clés ARB ; `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, `dart run tool/gen_l10n_catalog.dart`. Vérifier `git grep -n -i "senderIncidentCount\|incidentCount\|SenderReliabilityLabel\|senderReliability" -- lib test` : aucune ligne.
- [ ] **Step 4: Run** les mêmes tests → PASS. **Step 5: Commit** `feat(profile): retirer l'affichage des incidents expéditeur`.

### Task 7: Vérification finale et PR jumelle

- [ ] **Step 1:** `flutter analyze` à 0 problème ; `dart run tool/check_hardcoded_strings.dart` à 0 ; `flutter test --coverage` entièrement vert, couverture globale ≥ 90 % et chaque fichier de ce plan couvert.
- [ ] **Step 2:** `git diff origin/main...HEAD --stat` ne contient que les fichiers de ce plan (plus les fichiers générés).
- [ ] **Step 3:** Ouvrir la PR (titre `Classement des annonces : bloc autres annonces et tri par score`), description citant `MONDONY/yadony-back#634` et rappelant : fusion APRÈS #634, compatible avec l'ancien back, aucun build lancé. Après la fusion de #634 seulement, vérifier que #634 est déployée sur l'environnement visé avant tout build de recette ; la prod back ne part qu'avec le build app (les fiches de l'assistant décrivent déjà le bloc 2). Pas de build IPA/AAB sans accord explicite du propriétaire.
