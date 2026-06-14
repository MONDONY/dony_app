# Phase 4 — Profil cohérent & additif (design)

**Date :** 2026-06-14 · **Statut :** ✅ Design validé · **Branche :** `feature/phase-4-profil`

---

## 1. Contexte & objectif

Le profil mélange aujourd'hui des sections selon le rôle, sans modèle clair, et la
feuille « Modifier le profil » est une bottom sheet limitée. Objectif : rendre le
profil **propre, cohérent et additif** sans casser ce que l'utilisateur aime.

**Principes directeurs (validés) :**

1. **On garde** la structure actuelle : **header** existant + **3 onglets** (Activité / Compte / Réglages).
2. **Additif, pas XOR** : l'expéditeur a un profil lean ; devenir voyageur **ajoute**
   des champs et des sections par-dessus la base — sans bascule de rôle, sans
   « deuxième profil ».
3. **Pas de label « voyageur »** sur les sections : les sections d'un voyageur
   apparaissent simplement, dans le même style visuel que les autres.
4. **Cohérence visuelle** : cartes arrondies, icône en pastille, séparateurs fins,
   rayons concentriques, palette dony bleue (`DonyColors.primary` #0B5FFF).

Hors-scope : refonte du header (conservé tel quel, +badges de rôle), onglet
Réglages (déjà propre), `ActiveRoleCubit` (inchangé — décision séparée du merge).

---

## 2. Modèle de données

### 2.1 Nouveaux champs utilisateur (base = tous les users)

| Champ | Type back | Type front (`UserModel`) | Pour qui |
|---|---|---|---|
| `bio` (À propos) | `varchar(280)` | `String? bio` | tous |
| `avatarUrl` | `varchar(512)` | `String? avatarUrl` | tous |
| `languages` | table `user_languages` (`@ElementCollection`) | `List<String> languages` | voyageur (saisie) |
| `transportMode` | `varchar` enum (`AVION`/`VOITURE`/`TRAIN`) | `String? transportMode` | voyageur (saisie) |

- `bio` : limite **280 caractères** (validée côté front `maxLength` + côté back `@Size(max=280)`).
- `avatarUrl` : **URL publique directe** (décision validée — l'avatar n'est pas sensible,
  affiché en listes/chat/profil public, cacheable via `CachedNetworkImage`).
  ⚠️ Ne pas confondre avec le KYC qui reste **presigned only**.
- `languages` / `transportMode` : saisis dans l'écran d'édition, **visibles une fois
  voyageur** (pas affichés à l'expéditeur pur). Persistés pour tous mais l'UI ne les
  collecte qu'au statut voyageur.

### 2.2 Enrichissement des avis (`RatingItem`)

Le modèle actuel (`RatingItem`) n'a que `stars`, `comment`, `createdAt`, `excluded`.
Ajouts (back → front) :

| Champ | Type | Source |
|---|---|---|
| `authorName` | `String` | prénom + initiale du nom de l'auteur (ex. « Fatou M. ») — **pas de PII complète** |
| `authorAvatarUrl` | `String?` | avatar de l'auteur |
| `departureCity` | `String?` | ville de départ du bid lié |
| `arrivalCity` | `String?` | ville d'arrivée du bid lié |

`RatingSummary.distribution` (répartition par étoiles) **existe déjà** — réutilisé tel quel.

### 2.3 Profil public (`ProfilePublicModel`)

`avatarUrl` existe déjà. Ajouter : `bio`, `languages`, `transportMode`.

---

## 3. Backend (`dony-back/`)

### 3.1 Migration Flyway `V100__profile_fields.sql`

- `ALTER TABLE users ADD COLUMN bio varchar(280)`, `avatar_url varchar(512)`,
  `transport_mode varchar(16)`.
- `CREATE TABLE user_languages (user_id uuid REFERENCES users(id), language varchar(32))`.
- Jamais modifier une migration existante (règle projet) — V100 est la prochaine après V99.

### 3.2 `UserEntity` (`com.dony.api.auth`)

Ajouter les champs `bio`, `avatarUrl`, `transportMode` (enum `TransportMode`), et
`@ElementCollection Set<String> languages`. Soft-delete inchangé (extends `BaseEntity`).

### 3.3 Endpoints

1. **Mise à jour profil** — `PATCH /auth/me` (existant). Étendre `UpdateProfileRequest`
   avec `bio`, `languages`, `transportMode` ; `AuthService.updateProfile` les mappe.
   Validation `@Size(max=280)` sur `bio`, enum borné sur `transportMode`.
2. **Upload photo** — **`POST /auth/me/avatar`** (multipart `image/jpeg`). Flux :
   - Valider type + taille (≤ 10 MB).
   - `StorageService` (common/) upload → chemin **`avatars/{userId}/{ts}_avatar.jpg`**.
   - Renvoie l'**URL publique** ; persiste `avatar_url` ; retourne `UserResponse` à jour.
   - RFC 7807 sur erreur (taille/format).
3. **Avis enrichis** — endpoint `GET /ratings/user/{userId}` (existant, déjà paginé
   page/size 20). Enrichir le mapping DTO : joindre l'auteur (prénom + initiale, avatar)
   et le bid (départ/arrivée). Vérifier que l'entité Rating référence rater + bid
   (sinon, mapping via repository). **Pas de migration** si les relations existent.
4. **Profil public** — endpoint existant : ajouter `bio`, `languages`, `transportMode`
   au DTO de réponse.

### 3.4 Tests back

Unit (service update profil + validations bio/transport), upload avatar (mock
StorageService, taille/format), mapping avis enrichis. Integration MockMvc sur
`PATCH /auth/me`, `POST /auth/me/avatar`, `GET /ratings/user/{id}`. Couverture ≥ 90 %.

---

## 4. Frontend (`dony_app/`)

### 4.1 A — « Modifier le profil » : bottom sheet → écran plein

- **Supprimer** `edit_profile_bottom_sheet.dart`. Créer
  `lib/features/profile/presentation/screens/edit_profile_screen.dart`.
- **Route** `/profile/edit` dans `router.dart` (screen tracking auto).
- **Template** : écran secondaire (app bar retour ‹ + titre « Modifier le profil »),
  body scrollable, **bouton sticky bas** `DonyButton('Enregistrer')` (jamais dans le child).
- **Champs** (tous gardés + nouveaux) :
  - Identité : Prénom, Nom.
  - **À propos** : `TextField maxLength: 280` + compteur (tous).
  - Coordonnées : Email (optionnel).
  - Informations personnelles : Date de naissance, Ville.
  - **Préférences** (section neutre, visible une fois voyageur) : Langues parlées
    (chips multi-select + ajouter), Mode de transport (segmented ✈️/🚗/🚆).
- **Photo de profil** : avatar tap → `ImagePicker` (galerie/caméra) → compress
  (qualité 85 %, max ~1024², < 10 MB) → preview local + loading → upload multipart
  `POST /auth/me/avatar`. GPS non requis (pas un scan).
- **BLoC** : `AuthBloc` — `AuthUpdateProfileRequested` gagne `bio`, `languages`,
  `transportMode` ; nouvel event `AuthAvatarUploadRequested(file)`. Loading/Error gérés.
- **Refresh après nav** (règle A) : appelant `await context.push<bool>('/profile/edit')`
  → si `true`, recharger ; l'écran fait `context.pop(true)` après succès.

### 4.2 B — Profil public enrichi

Ordre des cartes (validé) : **Hero → À propos → Stats → Langues/Transport → Badges
→ Avis → Contact**.

- **Hero** : avatar (photo), nom, « membre depuis » + ville, chips Vérifié/PRO/Kilo Pro.
- **À propos** : carte bio (affichée si non vide), pour tous.
- **Stats** : colis livrés · note · délai de réponse.
- **Langues + Transport** : carte 2 colonnes, **uniquement si voyageur / données présentes**.
- **Badges · Avis · Contact** : conservés.
- **« Voir tous les avis (N) »** : bouton sur la carte Avis → **bottom sheet** :
  - En-tête : note moyenne + **répartition par étoiles** (barres, via `distribution`).
  - Liste **scrollable paginée** (réutilise `getUserRatings(userId, page)` + widget
    `rating_list_item`). Chaque avis : **avatar + nom (prénom+initiale)** + étoiles +
    date + commentaire + **chip corridor** (Paris → Dakar).
  - Read-only → pas de bouton sticky (conforme : aucun `DonyButton` requis ici).

### 4.3 C — Onglets Activité & Compte réorganisés (additif)

**Onglet Activité :**
- MON ACTIVITÉ : Mes envois en cours, Mes négociations (si actives).
- MON CARNET : Mes destinataires, Mes abonnements, **Mes adresses** *(déplacé depuis
  la section voyageur — ce sont des adresses de livraison, côté expéditeur)*.
- LITIGES : Mes litiges.
- MES TRAJETS *(voyageur)* : Mes trajets, Colis sur mes trajets, Mes modèles de trajet.

**Onglet Compte :**
- **Carte CTA « Devenir voyageur »** en haut *(si non-voyageur)* — grande carte gradient,
  remplace la petite section.
- À PROPOS : Ma présentation *(raccourci édition)*.
- CONTACT & SÉCURITÉ : Téléphone, Email.
- IDENTITÉ & CONFIANCE : Vérification d'identité, **Mon profil public** + **Mes avis reçus**
  *(les deux conservés : aperçu externe vs liste détaillée)*.
- **PAIEMENTS** *(fusion)* : Mon portefeuille + Moyens de paiement *(regroupe l'ancienne
  section Portefeuille + Paiements & factures)*.
- REVENUS VOYAGEUR *(voyageur)* : Recevoir mes paiements (Stripe), Ma grille de prix,
  Commission cash.
- FIDÉLITÉ : Parrainages (+ code parrain si applicable).
- COMPTE PRO : Passer en PRO / Mon profil PRO.

**Masquages :** tuiles « Bientôt » vides (Factures, Crédits & codes promo, Paiements &
factures voyage) **retirées** tant que pas prêtes (pas de tuile morte).

### 4.4 D — Devenir voyageur : polish

Écran plein conservé. Hero bénéfices + **stepper 2 étapes** (1 · Identité vérifiée,
2 · Compte bancaire Stripe Connect) + **bouton sticky** « Activer mon compte voyageur »
(actif quand les 2 étapes OK). Logique d'activation/désactivation actuelle inchangée.

### 4.5 E — Passer PRO : écran unique

- **Supprimer la duplication** : garder **l'écran** `upgrade_to_pro_screen.dart`, retirer
  `upgrade_pro_bottom_sheet.dart` (toutes les entrées pointent vers l'écran).
- Écran plein : champs Nom entreprise + SIRET (14 chiffres exacts), **bouton sticky**
  « Confirmer le passage en PRO ».
- **Si déjà PRO** : afficher infos société + bouton « Revenir en compte standard » (downgrade).
- Confirmation PRO/downgrade via **dialog** (action sensible).

---

## 5. Analytics

Nouveaux events (déclarés dans `AnalyticsEvents`, tirés dans le BLoC, `unawaited`, sans PII) :

| Event | Déclencheur |
|---|---|
| `profile_photo_updated` | succès upload avatar (`AuthBloc`) |
| `profile_about_updated` | bio modifiée non vide (à l'enregistrement) |
| `public_reviews_opened` | ouverture de la bottom sheet « tous les avis » (propriété `rating_count`) |

Events existants conservés : `become_traveler_started`, `upgrade_to_pro_started`.
Mettre à jour la table des events dans `dony_app/CLAUDE.md`.

---

## 6. Tests (≥ 90 %, front & back)

- **BLoC** : `AuthBloc` (update profil étendu, upload avatar succès/erreur).
- **Widgets** : `EditProfileScreen` (champs, compteur 280, picker photo, sticky save,
  préférences masquées si non-voyageur), profil public (À propos, Langues/Transport
  conditionnels), bottom sheet avis (répartition, liste, corridor, pagination),
  onglets réorganisés (sections base + voyageur, masquage Bientôt, CTA), écran PRO.
- **Back** : voir §3.4.

---

## 7. Séquence de build

1. **Back** : migration V100 + `UserEntity` + DTOs + `PATCH /auth/me` étendu + `POST /auth/me/avatar` + enrichissement avis + profil public. Tests.
2. **Front data** : `UserModel` (bio/avatarUrl/languages/transportMode), `RatingItem`
   (author/avatar/corridor), `ProfilePublicModel` (bio/languages/transportMode), repos.
3. **Front A** : `EditProfileScreen` + route + upload photo + suppression sheet.
4. **Front B** : profil public enrichi + bottom sheet avis.
5. **Front C** : réorganisation onglets Activité/Compte + CTA + masquages.
6. **Front D/E** : polish Devenir voyageur + écran PRO unique.
7. Analytics + tests + couverture + doc story.

---

## 8. Points tranchés (récap décisions)

- Header & 3 onglets conservés · modèle additif sans label voyageur.
- « À propos » = champ de base (tous) · 280 caractères.
- Avatar = **URL publique** · upload bucket via `StorageService`.
- Champs voyageur = **Langues + Mode de transport** (pas de corridors/fréquence — évite
  doublon avec trajets & grille de prix existants).
- « Modifier le profil » = **écran plein** + sticky bas (plus de bottom sheet).
- Avis : nom (prénom+initiale) + avatar + corridor + répartition étoiles · « Voir tous
  les avis » en bottom sheet paginée.
- Mes adresses → Carnet · fusion Paiements · masquer Bientôt · Devenir voyageur en CTA.
- PRO = **écran unique** (suppression bottom sheet dupliquée) + downgrade si déjà PRO.
