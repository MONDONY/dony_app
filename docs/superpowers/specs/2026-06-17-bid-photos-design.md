# Spec — Photos du colis & sélection de contenu sur l'offre (bid)

**Date :** 2026-06-17
**Statut :** Validé (brainstorming) — prêt pour plan d'implémentation
**Repos concernés :** `dony-back` (Spring Boot) **et** `dony_app` (Flutter) — deux repos git **séparés**.

---

## 1. Objectif

Refondre la création d'une offre (bid) d'un expéditeur sur un trajet de voyageur pour :

1. **Photos du colis (optionnel)** — l'expéditeur peut joindre jusqu'à **4 photos** à la création de l'offre.
2. **Visibilité voyageur** — le voyageur voit ces photos dans le détail de l'offre **avant** d'accepter, dans une galerie + un **viewer modal** (carte arrondie, pas plein écran) avec swipe / dots / compteur.
3. **Persistance après acceptation** — les photos restent visibles tant que l'offre n'est pas en route.
4. **Cycle de vie & purge** — les photos passent en statut `DELETING` à certains événements (offre en route, refusée, annulée, etc.), puis un **cron quotidien à minuit** purge physiquement les fichiers (S3 + ligne DB).
5. **Sélection de contenu pilotée par l'annonce** — le step « contenu du colis » du formulaire d'offre se base sur ce que le voyageur **accepte** (`acceptedContentTypes`) et **refuse** (`refusedTypes`), et permet à l'expéditeur d'**ajouter ses propres éléments** (custom). Modèle **pass-through** : le voyageur voit tout et décide en bloc (Accepter / Refuser).

---

## 2. État actuel (existant vérifié)

### Backend (`dony-back`)
- `BidEntity` (`matching/BidEntity.java`) : champ `contentCategory` (VARCHAR 50, texte libre), `refusalPhotoUrl` (photo unique de refus, sans statut). **Aucune** table photos multiples.
- `BidStatus` : `AWAITING_PAYMENT, PENDING, PAYMENT_ESCROWED, ACCEPTED, HANDED_OVER, IN_TRANSIT, REJECTED, CANCELLED, COMPLETED, NO_SHOW, PARCEL_REFUSED, EXPIRED`.
- `AnnouncementEntity` : `acceptedContentTypes: List<String>` (table `announcement_accepted_types`), `refusedTypes: List<String>` (table `announcement_refused_types`) — free-form.
- `BidRequest` (DTO) : `weightKg, declaredValueEur, description, contentCategory, recipientName, recipientPhone, disclaimerSigned, paymentMethod, phoneNumber, countryCode, promoCode, gridItems`. Création JSON via `POST /announcements/{announcementId}/bids`.
- `StorageService` (`common/`) : `uploadFile(MultipartFile, prefix)`, `uploadRequestPhoto(...)` (resize/thumbnail), `generatePresignedUrl(objectKey, Duration)`, `deleteFile(objectKey)`, `deleteByPrefix(prefix)`. Prefixes autorisés : `tracking/, users/, messaging/, kyc/, package_requests/, requests/`.
- Events bid émis : `BidRejectedEvent`, `BidExpiredOnDepartureEvent`, `BidAcceptedEvent`, `ParcelRefusedEvent`, `BidCreatedEvent`, `HandoverAlertEvent` (`matching/events/`).
- Schedulers existants (pattern) : `AwaitingPaymentCleanupScheduler`, `AnnouncementInProgressScheduler` (`@Scheduled(cron="0 0 * * * *")`), etc.
- **Dernière migration Flyway : `V139`** → nouvelle = **`V140`**.

### Frontend (`dony_app`)
- `DonyMediaService.pick({required ImageSource source})` (`core/services/media_service.dart`, PR #96) : renvoie `XFile?`, resize ≤ 1920×1920, JPEG qualité 85, rejette vidéos/non-images, garde-fou 50 MB.
- Upload multipart existant (pattern) : `tracking_repository.uploadTrackingPhoto()` → `FormData` → `/storage/upload/tracking` → renvoie `{key}`.
- `BidModel` (`features/matching/data/models/bid_model.dart`) : json_serializable. `BidBloc._onCreateRequested` tire `AnalyticsEvents.bidSubmitted`.
- Form offre : `create_bid_bottom_sheet.dart` — `contentCategory` = multi-select chips depuis **liste statique en dur** `['Vêtements','Médicaments','Alim. sèche','Documents','Hi-fi','Téléphone','Autre']`, joint en CSV. **Aucun lien** avec l'annonce.
- Détail voyageur : `bid_detail_screen.dart` + `traveler_detail_body.dart` + `colis_destinataire_card.dart`.
- `AnnouncementModel` expose déjà `acceptedContentTypes`, `refusedTypes`, `priceGridItems`.

---

## 3. Décisions de conception (validées)

| # | Décision |
|---|----------|
| D1 | **Max 4 photos** par offre, optionnel. |
| D2 | Viewer = **modal carte arrondie** (radius 22) sur fond assombri, **pas plein écran**. Swipe + flèches + dots + compteur « Photo n / N », ✕ ou tap dehors pour fermer. Réutilisé côté expéditeur et voyageur. |
| D3 | Sélection contenu = 3 groupes : **Accepté** (chips depuis `announcement.acceptedContentTypes`, sélectionnables), **Tes éléments** (custom, ajout libre), **Refusé** (`announcement.refusedTypes`, verrouillés/barrés, non sélectionnables). |
| D4 | **Pass-through** : éléments custom acceptés sans étape de validation ; le voyageur décide en bloc. |
| D5 | **Refus → photos supprimées** via le même chemin DELETING + cron (pas de suppression immédiate). |
| D6 | **Un seul chemin de suppression** : `ACTIVE → DELETING → purge cron`. Jamais de delete direct hors cron. |
| D7 | Upload = **pré-upload puis référence** : `POST /bids/photos` (multipart, 1 photo → `{key}`), le client collecte les keys, puis `BidRequest.photoKeys` à la création. |
| D8 | Transition `ACTIVE → DELETING` posée par **listener** sur les events de statut bid + **balayage défensif** dans le cron (bids terminaux/route dont photos encore ACTIVE). |
| D9 | Cron purge : `@Scheduled(cron="0 0 0 * * *")` (minuit). |

---

## 4. Conception détaillée — Backend (`dony-back`)

### 4.1 Modèle de données

**Migration `V140__bid_photos.sql`** — table `bid_photos` :

| colonne | type | notes |
|---------|------|-------|
| `id` | UUID PK | |
| `bid_id` | UUID NOT NULL | FK → `bids(id)`, index |
| `object_key` | VARCHAR(1024) NOT NULL | clé S3 (`bids/...`) |
| `position` | INT NOT NULL | ordre 0..3 |
| `status` | VARCHAR(20) NOT NULL | `ACTIVE` / `DELETING`, défaut `ACTIVE`, index |
| `deleting_since` | TIMESTAMP NULL | horodatage passage DELETING |
| `created_at` | TIMESTAMP NOT NULL | |

Index : `(bid_id)`, `(status)` (le cron filtre dessus).
Pas d'`audit_log` requis pour les photos elles-mêmes ; purge physique voulue (donc **pas** de `BaseEntity` soft-delete sur cette table).

**Entité `BidPhotoEntity`** (`matching/BidPhotoEntity.java`) + **enum `BidPhotoStatus { ACTIVE, DELETING }`** (`matching/BidPhotoStatus.java`).
Repository `BidPhotoRepository` : `findByBidIdAndStatus(...)`, `findByStatus(DELETING)`, `findAllByBidId(...)`.

### 4.2 Upload des fichiers

- **Endpoint** `POST /bids/photos` (multipart `file`), authentifié (`ROLE_SENDER`).
  - Validations : type image (réutiliser logique `uploadRequestPhoto` : resize, JPEG, thumbnail si pertinent), taille ≤ 10 MB, sinon `ProblemDetail` 422.
  - Prefix S3 **`bids/`** → ajouter `bids/` aux prefixes autorisés de `StorageService`.
  - Réponse : `{ "key": "bids/{senderId}/{ts}_colis.jpg" }`.
- Le client upload chaque photo choisie (≤ 4) et collecte les `key`.

### 4.3 Création de l'offre

- `BidRequest` gagne `photoKeys: List<String>` — `@Size(max = 4)`, nullable.
- `BidService.createBid(...)` :
  - Garde-fou : chaque key doit commencer par `bids/` (sinon 422) → empêche de référencer des objets arbitraires.
  - Crée une ligne `BidPhotoEntity` (status `ACTIVE`, `position` = index) par key, liée au bid.
  - **Garde-fou contenu** : aucun élément déclaré (`contentCategory` éclaté sur `,`) ne doit appartenir à `announcement.refusedTypes` → sinon `ProblemDetail` 422. Les éléments custom (hors listes annonce) restent autorisés.

### 4.4 Réponse / lecture

- Nouveau DTO `BidPhotoResponse { UUID id, String url }` — `url` = **presigned GET** (`generatePresignedUrl`, TTL court ex. 15 min).
- `BidResponse` et `BidDetailResponse` gagnent `photos: List<BidPhotoResponse>` — **uniquement les `ACTIVE`** (les `DELETING` ne sont jamais renvoyées).

### 4.5 Transition ACTIVE → DELETING (listener)

- Nouveau listener (package `matching/`, ex. `BidPhotoLifecycleListener`) écoutant les events terminaux/route :
  - `BidRejectedEvent`, `BidExpiredOnDepartureEvent`, `ParcelRefusedEvent` → passer toutes les photos ACTIVE du bid en `DELETING` (+ `deleting_since`).
  - Transitions sans event dédié (`CANCELLED`, `IN_TRANSIT`, `NO_SHOW`) : poser la transition **directement dans `BidService`** au point de changement de statut, OU publier/écouter l'event correspondant s'il existe déjà. (Le plan tranchera au cas par cas selon les events réellement émis.)
- Règle : `ACCEPTED` / `HANDED_OVER` → photos restent `ACTIVE`.

### 4.6 Cron de purge

- Nouveau `BidPhotoCleanupScheduler` (package `matching/`), `@Scheduled(cron="0 0 0 * * *")` :
  1. `findByStatus(DELETING)` par lots.
  2. Pour chaque : `storageService.deleteFile(objectKey)` puis suppression de la ligne. Idempotent (si le fichier n'existe plus, ignorer l'erreur et supprimer la ligne).
  3. **Balayage défensif** : photos encore `ACTIVE` mais dont le bid est dans un état terminal/route (`REJECTED, CANCELLED, EXPIRED, IN_TRANSIT, NO_SHOW, PARCEL_REFUSED`) → les passer `DELETING` (rattrape un listener manqué) ; elles seront purgées au passage suivant.
- Pattern calqué sur `AwaitingPaymentCleanupScheduler`.

### 4.7 Tests backend
- `BidPhotoServiceTest` : création photos à partir de keys, garde-fou prefix, garde-fou refusedTypes (422), max 4.
- `BidPhotoCleanupSchedulerTest` : purge DELETING, balayage défensif, idempotence (fichier déjà absent).
- `BidPhotoLifecycleListenerTest` : event refus/expire/refused → DELETING.
- Controller `POST /bids/photos` (MockMvc) : succès, type non-image (422), > 10 MB (422), non authentifié (401).
- Couverture ≥ 90 %.

---

## 5. Conception détaillée — Frontend (`dony_app`)

### 5.1 Data
- Nouveau model `BidPhoto { String id, String url }` (`features/matching/data/models/bid_photo.dart`) + json_serializable.
- `BidModel` gagne `List<BidPhoto> photos` (défaut `[]`), parsé depuis `photos`.
- `BidRepository` / `BidRemoteDatasource` :
  - `uploadBidPhoto(String filePath) → String key` : `FormData` multipart → `POST /bids/photos` (pattern `uploadTrackingPhoto`).
  - `createBid(...)` gagne `List<String>? photoKeys` → ajouté au body JSON.

### 5.2 BLoC (`BidBloc`)
- Le flux d'upload des photos est géré dans le BLoC (pas dans le widget) :
  - Events : `BidPhotoAddRequested(filePath)`, `BidPhotoRemoveRequested(localId/key)`.
  - State : liste des photos en cours (uploading / uploaded key / erreur) exposée au form.
  - `BidCreateRequested` / `BidCheckoutRequested` transmettent les `photoKeys` collectées.
- `AnalyticsService` déjà injecté — on ajoute les events (cf. 5.5).

### 5.3 UI — Expéditeur (`create_bid_bottom_sheet.dart`)
- **Section « 📷 Photos du colis » (optionnel)** : rangée de thumbnails (avec ✕ pour retirer) + tuile « + Ajouter » → choix caméra/galerie via `DonyMediaService.pick`. Max 4 (tuile masquée à 4). Indicateur d'upload par thumbnail. Respecter règle bottom sheet (boutons → `stickyBottom`).
- **Refonte step « contenu »** : 3 groupes (D3) — chips **Accepté** (depuis `announcement.acceptedContentTypes`), **Tes éléments** custom (input d'ajout + chips retirables), **Refusé** (`announcement.refusedTypes`, désactivés/barrés + note). Remplace la liste statique `_contentCategories`. La valeur soumise reste un CSV (`contentCategory`) = accepté sélectionnés + custom.
- Garde-fou client : un refusé n'est pas sélectionnable (back valide aussi).

### 5.4 UI — Voyageur (détail offre)
- `colis_destinataire_card.dart` (ou carte « Le colis ») : galerie de thumbnails (jusqu'à 3 + overlay « +N ») + badge « 📷 N photos ». Affichée **avant** Accepter/Refuser.
- **`BidPhotoViewerModal`** (nouveau widget partagé, `features/matching/presentation/widgets/bid_detail/`) : modal carte arrondie, `PageView` swipe, dots, compteur « Photo n / N », fermeture ✕ / tap scrim. `CachedNetworkImage` (presigned URL). Réutilisé côté expéditeur (relecture) et voyageur.
- Si `photos` vide → aucune galerie (pas d'état vide intrusif).

### 5.5 Analytics
- Ajouter dans `AnalyticsEvents` : `bidPhotoAdded = 'bid_photo_added'`, `bidPhotoRemoved = 'bid_photo_removed'`, `bidPhotosViewed = 'bid_photos_viewed'`.
- `bid_photo_added` / `bid_photo_removed` tirés dans `BidBloc` (handlers). `bid_photos_viewed` à l'ouverture du modal (propriété `photo_count`, sans PII).
- MAJ de la table des events dans `dony_app/CLAUDE.md`.

### 5.6 Tests frontend
- blocTest `BidBloc` : add/remove photo (upload mock), create avec `photoKeys`.
- Widget tests : section photos (ajout/retrait, cap à 4), `BidPhotoViewerModal` (swipe, compteur, fermeture), step contenu (accepté sélectionnable, refusé désactivé, ajout custom).
- Couverture ≥ 90 %.

---

## 6. Sécurité & conformité
- Photos servies en **presigned URL** (TTL court), jamais d'URL publique directe.
- Garde-fou prefix `bids/` à la création (pas de référence d'objet arbitraire).
- Aucune PII dans les properties analytics (seulement `photo_count`).
- Upload authentifié `ROLE_SENDER` ; rate limiting Nginx applicable comme les autres endpoints.
- Purge physique = conforme minimisation des données (les photos ne survivent pas au trajet terminé / au refus).

---

## 7. Hors périmètre (YAGNI)
- Pas de réorganisation drag-and-drop des photos (ordre = ordre d'ajout).
- Pas d'édition de photos après création de l'offre (ni ajout ni retrait post-création) — uniquement à la création.
- Pas de validation granulaire des éléments custom côté voyageur (pass-through, D4).
- Pas de modal plein écran (D2).

---

## 8. Découpage repos (rappel)
- **`dony-back`** : §4 (migration V140, entité, endpoint upload, DTO, listener, cron, tests). Commits dans le repo `dony-back`, branche dédiée.
- **`dony_app`** : §5 (model, repo/datasource, BLoC, UI form + détail + viewer, analytics, tests). Commits dans le repo `dony_app`, branche `feature/bid-photos`.
- Contrat d'API partagé : `POST /bids/photos`, `BidRequest.photoKeys`, `BidResponse.photos[]`.
