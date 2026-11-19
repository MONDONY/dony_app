# Cartes trajet : j'aime, partage et favori — Plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS : utiliser superpowers:subagent-driven-development (recommandé) ou superpowers:executing-plans pour exécuter ce plan tâche par tâche. Les étapes utilisent des cases `- [ ]`.

**Objectif :** ajouter sous chaque carte trajet une ligne d'icônes (♡ j'aime public avec compteur, partage en flèche courbe, favori), et faire monter les trajets aimés dans le classement de la recherche.

**Architecture :** back d'abord (table `trip_likes`, routes `PUT`/`DELETE /announcements/{id}/like`, `likeCount` et `likedByMe` dans les réponses de recherche et de favoris, nouveau poids `likes` dans le score), puis app (nouvelle feature `likes/`, ligne d'actions dans `TripCard`, icône de partage). Deux dépôts, deux PR jumelles.

**Tech :** Spring Boot 3.4 / Java 21 / PostgreSQL / Flyway ; Flutter, flutter_bloc, GetIt, GoRouter, ARB FR + EN.

**Spec :** `dony_app/docs/superpowers/specs/2026-11-20-cartes-jaime-partage-design.md` · maquettes : https://claude.ai/artifact/9JM4TtUDcejkva9YWZsaJs et https://claude.ai/artifact/F3vHoJp8G57zg2aRRqX4v5

## Contraintes globales

- Branche `feature/trip-likes` dans chaque dépôt, via worktree (`dony-back/.claude/worktrees/trip-likes`, `dony_app-worktrees/trip-likes`). Jamais sur `main`. Aucune ligne `Co-Authored-By`.
- PR jumelles : la PR app cite le numéro de la PR back et se fusionne après elle. L'app tolère l'ancien back : champs absents = `likeCount` 0, `likedByMe` false.
- Back : migration `V(n+1)`, ne jamais modifier une migration existante. Dernière sur `origin/main` au 20/11 : V388. **Avant d'écrire la migration, vérifier qu'aucune PR ouverte ne prend déjà V389** (`gh pr list --json files`), sinon prendre le numéro suivant.
- Back : erreurs RFC 7807 via `GlobalExceptionHandler`, jamais de `String` ou `Map` brut. Un seul `./mvnw` à la fois.
- App : BLoC uniquement (jamais `setState`), GoRouter, textes par `context.l10n` en FR **et** EN, aucune couleur en dur (`DonyColors.primary`), aucun dégradé, zones de toucher ≥ 44 px (`kDonyMinTapTarget`). Un seul `flutter test` à la fois.
- Libellés de bouton : une ligne, taille normale. La ligne d'icônes n'a pas de libellé visible ; chaque bouton porte `tooltip` + `Semantics`.
- Analytics : noms dans `AnalyticsEvents`, tirés dans le BLoC avec `unawaited`, aucune PII ; table des événements de `dony_app/CLAUDE.md` mise à jour.
- Marque : « Yadony » dans tout texte visible, jamais « Dony ».
- Couverture ≥ 90 % sur le code ajouté, back et app. Tous les tests passent avant chaque commit.
- Valeurs de la spec : compteur masqué à 0 ; sélectionné = `DonyColors.primary` avec icône pleine ; partage bleu seulement pendant l'appui ; visiteur sans compte : favori inchangé, ♡ ouvre l'invitation à se connecter ; voyageur sur son trajet : compteur en lecture seule + partage, sans signet ni ♡ actif ; fiche du trajet : seule l'icône de partage change ; les vues restent privées.

## Revue ciblée

Entrées ou conditions que la spec implique sans que les tâches les testent d'office ; chacune a son test dans la tâche indiquée.

1. Double toucher rapide sur le ♡ : un seul j'aime en base, compteur +1 une fois (B2 test de concurrence ; A2 le cubit ignore un toggle pendant l'appel).
2. Échec réseau ou 422 : le compteur et l'icône reviennent à l'état d'avant, jamais de compteur négatif (A2).
3. Ancien back sans `likeCount` ni `likedByMe` : la carte s'affiche, compteur masqué, ♡ éteint (A1).
4. Aimer son propre trajet, ou un trajet annulé, terminé, brouillon ou retiré : refusé (B2).
5. Gonflage du classement : le bonus sature à 20 j'aime, et les j'aime d'un compte supprimé ne comptent pas (B3, B4).
6. Texte agrandi à 200 % et écran de 360 dp : la ligne d'icônes ne déborde pas (A3).

---

## Dépôt `dony-back`

### Task B1: table, entité et dépôt des j'aime

**Fichiers :**
- Créer : `src/main/resources/db/migration/V389__trip_likes.sql`
- Créer : `src/main/java/com/yadony/api/likes/TripLikeEntity.java`, `TripLikeRepository.java`
- Test : `src/test/java/com/yadony/api/likes/TripLikeRepositoryTest.java` (même montage que `favorites/FavoriteRepositoryTest`)

**Interfaces :**
- Produit : `TripLikeRepository`
  - `int insertIfAbsent(UUID id, UUID userId, UUID tripId)` : `ON CONFLICT DO NOTHING`, rend 1 ou 0
  - `int deleteActive(UUID userId, UUID tripId)`
  - `boolean existsByUserIdAndTripId(UUID userId, UUID tripId)`
  - `long countActive(UUID tripId)` et `List<Object[]> countByTripIds(Collection<UUID> ids)` (lignes `[tripId, count]`, sans les trajets à zéro). **Les deux ignorent les j'aime des comptes supprimés** (jointure sur `users.deleted_at IS NULL`).
  - `List<UUID> findLikedTripIds(UUID userId, Collection<UUID> ids)`

- [ ] **Étape 1 : écrire les tests du dépôt** : `insertIfAbsent_deux_fois_ne_cree_qu_une_ligne`, `deleteActive_est_idempotent`, `countByTripIds_ignore_les_comptes_supprimes`, `countByTripIds_omet_les_trajets_sans_j_aime`, `findLikedTripIds_ne_rend_que_ceux_du_lecteur`.
- [ ] **Étape 2 : lancer, constater l'échec** : `./mvnw test -Dtest=TripLikeRepositoryTest` → ÉCHEC (classes absentes).
- [ ] **Étape 3 : migration.** Table `trip_likes(id UUID PK, user_id UUID NOT NULL REFERENCES users(id), trip_id UUID NOT NULL REFERENCES announcements(id), created_at, updated_at, deleted_at TIMESTAMPTZ)`, index unique partiel `ux_trip_likes_active (user_id, trip_id) WHERE deleted_at IS NULL`, index `ix_trip_likes_trip (trip_id) WHERE deleted_at IS NULL`. Même forme que `V152__favorites.sql`.
- [ ] **Étape 4 : entité et dépôt.** `TripLikeEntity extends BaseEntity` (`@Where deleted_at IS NULL`), champs `userId`, `tripId`. Requêtes natives `@Modifying @Transactional` calquées sur `FavoriteRepository.insertIfAbsent` / `deleteActive` (suppression physique, précédent des favoris).
- [ ] **Étape 5 : relancer** → PASSE.
- [ ] **Étape 6 : commit** `feat(likes): table et dépôt des j'aime de trajet`.

### Task B2: routes et service pour aimer / ne plus aimer

**Fichiers :**
- Créer : `likes/TripLikeService.java`, `likes/TripLikeController.java`, `likes/dto/TripLikeResponse.java`
- Test : `src/test/java/com/yadony/api/likes/TripLikeServiceTest.java`, `TripLikeControllerTest.java` (montage de `FavoriteControllerTest`), `TripLikeConcurrencyIT.java` (montage de `FavoriteConcurrencyIT`, profil `e2e`)

**Interfaces :**
- Consomme : `TripLikeRepository` (B1), `AnnouncementRepository`, `AuditService`, `BlockVisibility`.
- Produit :
  - `record TripLikeResponse(long likeCount, boolean likedByMe)`
  - `TripLikeResponse TripLikeService.like(UUID userId, UUID tripId)`, `unlike(UUID userId, UUID tripId)` (idempotents)
  - `Map<UUID, Long> countsFor(Collection<UUID> tripIds)` et `Set<UUID> likedBy(UUID userId, Collection<UUID> tripIds)` (utilisés par B3 et B4)
  - `PUT` et `DELETE /announcements/{id}/like`, `@PreAuthorize("hasAnyRole('SENDER','TRAVELER')")` : un invité n'y accède pas, c'est voulu.

- [ ] **Étape 1 : tests du service** : `like_sur_son_propre_trajet_leve_422_trip-like-own-trip`, `like_sur_trajet_annule_termine_brouillon_ou_retire_leve_404`, `like_sur_trajet_d_un_voyageur_bloque_leve_404`, `like_deux_fois_reste_a_un` (`likeCount` = 1, `likedByMe` = true), `unlike_sans_like_est_sans_effet`, `like_ecrit_une_ligne_audit_TRIP_LIKE_ADDED_une_seule_fois`. Trajets acceptés : `ACTIVE` et `FULL`.
- [ ] **Étape 2 : tests du contrôleur** : 200 avec corps `{"likeCount":1,"likedByMe":true}` ; 403 pour un invité ; 401 sans jeton ; 422 `application/problem+json` sur son propre trajet.
- [ ] **Étape 3 : test de concurrence** `TripLikeConcurrencyIT` : 20 `like` simultanés du même utilisateur donnent une ligne et aucune erreur ; 20 utilisateurs différents donnent `likeCount` = 20.
- [ ] **Étape 4 : lancer, constater l'échec.**
- [ ] **Étape 5 : implémenter.** Ressource utilisateur résolue comme `FavoriteController.requireUserId`. Audit `TRIP_LIKE_ADDED` / `TRIP_LIKE_REMOVED` seulement si une ligne a changé (comme `auditFavorite`).
- [ ] **Étape 6 : relancer** les trois classes → PASSE.
- [ ] **Étape 7 : commit** `feat(likes): aimer et ne plus aimer un trajet`.

### Task B3: `likeCount` et `likedByMe` dans les réponses

**Fichiers :**
- Modifier : `matching/dto/AnnouncementSearchResponse.java`, `matching/AnnouncementService.java` (`mapAnnouncements`, vers la ligne 868), `favorites/FavoriteService.java` (`getFavoriteTrips`), `matching/dto/AnnouncementInsightsResponse.java`, `matching/AnnouncementViewService.java` (`getInsights`)
- Test : `matching/AnnouncementServiceLikesTest.java`, complément de `favorites/FavoriteServiceTest.java` et du test d'`AnnouncementViewService`

**Interfaces :**
- Consomme : `TripLikeService.countsFor` / `likedBy` (B2).
- Produit :
  - `AnnouncementSearchResponse` gagne **deux composants en fin de liste** : `long likeCount`, `boolean likedByMe`. Garder le constructeur à l'arité actuelle (comme « l'arité d'avant le bateau »), qui passe `0` et `false`. Les méthodes `withConvertedPrice` et `withUniqueViewerCount` reportent les deux valeurs ; ajouter `withLikes(long likeCount, boolean likedByMe)`.
  - `AnnouncementInsightsResponse(long uniqueViewerCount, long shareViewCount, long likeCount)` : lu par le seul voyageur, comme aujourd'hui.

- [ ] **Étape 1 : tests** : la recherche rend `likeCount` pour tout lecteur et `likedByMe` vrai seulement pour le lecteur qui a aimé ; un lecteur anonyme reçoit `likedByMe` faux ; `getFavoriteTrips` porte aussi les deux champs ; `insights` rend `likeCount` ; un seul appel groupé par page (vérifier avec `verify(tripLikeService, times(1)).countsFor(...)`, pas de N+1).
- [ ] **Étape 2 : lancer, constater l'échec.**
- [ ] **Étape 3 : implémenter.** Précédent d'injection entre packages : `AnnouncementService` injecte déjà `FavoriteRepository`. Un seul `countsFor` et un seul `likedBy` par page, dans `mapAnnouncements`, avant la boucle.
- [ ] **Étape 4 : relancer** → PASSE, plus `./mvnw test -Dtest='Announcement*Test,Favorite*Test'` pour la non-régression.
- [ ] **Étape 5 : commit** `feat(likes): compteur et état dans la recherche, les favoris et l'audience`.

### Task B4: les j'aime comptent dans le classement

**Fichiers :**
- Modifier : `matching/ranking/TripRankingProperties.java`, `matching/ranking/TripScoreCalculator.java`, `matching/AnnouncementService.java` (`rankingScores` ligne ~802, appels lignes ~635 et ~758), `src/main/resources/application.yml` (bloc `yadony.ranking.weights`)
- Test : `ranking/TripScoreCalculatorTest.java`, `ranking/TripRankingPropertiesTest.java`, `AnnouncementSearchRankingTest.java`

**Interfaces :**
- Produit :
  - `Weights` gagne `int likes` (défaut `10`, négatif refusé). Garder un constructeur à cinq arguments qui met `likes` à `0` pour les tests existants ; poser `@ConstructorBinding` sur le constructeur canonique pour la liaison Spring. Défaut de `TripRankingProperties` : `new Weights(30, 25, 20, 15, 10, 10)`.
  - `double TripScoreCalculator.score(TravelerQuality q, boolean onlinePayment, long daysToDeparture, long ageDays, long likeCount)`. L'ancienne signature reste et délègue avec `likeCount` = 0.
  - Terme des j'aime : `clamp(ln(1 + n) / ln(21))` (sature à 20 j'aime). `weightSum()` inclut `likes`.
  - `application.yml` : `likes: ${YADONY_RANKING_WEIGHT_LIKES:10}`.

- [ ] **Étape 1 : tests du calculateur** : `plus_de_likes_donne_un_meilleur_score_a_egalite`, `le_bonus_sature_a_20_likes` (score(20) = score(500)), `poids_likes_a_zero_desactive_le_critere`, `sans_like_l_ordre_relatif_est_celui_d_avant` (deux annonces à zéro j'aime gardent le même ordre qu'avec cinq poids), `poids_likes_negatif_refuse`.
- [ ] **Étape 2 : test de recherche** : à qualité de voyageur, fraîcheur et paiement égaux, le trajet avec 15 j'aime sort avant celui avec 0, trié par score ; l'id départage toujours. Les j'aime d'un compte supprimé ne le font pas monter.
- [ ] **Étape 3 : lancer, constater l'échec.**
- [ ] **Étape 4 : implémenter.** `rankingScores` reçoit un `Map<UUID, Long>` obtenu par **un seul** `tripLikeService.countsFor(ids)` sur les candidats (au plus `maxCandidates`).
- [ ] **Étape 5 : relancer** `./mvnw test -Dtest='TripScoreCalculatorTest,TripRankingPropertiesTest,AnnouncementSearchRankingTest,AnnouncementRankingProjectionIT'` → PASSE.
- [ ] **Étape 6 : commit** `feat(ranking): les j'aime de trajet pèsent dans le score`.

### Task B5: fiches de l'assistant, suite complète et PR

**Fichiers :**
- Modifier : fiches de `src/main/resources/assistant/kb/fr/` et `kb/en/` qui expliquent les favoris, le partage ou l'affiche du trajet (chercher `favori`, `affiche`, `poster`) : mentionner les j'aime, même `id` en FR et EN.

- [ ] **Étape 1 :** mettre à jour les fiches. Ne pas ajouter de route à la liste blanche : aucun nouvel écran.
- [ ] **Étape 2 :** `./mvnw test jacoco:report` → tous verts, couverture globale ≥ 90 %.
- [ ] **Étape 3 :** commit `docs(assistant): fiches mises à jour pour les j'aime`, push, PR back. Attendre la CI verte (relire `statusCheckRollup` en JSON, pas le tableau), fusionner, puis **déploiement staging avant de lancer l'app dessus**.

---

## Dépôt `dony_app`

### Task A1: modèles et réponse du serveur

**Fichiers :**
- Modifier : `lib/features/matching/data/models/announcement_model.dart` (champs près de `isFavorite`, ligne ~235 ; `fromJson`), `lib/features/matching/data/models/trip_audience_model.dart`
- Test : `test/features/matching/data/models/announcement_model_likes_test.dart`, `trip_audience_model_test.dart`

**Interfaces :**
- Produit : `AnnouncementModel.likeCount` (`int`, défaut 0), `AnnouncementModel.likedByMe` (`bool`, défaut false) ; `TripAudienceModel.likeCount` (`int`, défaut 0).

- [ ] **Étape 1 : tests** : `fromJson_lit_likeCount_et_likedByMe`, `fromJson_sans_ces_champs_donne_0_et_false` (ancien back), `TripAudienceModel_lit_likeCount_et_0_si_absent`, `props_incluent_likeCount`.
- [ ] **Étape 2 :** `flutter test test/features/matching/data/models` → ÉCHEC.
- [ ] **Étape 3 : implémenter** (`(json['likeCount'] as num?)?.toInt() ?? 0`).
- [ ] **Étape 4 :** relancer → PASSE. Commit `feat(likes): lire le compteur et l'état dans les modèles`.

### Task A2: feature `likes/` (données et cubit)

**Fichiers :**
- Créer : `lib/features/likes/data/models/trip_like_status.dart`, `data/datasources/trip_like_remote_datasource.dart`, `data/repositories/trip_like_repository.dart`, `bloc/trip_likes_cubit.dart`
- Modifier : `lib/core/di/injection.dart` (près de `FavoriteIdsCubit`, ligne ~2002), `lib/app/app.dart` (`BlocProvider<TripLikesCubit>.value` près de la ligne 500), `lib/core/services/analytics_events.dart`
- Test : `test/features/likes/trip_likes_cubit_test.dart`, `trip_like_repository_test.dart`, `trip_like_remote_datasource_test.dart`

**Interfaces :**
- Produit :
  - `class TripLikeStatus extends Equatable { final int likeCount; final bool likedByMe; }`
  - Datasource : `Future<TripLikeStatus> like(String tripId)` (`PUT /announcements/$tripId/like`), `unlike(String tripId)` (`DELETE`)
  - `class TripLikesState { final Map<String, TripLikeStatus> byTrip; }`
  - `TripLikesCubit(TripLikeRepository repo, AnalyticsService analytics)` :
    - `void seed(Iterable<AnnouncementModel> trips)` : fusionne les valeurs serveur sans écraser un trajet dont un appel est en cours
    - `TripLikeStatus statusOf(AnnouncementModel trip)` : l'état du cubit, sinon celui du modèle
    - `Future<void> toggle(AnnouncementModel trip)` : optimiste, ignoré si un appel est déjà en cours pour ce trajet, retour arrière puis `rethrow` en cas d'erreur
  - `AnalyticsEvents.tripLiked`, `tripUnliked`, `tripLikeFailed` (avec `error_code`, `unknown` sans code), `tripLikeLoginPrompted`, `tripCardShareTapped`

- [ ] **Étape 1 : tests du cubit** : `toggle_ajoute_un_et_passe_likedByMe`, `toggle_retire_un_et_ne_descend_jamais_sous_zero`, `toggle_pendant_un_appel_en_cours_est_ignore`, `echec_reseau_remet_l_etat_d_avant_et_relance_l_erreur`, `seed_ne_remplace_pas_un_trajet_en_cours_d_appel`, `statusOf_retombe_sur_le_modele`, `tripLiked_emis_une_fois_apres_succes_et_tripLikeFailed_avec_error_code_sinon`.
- [ ] **Étape 2 : tests de données** : la datasource appelle les bons chemins et lit le corps ; le dépôt délègue.
- [ ] **Étape 3 :** `flutter test test/features/likes` → ÉCHEC.
- [ ] **Étape 4 : implémenter.** Cubit enregistré `registerLazySingleton` comme `FavoriteIdsCubit`. Analytics via `unawaited(_analytics.logEvent(...))`.
- [ ] **Étape 5 :** relancer → PASSE. Commit `feat(likes): cubit et accès réseau des j'aime`.

### Task A3: ligne d'actions sous la carte

**Fichiers :**
- Créer : `lib/features/matching/presentation/widgets/trip_card_actions.dart`
- Modifier : `lib/features/matching/presentation/widgets/trip_card.dart` (`TripCard`, `_ActiveCardContent` ; retirer le signet de l'en-tête de la carte active), `lib/features/home/presentation/home_screen.dart` (ligne ~2524), `lib/features/home/presentation/map_traveler_view.dart` (ligne ~295), `lib/features/favorites/presentation/favorites_screen.dart` (lignes ~205 et ~272)
- Test : `test/features/matching/trip_card_actions_test.dart`

**Interfaces :**
- Consomme : `TripLikesCubit` (A2), `FavoriteIdsCubit`, `FirebaseSessionProbe.hasRealSession`, l'ouverture de l'affiche déjà utilisée par `_HeroWithFavorite.onShare` (`traveler_announcement_bottom_sheet.dart` ligne ~755, garde `canShareTripPoster`).
- Produit :
  - `class TripCardActions extends StatelessWidget { const TripCardActions({required AnnouncementModel announcement, required bool isOwn}); }`
  - `TripCard` gagne `bool showOwnLikes = false` ; `showFavorite` garde son sens (carte d'un autre voyageur). Les cartes passées (`_PastCardContent`) et « Mes trajets » ne changent pas.

**Comportement :** sous un filet comme les autres sections. À gauche ♡ + compteur (`Icons.favorite` / `favorite_border`) et partage ; à droite signet. Sélectionné : `DonyColors.primary`, icône pleine ; partage en primaire seulement appuyé. Compteur masqué à 0. Voyageur sur son trajet : compteur seul en lecture seule (visible dès 1) + partage, ni ♡ actif ni signet. Visiteur sans compte : le favori fonctionne, le ♡ appelle l'invitation à se connecter déjà employée par `GuestAccessGuard` (`lib/app/`) et émet `tripLikeLoginPrompted`. Partage masqué quand `canShareTripPoster` est faux. Une erreur de toggle montre `DonySnackbar` d'erreur comme `_buildFavoriteHeart`. Chaque bouton : `tooltip` + `Semantics`, cible 44 px.

- [ ] **Étape 1 : tests de widget** : `affiche_coeur_partage_et_signet_pour_un_autre_voyageur` ; `compteur_masque_a_zero_et_visible_a_partir_de_1` ; `toucher_le_coeur_passe_au_primaire_et_incremente` ; `toucher_le_signet_appelle_toggleTrip` ; `voyageur_sur_son_trajet_voit_le_compteur_sans_coeur_ni_signet` ; `visiteur_touchant_le_coeur_ouvre_l_invitation_et_ne_change_rien` ; `partage_absent_quand_canShareTripPoster_est_faux` ; **`aucun_debordement_a_360dp_et_texte_200_pourcent`** (`tester.takeException()` nul, hauteur de la ligne ≥ 44).
- [ ] **Étape 2 :** `flutter test test/features/matching/trip_card_actions_test.dart` → ÉCHEC.
- [ ] **Étape 3 : implémenter** le widget, brancher dans `_ActiveCardContent`, passer `showOwnLikes: isOwn` aux deux écrans de recherche, appeler `TripLikesCubit.seed(trips)` à la réception de chaque liste (recherche, favoris).
- [ ] **Étape 4 :** relancer ; puis `flutter test test/features/matching test/features/home test/features/favorites` pour la non-régression des cartes existantes.
- [ ] **Étape 5 :** commit `feat(likes): ligne j'aime, partage et favori sous la carte trajet`.

### Task A4: flèche courbe pour le partage du détail

**Fichiers :**
- Créer : `assets/icons/share-curved.svg` (Lucide `corner-up-right` : `<path d="m15 14 5-5-5-5"/><path d="M4 20v-7a4 4 0 0 1 4-4h12"/>`, même gabarit que `share-2.svg`)
- Modifier : `traveler_announcement_bottom_sheet.dart` (`_SharePosterButton`, ligne ~1051), `trip_owner_detail_screen.dart` (ligne ~292), l'icône de partage de `TripCardActions` (A3) ; déclaration de l'asset comme `share-2`
- Test : complément de `test/features/matching/.../traveler_announcement_bottom_sheet_test.dart` et du test de l'écran propriétaire

- [ ] **Étape 1 : tests** : le bouton `Key('trip-sheet-share-button')` porte `DonyIcon('share-curved')` ; l'en-tête du détail propriétaire aussi ; `share-2` reste utilisé ailleurs (suivi de colis, QR) et n'est pas touché.
- [ ] **Étape 2 :** lancer → ÉCHEC. **Étape 3 :** implémenter. **Étape 4 :** relancer → PASSE.
- [ ] **Étape 5 :** commit `feat(trajet): icône de partage en flèche courbe`.

### Task A5: j'aime dans l'audience du voyageur

**Fichiers :**
- Modifier : `trip_owner/trip_audience_line.dart` (`TripAudience.parts`)
- Test : `test/features/matching/trip_audience_line_test.dart`

**Interfaces :**
- Produit : `parts` ajoute en dernier `l.tripAudienceLikes(audience.likeCount)` quand `likeCount > 0`. Sous-titre de la tuile « Affiche » : premier morceau inchangé.

- [ ] **Étape 1 : tests** : « 128 personnes ont vu votre trajet · 24 j'aime » (FR) et l'équivalent EN ; à zéro j'aime la ligne est celle d'aujourd'hui ; `isEmpty` reste faux s'il n'y a que des j'aime.
- [ ] **Étape 2 :** lancer → ÉCHEC. **Étape 3 :** implémenter. **Étape 4 :** relancer → PASSE.
- [ ] **Étape 5 :** commit `feat(likes): j'aime dans l'audience du trajet`.

### Task A6: textes FR et EN, suivi analytics, documentation, PR

**Fichiers :**
- Modifier : `lib/l10n/app_fr.arb`, `lib/l10n/app_en.arb` (mêmes clés) ; `dony_app/CLAUDE.md` (table des événements) ; `AnalyticsEvents`

**Clés à créer** (FR / EN) : `tripLikeTooltip` « J'aime » / « Like » ; `tripUnlikeTooltip` « Je n'aime plus » / « Unlike » ; `tripLikeCountSemantics(count)` pluriel « {count} personnes aiment ce trajet » / « {count} people like this trip » ; `tripLikeLoginInviteTitle`, `tripLikeLoginInviteBody`, bouton court « Se connecter » / « Sign in » ; `tripAudienceLikes(count)` pluriel « {count} j'aime » / « {count} likes ». Réutiliser `tripPosterShareButton` pour le partage et `favoritesAddTooltip` / `favoritesRemoveTooltip` pour le signet.

- [ ] **Étape 1 :** ajouter les clés et régénérer (`flutter gen-l10n`). `dart run tool/check_hardcoded_strings.dart` → seuil 0.
- [ ] **Étape 2 :** ajouter à la table de `CLAUDE.md` une ligne par événement (`trip_liked`, `trip_unliked`, `trip_like_failed`, `trip_like_login_prompted`, `trip_card_share_tapped`), avec déclencheur et propriétés, sans PII.
- [ ] **Étape 3 :** `flutter analyze && flutter test --coverage` → tout vert, couverture ≥ 90 %.
- [ ] **Étape 4 :** commit `docs(likes): textes FR/EN et table des événements`, push, PR app qui **cite la PR back** ; ne fusionner qu'après la PR back fusionnée et déployée sur staging ; vérifier la ligne d'icônes sur un appareil réel (Redmi) et sur l'iPhone, en FR et en EN.

---

## Vérification finale (après les deux fusions)

- [ ] Sur staging : aimer un trajet depuis la liste, relancer l'app, le ♡ et le compteur restent (état lu du serveur).
- [ ] Deux comptes, deux trajets identiques à l'exception des j'aime : le plus aimé passe devant dans « Tous les trajets ».
- [ ] Un visiteur touche le ♡ : invitation à se connecter, aucun changement de compteur.
- [ ] Le voyageur voit « n j'aime » sur sa carte et dans la tuile « Affiche » de son détail ; un visiteur ne voit jamais les vues.
- [ ] Nettoyage après fusion : worktrees et branches locales supprimés (règle de `CLAUDE.md`).
