# Feature — Demande d'envoi : redesign carte/détail + photos colis multiples (full-stack)

**Date:** 2026-06-18 | **Status:** ✅ Complète
**Repos/branches:** `dony-back` → `feature/package-request-photos` · `dony_app` → `feature/demande-photos-redesign`

## Résumé
L'expéditeur ajoute jusqu'à **4 photos** de son colis à la création d'une demande d'envoi.
Quand un voyageur lie son trajet (bid matérialisé après paiement), les photos sont **copiées
vers le bid** (S3 `package_requests/` → `bids/`) et apparaissent dans la galerie du bid existante.
La **carte** demande passe à une identité colis-first (ticket ambre, photo + compteur, chip
statut, budget). Le **détail** devient un écran plein écran (carousel photos, sections,
signalement, CTA « Proposer mon trajet »).

## Backend (dony-back)
- **V141** `package_request_photos` (table miroir de `bid_photos`). `photo_url` (V57) conservé = 1ère.
- `PackageRequestPhotoEntity` / `Repository` / `PackageRequestPhotoService` (replacePhotos max 4,
  valide prefix `package_requests/{senderId}/`, `objectKeys`, `activePhotos` presigned, `firstPhotoUrl`).
- API : `PackageRequestCreateRequest.photoKeys` (max 4). `create`/`update` attachent les photos
  (update : `photoKeys==null` → conserve). Réponses (`PackageRequestResponse`,
  `PackageRequestSearchResponse`) exposent `photos[]` presigned + `photoUrl`=1ère.
- `StorageService.copyObject(src, destPrefix)` (copie S3 server-side).
- **Propagation** : `PackageRequestAcceptedEvent` étendu (`photoObjectKeys`), peuplé dans
  `NegotiationService.finalizeInternal`, copié+attaché dans `ThreadAcceptedBidListener.onPackageRequestAccepted`
  (best-effort : un échec de copie ne casse pas la matérialisation).
- **V142** `package_request_reports` + `PackageRequestReportService` + `POST /package-requests/{id}/report`
  (idempotent, auto-signalement interdit, `audit_log`).

## Frontend (dony_app)
- Modèles : `PackageRequest`/`PackageRequestSearchItem` + `photoUrls`. Repo `uploadPhotoKey`,
  `create/update photoKeys`, `report`.
- `PackageRequestPhotosCubit` (calqué `BidPhotosCubit`, max 4, add/remove/readyKeys/touched).
- Wizard : Step 2 = bloc multi-photos (`PackageRequestPhotoSection`) + catégorie « Autre » libre
  + description. `FormStep3Submitted.photoKeys`. CTA Retour+action sur la même ligne (steps 2-3).
- Carte `PackageRequestListCard` : ticket ambre, photo+compteur, titre colis-first, trajet
  (drapeaux), budget, `packageStatusChip(status)`.
- Détail `PackageRequestPublicDetailScreen` : carousel photos, identité + statut + PRIX FERME,
  sections (Colis/Budget/Paiement souhaité/Zones), app bar bug + signaler, CTA « Proposer mon trajet ».
  `PackageRequestPreviewBottomSheet.show()` → navigue vers cet écran (tous les appelants home basculent).
- Analytics : `package_request_photo_added/removed`, `package_request_detail_opened`,
  `package_request_reported`.

## Tests
- Backend : `./mvnw test` vert (≈1900 tests). Nouveaux : `PackageRequestPhotoServiceTest`,
  `StorageServiceCopyObjectTest`, propagation dans `ThreadAcceptedBidListenerTest`,
  `PackageRequestReportServiceTest`, IT report.
- Flutter : `flutter test` vert (≈4150 tests). Nouveaux/maj : repo photoKeys+report+parsing,
  `PackageRequestPhotosCubit`, `PackageRequestPhotoSection`, carte ticket, détail body, preview→nav.

## Pièges
- `update` avec `photoKeys==null` conserve les photos (édition sans toucher aux photos) ;
  liste (même vide) = remplace.
- `attachPhotos` valide le prefix `bids/` → la propagation **copie** d'abord l'objet S3 (lifecycle
  indépendant, cleanup cron réutilisé tel quel).
- Carte/feed : `status` par défaut OPEN (le feed est openOnly) ; le détail charge le vrai statut.
