# Signalement d'absence à la livraison (no-show arrivée) — Design

**Date :** 2026-07-15
**Statut :** validé (maquette : https://claude.ai/code/artifact/df21f560-f287-4598-b0c1-e82276ae1db8)
**Portée :** dony-back (packages `cancellation/` + `disputes/`) + dony_app (feature `tracking/` — écran suivi envoi)

## Contexte

dony gère déjà un no-show **au départ** (expéditeur absent à la remise voyageur, ou voyageur absent) via le package `cancellation/` : signalement → délai de contestation (`noShowContestationHours`) → contestation ouvre un litige (`SENDER_NO_SHOW_CONTESTED`, `refundFrozen=true`), sans contestation → confirmation manuelle admin ou auto.

**Rien n'existe côté ARRIVÉE.** Le seul mécanisme post-remise est `cancel-after-handover` (annulation après remise, remboursement intégral automatique, code de retour 3 jours) — inadapté ici : il rembourse l'expéditeur d'office, alors qu'un no-show à la livraison peut être la faute de l'une ou l'autre partie. Cette feature ajoute un signalement d'absence symétrique, **au moment de la remise au destinataire**, sans jamais déclencher de paiement/remboursement automatique — l'admin tranche systématiquement (décision produit explicite).

## Décisions validées

- **Symétrie complète** : le voyageur peut signaler « destinataire absent » ; l'expéditeur peut signaler « le voyageur ne livre pas ».
- **Conséquence** : contestation → litige (même mécanique que le no-show départ). **Jamais de capture/remboursement automatique**, avec ou sans contestation — le paiement reste gelé (`refundFrozen=true`) jusqu'à décision admin dans tous les cas, y compris si la deadline de contestation expire sans réponse (litige ouvert en type « non contesté »).
- **Délai de contestation** : réutilise `noShowContestationHours` (config existante, `CommissionProperties`), pas de nouveau paramètre — symétrie avec le départ, ajustable plus tard si besoin s'en fait sentir.
- **Point d'entrée** : CTA sur l'écran de détail/suivi de l'envoi (pas de nouvel écran de hub).

## Backend (dony-back)

### 1. `CancellationEntity` — scope DELIVERY

Ajout d'un champ `scope` (`HANDOVER` par défaut, `DELIVERY` nouveau) sur `CancellationEntity`. Un seul enregistrement `DELIVERY` par bid (comme aujourd'hui un seul `HANDOVER`). Migration `V(n+1)__cancellations_delivery_scope.sql` : colonne `scope VARCHAR(20) NOT NULL DEFAULT 'HANDOVER'`.

### 2. Endpoints (`CancellationController`, package `cancellation/`)

- `POST /cancellations/bids/{bidId}/report-delivery-noshow` — rôle `TRAVELER`. Le voyageur signale que le destinataire n'est pas venu à la remise.
- `POST /cancellations/bids/{bidId}/report-traveler-delivery-noshow` — rôle `SENDER`. L'expéditeur signale que le voyageur ne livre pas / est injoignable.
- `POST /cancellations/bids/{bidId}/contest-delivery-noshow` — la partie adverse à celle qui a signalé (TRAVELER si signalé par SENDER, et inversement), avant la deadline.

**Gardes communes** (dans `CancellationService`, nouvelles méthodes miroir des méthodes départ existantes) :
- bid au statut `IN_TRANSIT`.
- Date de départ du trajet déjà passée (le voyage a eu lieu — condition de cohérence temporelle, équivalent du `handoverWindowEnd` mais côté arrivée : pas de champ dédié requis, `AnnouncementEntity.departureDate` suffit puisqu'il n'existe qu'un scénario "en transit").
- Pas de `CancellationEntity` scope `DELIVERY` déjà `PENDING_CONFIRMATION` ou `CONTESTED` pour ce bid (idempotence, 409 sinon).

**Signalement** (`reportDeliveryNoShow` / `reportTravelerDeliveryNoShow`) : crée `CancellationEntity(scope=DELIVERY, noShowStatus=PENDING_CONFIRMATION, contestationDeadline=now+noShowContestationHours)`. Notification FCM à l'autre partie. Audit log (`DELIVERY_NOSHOW_REPORTED_BY_TRAVELER` / `..._BY_SENDER`).

**Contestation** (`contestDeliveryNoShow`) : vérifie que l'appelant est bien l'autre partie et que la deadline n'est pas dépassée, passe `noShowStatus=CONTESTED`, publie `DisputeOpenedEvent` avec un type dédié :
- `RECIPIENT_NO_SHOW_CONTESTED` si le voyageur avait signalé (litige : le voyageur affirme absence destinataire, l'expéditeur conteste).
- `TRAVELER_DELIVERY_NO_SHOW_CONTESTED` si l'expéditeur avait signalé.

`DisputeService.openDeliveryNoShowDispute` (nouvelle méthode, miroir de `openSenderNoShowDispute`) : `refundFrozen=true`, un seul dispute par bid comme aujourd'hui.

### 3. Scheduler — non-contestation

Nouveau `@Scheduled` (cron horaire, idempotent, dans `cancellation/`, à côté des schedulers existants) : trouve les `CancellationEntity(scope=DELIVERY, noShowStatus=PENDING_CONFIRMATION, contestationDeadline < now)`, ouvre quand même un litige (type `RECIPIENT_NO_SHOW` / `TRAVELER_DELIVERY_NO_SHOW`, sans le suffixe `_CONTESTED`), `refundFrozen=true`. **Aucune capture ni remboursement déclenché** — l'admin tranche dans tous les cas. Audit log `DELIVERY_NOSHOW_UNCONTESTED_DISPUTE_OPENED`.

### 4. `DisputeResponse` / `DisputeService.getDisputesForUser`

Aucun changement de shape — les 4 nouveaux `type` (`RECIPIENT_NO_SHOW_CONTESTED`, `TRAVELER_DELIVERY_NO_SHOW_CONTESTED`, `RECIPIENT_NO_SHOW`, `TRAVELER_DELIVERY_NO_SHOW`) passent par le même DTO enrichi déjà livré (feature « Mes litiges »). Le mapping bid→annonce→villes/poids/autre-partie fonctionne à l'identique.

### 5. Tests

- `CancellationServiceTest` : gardes (statut bid, deadline, idempotence), signalement des deux sens, contestation des deux sens (bonne partie / mauvaise partie rejetée), scheduler (litige ouvert si deadline dépassée, idempotent si rejoué).
- `CancellationControllerTest` : rôles corrects par endpoint, 403 si mauvais rôle, 404/422 sur gardes.
- `DisputeServiceTest` : les 4 nouveaux types se mappent sans régression sur le DTO existant.

## Flutter (dony_app)

### 1. Écran détail/suivi de l'envoi

Ajout d'une section « Remise au destinataire » (voyageur) / « Remise à votre destinataire » (expéditeur), visible seulement quand bid `IN_TRANSIT` + trajet déjà parti et qu'aucun signalement DELIVERY n'existe encore :
- Voyageur : cellule « Signaler l'absence du destinataire » (icône `user`, teinte danger).
- Expéditeur : cellule « Le voyageur ne livre pas » (icône `plane`, teinte danger).

Tap → bottom sheet de confirmation (motif optionnel, bandeau rappelant le gel du paiement, boutons en `stickyBottom` per règle projet) → dispatch de l'action correspondante.

### 2. Bannière post-signalement

Remplace la cellule CTA une fois un signalement DELIVERY existant sur le bid :
- Pour l'auteur du signalement : bannière neutre « Absence signalée » + compte à rebours jusqu'à la deadline de contestation.
- Pour l'autre partie : bannière rouge « {Autre partie} signale une absence » + CTA « Contester ce signalement » en `stickyBottom`, tant que la deadline n'est pas dépassée.

### 3. BLoC

Nouveaux events sur le bloc existant qui gère déjà le détail d'envoi (à identifier précisément en phase de plan : probablement un cubit/bloc dédié au détail bid, à réutiliser plutôt que dupliquer) : `DeliveryNoShowReportRequested`, `DeliveryNoShowContestRequested`. Repository : 3 nouveaux appels Dio miroir des appels no-show départ existants.

### 4. Labels litiges

Ajout des 4 nouveaux types dans `dispute_labels.dart` :
| type backend | libellé |
|---|---|
| `RECIPIENT_NO_SHOW_CONTESTED` / `RECIPIENT_NO_SHOW` | Absence du destinataire |
| `TRAVELER_DELIVERY_NO_SHOW_CONTESTED` / `TRAVELER_DELIVERY_NO_SHOW` | Défaut de livraison |

### 5. Analytics

- `delivery_noshow_reported` (propriété `by`: sender/traveler).
- `delivery_noshow_contested` (propriété `by`).
- Déclarés dans `AnalyticsEvents`, tirés dans le bloc, `unawaited`, pas de PII.

### 6. Tests

- Bloc/repository : mêmes patterns que le no-show départ (`cancellation_bloc_test.dart` comme référence).
- Widget tests écran détail : cellule visible/masquée selon statut+rôle, bottom sheet, bannières des deux points de vue, contestation.
- Couverture ≥ 90 % sur le code nouveau.

## Hors scope (explicitement)

- Nouveau paramètre de délai spécifique à l'arrivée (réutilise `noShowContestationHours`).
- Toute capture ou remboursement automatique lié à ce flux (contrairement à `cancel-after-handover`).
- Nouvel écran dédié — tout passe par l'écran de détail d'envoi existant et l'écran « Mes litiges » déjà livré.
- Notification SMS (FCM seul, comme le no-show départ).
