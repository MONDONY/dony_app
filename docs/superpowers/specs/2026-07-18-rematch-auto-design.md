# Rematch automatique après annulation de trajet — Design

**Date :** 2026-07-18
**Statut :** Validé par l'utilisateur (design conversationnel)
**Portée :** Cross-stack — `dony-back` (1 PR) + `dony_app` (1 PR)
**Référence produit :** Story 5.6 (epic-05-matching.md, FR31) + Story 5.5 (annulation, FR30)

---

## 1. Problème & objectif

Quand un voyageur annule son trajet, les expéditeurs affectés sont remboursés mais laissés sans issue : la notification `TRIP_CANCELLED` ne mène nulle part (routing `null`), l'écran `RematchSearchScreen` existe mais est du code mort (aucun appelant), le détail d'un envoi annulé n'offre aucun CTA, et la génération de suggestions côté back est naïve et buggée (suggestions créées uniquement pour le premier expéditeur affecté, full scan `findAll()`, pas de vérification de capacité).

Objectif : chaîne complète fonctionnelle — annulation → suggestions pertinentes par expéditeur → notification avec deep link → écran alternatives → envoi d'une nouvelle demande.

## 2. Règles métier (verrouillées)

| Règle | Valeur |
|---|---|
| Fenêtre des alternatives | départ ∈ `[aujourd'hui, departureDate_annulé + 3 jours]` (bornes incluses) |
| Corridor | même `departureCity` + `arrivalCity` (égalité insensible à la casse, comportement actuel conservé via Specifications) |
| Capacité | `availableKg` de l'alternative ≥ `weightKg` du bid annulé |
| Exclusions | annonce annulée elle-même ; toutes les annonces du voyageur qui annule ; annonces non publiques (`publicOrOpenSurplus`) ; voyageurs bloqués/bloquants (`notBlockedBy(sender)`) ; statut ≠ `ACTIVE` |
| Tri | date de départ croissante, puis note voyageur décroissante |
| Limite | 5 suggestions max par expéditeur affecté |
| Génération | pour CHAQUE cancellation créée (une par bid affecté) — fixe le bug « premier expéditeur seulement » |
| Notification | une seule, `TRIP_CANCELLED` enrichie (pas de seconde notification) |
| `rematch_status` | `NONE` → `SUGGESTED` quand ≥ 1 suggestion persistée (colonne existante, enfin utilisée) |

**Textes notification (story 5.6) :**
- ≥ 1 alternative : « Trajet annulé — remboursement en cours. N voyageur(s) alternatif(s) disponible(s) » + `data = { type: TRIP_CANCELLED, cancellationId }` (deep link).
- 0 alternative : « Trajet annulé — Aucun voyageur disponible dans les 72h, votre remboursement est traité » sans `cancellationId` (pas de deep link, pas d'écran vide).

## 3. Backend (`dony-back`, package `cancellation/` uniquement)

### 3.1 `RematchService` (nouveau, extrait de `CancellationService`)
- La logique `generateRematchSuggestions` quitte `CancellationService` (l'architecture documente déjà `cancellation/RematchService.java`).
- Requête via `announcementRepository.findAll(Specification, ...)` en composant les specs **existantes** de `matching/AnnouncementSpecification` : `hasStatus(ACTIVE)`, `hasDepartureCity`, `hasArrivalCity`, `departureDateFrom(today)`, `departureDateTo(cancelledDeparture.plusDays(3))`, `minAvailableKg(bidWeightKg)`, `publicOrOpenSurplus` (même visibilité que le feed de recherche public expéditeur), `notBlockedBy(senderId)` + exclusion `id != cancelledAnnouncementId` et `travelerId != cancellingTravelerId`.
- Appelé de façon synchrone par `CancellationService.cancelTrip` dans la même transaction, une fois **par cancellation** (boucle sur les bids annulés), avec le poids du bid concerné.
- Retourne le compte par expéditeur pour alimenter l'événement.
- Cross-package : `cancellation/` peut référencer les Specifications et le repository de `matching/` en lecture (déjà le cas aujourd'hui — `CancellationService` utilise `announcementRepository`) ; aucun appel de service cross-package.

### 3.2 Événement + notification
- `TripCancelledEvent` gagne `Map<UUID, RematchInfo> rematchBySender` où `RematchInfo = (UUID cancellationId, int suggestionCount)` (champ additif, constructeurs existants préservés pour les autres call sites — `cancelAfterHandover` passe une map vide).
- `NotificationDispatcher.onTripCancelled` : corps conditionnel selon `suggestionCount` (textes §2), `cancellationId` dans le payload seulement si count > 0.

### 3.3 API
- `GET /cancellations/{id}/rematch-suggestions` conservé tel quel (participant-only).
- `RematchSuggestionDto` enrichi : + `travelerFirstName` (String), + `travelerRating` (BigDecimal, nullable), + `travelerRatingCount` (int) — l'écran doit afficher note et capacité (story). Chargés en batch (pas de N+1).

### 3.4 Données
- Aucune migration : `rematch_suggestions` et `cancellations.rematch_status` existent déjà (V8).
- `CancellationEntity.rematchStatus` passe à `"SUGGESTED"` quand des suggestions sont persistées pour cette cancellation.

### 3.5 Tests back
- Unit `RematchServiceTest` : fenêtre (borne incluse `departure+3j`, exclu `+4j`, trajets passés exclus), capacité (kg insuffisant exclu), exclusions (même voyageur, annonce annulée, non-ACTIVE), tri (date puis note), limite 5, multi-expéditeurs (chaque cancellation a ses suggestions — anti-régression du bug).
- Test DB réel de la Specification composée (pattern `PackageRequestUrgentSpecificationDbTest`).
- IT controller : DTO enrichi (note voyageur présente), 403 non-participant (existant).
- `NotificationDispatcher` : les 2 corps de message + présence/absence du `cancellationId`.

## 4. Frontend (`dony_app`, feature `cancellation/`)

### 4.1 Route self-fetching
- Route existante `/cancellations/rematch` (extra `CancellationModel`) remplacée par `/cancellations/:id/rematch` : l'écran reçoit `cancellationId`, fetch les suggestions via le bloc (`RematchSuggestionsRequested`) ; `extra` `CancellationModel` accepté en optimisation si déjà en main (chemin interne).

### 4.2 Deep link notification
- `notification_service._routeForMessage` : `TRIP_CANCELLED` + `cancellationId` présent → `/cancellations/{id}/rematch` ; sans `cancellationId` → `null` (comportement actuel conservé pour le cas 0 alternative).
- Même logique dans `notification_bottom_sheet.routeForNotification`.

### 4.3 CTA sur l'envoi annulé
- `billet_talon.dart` `_CancelledBlock` (cas terminal simple, hors flux retour D5-D7) : bouton secondaire « Voir les trajets alternatifs » → route rematch. Affiché seulement si le bid a une cancellation de type `TRIP_CANCELLED` avec `rematchStatus == SUGGESTED` (info exposée par le back dans `BidResponse` — vérifier ce qui existe ; sinon CTA systématique et l'écran gère le vide).

### 4.4 Écran alternatives (`RematchSearchScreen`)
- Bandeau remboursement conservé.
- `_SuggestionCard` maison remplacée par la vraie `TravelerCard` (note + capacité + cohérence visuelle, favoris/badge urgent gratuits) — nécessite de mapper `RematchSuggestionModel` → `AnnouncementModel` ou de fetcher les annonces par id.
- « Envoyer une demande » → flux de création de bid existant (comme aujourd'hui) + `logEvent(AnalyticsEvents.rematchAccepted)` (event déclaré jamais tiré) avec propriétés `{count: suggestions.length}` — pas de PII.
- État vide : « Aucun voyageur disponible dans les 72h — votre remboursement est traité » (même texte que la notification), CTA « Voir d'autres trajets » → recherche home corridor pré-rempli (nice-to-have si simple, sinon retour).
- État chargement/erreur standards.

### 4.5 Tests front
- Bloc : fetch par id, états loading/success/empty/error.
- Widget écran : liste TravelerCard, état vide conforme, analytics tiré au tap « Envoyer une demande ».
- Routing : les 2 tables notifient la bonne route avec/sans `cancellationId`.
- CTA billet : visible sur bid CANCELLED type trajet annulé, absent sur flux retour.

## 5. Hors périmètre (YAGNI)

- Re-matching périodique post-annulation (les suggestions sont figées au moment de l'annulation ; l'écran re-fetch les données live des annonces).
- Expiry/lifecycle des suggestions (VIEWED/EXPIRED), scheduler.
- Scoring pondéré (`computeMatchScore`) — tri simple date+note suffit.
- SMS fallback pour cette notification (reste non-critique côté ACK).
- Rematch pour les demandes d'envoi (package requests) — uniquement les bids sur trajets annulés.

## 6. Ordre de livraison

1. **PR back** : RematchService + event enrichi + notification + DTO enrichi + tests.
2. **PR front** : route self-fetch + deep links + CTA + écran + analytics + tests.

(Le front peut tomber en marche dégradée si le back n'est pas déployé : sans `cancellationId` dans le payload, aucune navigation — comportement actuel.)
