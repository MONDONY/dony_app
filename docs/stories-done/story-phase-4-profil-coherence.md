# Story Phase 4 — Profil cohérent & additif (Flutter + Backend)

**Date:** 2026-06-14 | **Status:** ✅ Complète
**Branche:** `feature/phase-4-profil` (front `dony_app` ET back `dony-back`, repos séparés)

## Résumé

Refonte du profil sur un **modèle additif** : l'expéditeur a un profil lean ; devenir
voyageur ajoute champs et sections par-dessus la base — sans bascule de rôle, sans label
« voyageur ». Header et 3 onglets (Activité / Compte / Réglages) conservés et embellis.
Nouveaux champs : **À propos (bio, tous), photo de profil (bucket, URL publique), langues
et mode de transport (voyageur)**. Édition profil migrée de bottom sheet vers **écran plein**.
Profil public enrichi (À propos, langues/transport) + **bottom sheet « tous les avis »**
(résumé + répartition étoiles + pagination, avis nominatifs avec auteur + avatar + corridor).
Onglets réorganisés (adresses → Carnet, fusion Paiements, masquage des tuiles « Bientôt »,
Devenir voyageur en carte CTA). PRO unifié en un seul écran (+ downgrade).

## Fichiers créés / modifiés

### Backend (`dony-back/`)
- `db/migration/V139__profile_fields.sql` (NEW) — colonnes `bio`/`avatar_url`/`transport_mode` + table `user_languages`.
- `auth/TransportMode.java` (NEW) — enum AVION/VOITURE/TRAIN.
- `auth/UserEntity.java` — 4 champs + accessors.
- `auth/dto/UpdateProfileRequest.java`, `auth/dto/UserResponse.java` — bio/langues/transport (+ avatarUrl sur UserResponse).
- `auth/AuthService.java` — mapping update + `updateAvatar` + injection `StorageService`.
- `auth/AuthController.java` — `POST /auth/me/avatar` (multipart).
- `common/StorageService.java` — `publicUrl()`.
- `auth/dto/ProfilePublicResponse.java`, `auth/ProfilePublicService.java` — avatar/bio/langues/transport.
- `ratings/dto/RatingItemResponse.java`, `ratings/RatingService.java` — auteur (prénom+initiale) + avatar + corridor.

### Front (`dony_app/`)
- `features/auth/data/models/user_model.dart` — bio/avatarUrl/languages/transportMode (+ toJson).
- `features/auth/data/...` + `bloc/` — `updateProfile` étendu, `uploadAvatar`, `AuthAvatarUploadRequested`.
- `features/ratings/data/models/rating_summary.dart` — `RatingItem` auteur/corridor.
- `features/profile/data/models/profile_public_model.dart` — bio/langues/transport.
- `features/profile/presentation/screens/edit_profile_screen.dart` (NEW) — écran plein + photo + bio 280 + préférences.
- `features/profile/presentation/widgets/edit_profile_bottom_sheet.dart` (SUPPRIMÉ).
- `features/profile/presentation/screens/profile_public_screen.dart` — À propos + langues/transport + bouton « tous les avis ».
- `features/profile/presentation/widgets/all_reviews_bottom_sheet.dart` (NEW) + `bloc/user_reviews_cubit.dart` (NEW).
- `features/profile/presentation/profile_screen.dart` — réorg onglets (adresses→Carnet, fusion Paiements, masquage Bientôt, CTA voyageur, PRO→écran).
- `features/profile/presentation/widgets/become_traveler_cta_card.dart` (NEW).
- `features/profile/presentation/screens/upgrade_to_pro_screen.dart` — état déjà-PRO + downgrade.
- `features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart` (SUPPRIMÉ).
- `features/profile/presentation/screens/become_traveler_screen.dart` — stepper poli (logique inchangée).
- `core/services/analytics_events.dart` + `CLAUDE.md` — events `profile_photo_updated`/`profile_about_updated`/`public_reviews_opened`.
- `app/router.dart` — route `/profile/edit`. `core/di/injection.dart` — `UserReviewsCubit`.

## Comment ça fonctionne

### Flux utilisateur
1. **Éditer le profil** : header (bouton ✎) ou bannière complétion → écran plein `/profile/edit`.
   Champs : Identité, **À propos** (max 280, tous), Coordonnées, Infos perso ; **Préférences**
   (Langues + Transport) visibles uniquement si voyageur. Photo : tap avatar → galerie → upload
   (`POST /auth/me/avatar`), l'écran reste ouvert et rafraîchit l'avatar (flag `_saving` → pop
   seulement sur « Enregistrer »).
2. **Profil public** (vu par les autres) : Hero → À propos → Stats → Langues/Transport → Badges
   → Avis → Contact. « Voir tous les avis (N) » → bottom sheet paginée (résumé + répartition
   étoiles, chaque avis : avatar + prénom+initiale + étoiles + date + commentaire + corridor).
3. **Onglets** : adresses dans Mon carnet (base) ; section PAIEMENTS (portefeuille) ; tuiles
   « Bientôt » masquées ; non-voyageur voit la **carte CTA Devenir voyageur** en tête de Compte.
4. **PRO** : tuile Compte PRO → écran `/profile/upgrade-to-pro` (formulaire si non-PRO ;
   infos société + « Revenir en compte standard » si PRO).

### BLoC / events
- `AuthBloc` : `AuthUpdateProfileRequested` (+ bio/languages/transportMode) → `AuthProfileUpdated` ;
  `AuthAvatarUploadRequested(path)` → upload → `AuthProfileUpdated` (analytics `profile_photo_updated`).
  `profile_about_updated` tiré quand bio non vide.
- `UserReviewsCubit` : seed depuis le résumé déjà chargé puis pagination (`getUserRatings(userId, page)`),
  event `public_reviews_opened` (propriété `rating_count`) tiré une fois.

### Appels API
- `PATCH /auth/me` (bio/languages/transportMode), `POST /auth/me/avatar` (multipart, renvoie l'user
  avec `avatarUrl` public), `GET /users/{id}/profile-public` (+ bio/langues/transport),
  `GET /ratings/user/{id}?page=` (avis enrichis auteur+corridor), `DELETE /auth/me/upgrade-to-pro` (downgrade).

### Pièges / points d'attention
- **Avatar = URL publique** (pas presigned comme le KYC) → prérequis déploiement : préfixe bucket
  `users/` lisible publiquement + config `storage.public-base-url`.
- L'upload d'avatar émet aussi `AuthProfileUpdated` : l'écran d'édition ne se ferme PAS dessus
  (flag `_saving`), seulement après « Enregistrer ».
- `AuthBloc` global partagé → le header se rafraîchit seul après save (pas de reload manuel).
- Avis : nom = **prénom + initiale uniquement** (anti-PII).

## Critères d'acceptation couverts
- Modèle additif (champs + sections) sans label voyageur ✅
- À propos (tous, 280) ✅ · Photo bucket URL publique ✅ · Langues + Transport (voyageur) ✅
- Édition = écran plein + sticky save ✅ · Profil public enrichi + sheet avis paginée nominative ✅
- Onglets réorganisés (adresses, fusion paiements, masquage Bientôt, CTA, PRO unique + downgrade) ✅
- Analytics (3 events, sans PII) ✅

## Tests
- **Backend** : 1830 tests, BUILD SUCCESS.
- **Front** : 4055 tests verts (2 skipped), `flutter analyze` 0 erreur.
- Tests ajoutés pour chaque task (models, blocs/cubit, écrans, sheet, réorg onglets, analytics).

## Décisions techniques
- Garder `ActiveRoleCubit` (décision merge séparée) — le profil additif s'appuie sur
  `UserModel.isTraveler`/`isSender`, pas sur un toggle.
- Avis : enrichissement via joins existants (rater user + bid→announcement) — pas de migration.
- Réutilisation : `RatingSummaryCard` (header répartition), endpoint `getUserRatings` paginé.
- PRO : suppression du doublon bottom sheet au profit de l'écran existant.

## Reste à faire (hors code)
- Config déploiement `storage.public-base-url` + ACL public-read du préfixe `users/`.
- Vérification manuelle device (3 onglets × expéditeur/voyageur) recommandée avant merge.
