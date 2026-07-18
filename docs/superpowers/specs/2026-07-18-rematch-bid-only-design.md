# Rematch sur transport annulé sans annulation du trajet — Design

**Date :** 2026-07-18
**Statut :** Validé par l'utilisateur (design conversationnel)
**Portée :** Extension de la feature rematch (spec `2026-07-18-rematch-auto-design.md`) — mêmes branches/PRs (`feature/rematch-auto`, back #113 + front #158)
**Référence produit :** extension de Story 5.6 (FR31)

---

## 1. Problème & objectif

Le rematch automatique ne couvre que l'annulation du trajet entier (`cancelTrip`). Quand le voyageur annule le transport d'un seul colis (`cancelBid`) ou refuse une demande déjà payée (`rejectBid` sur `PAYMENT_ESCROWED`), l'expéditeur est remboursé mais ne reçoit aucune suggestion d'alternative — notification générique « Demande refusée », aucune trace `cancellations`, aucun CTA.

Objectif : même chaîne complète (suggestions → notification avec deep link → écran alternatives → nouvelle demande) pour ces deux cas, en réutilisant l'infrastructure rematch existante.

## 2. Règles métier (verrouillées)

| Règle | Valeur |
|---|---|
| Déclencheurs | (a) `cancelBid` initié par le **voyageur** (bid `ACCEPTED`/`PAYMENT_ESCROWED`) ; (b) `rejectBid`/`doRejectBid` initié par le **voyageur** sur bid `PAYMENT_ESCROWED` |
| Exclus | annulation par l'expéditeur ; refus d'une demande non payée (cash/Wave/OM `PENDING`) ; `rejectBidBySystem` (automatisations) ; no-shows ; `refuseParcel` ; `cancelAfterHandover` (flux retour) |
| Génération | identique à `cancelTrip` : `RematchService.generateForCancellations` réutilisé tel quel — fenêtre `[aujourd'hui UTC, departureDate du trajet concerné + 3j]` bornes incluses, capacité `availableKg ≥ weightKg` (filtre omis si GRID `weightKg` null), exclusions (l'annonce du bid, TOUTES les annonces du voyageur fautif, non-ACTIVE, `publicOrOpenSurplus`, `notBlockedBy`), tri date puis note, limite 5, `rematch_status → SUGGESTED` |
| Cancellation | une `CancellationEntity` créée (scope `HANDOVER` défaut), reason `BID_CANCELLED_BY_TRAVELER` ou `BID_REJECTED_AFTER_PAYMENT` (nouvelles valeurs enum) |
| Notification | type `BID_REJECTED` conservé (pas de nouveau type), UNE seule notification (la générique « Demande refusée » est remplacée, pas doublée), `cancellationId` dans data seulement si count > 0 |
| Remboursement | inchangé — `BidRejectedEventListener` (payments) continue de traiter le refund indépendamment |
| Migration | AUCUNE (reason = colonne texte, `UNIQUE(bid_id, scope)` compatible : ces bids n'ont pas encore de ligne HANDOVER) |

**Textes notification :**
- Annulation voyageur, ≥ 1 alternative : titre « Transport annulé », corps « Le voyageur a annulé le transport de votre colis — remboursement en cours. N voyageur(s) alternatif(s) disponible(s) » + `data = {type: BID_REJECTED, bidId, cancellationId}`.
- Annulation voyageur, 0 alternative : titre « Transport annulé », corps « Le voyageur a annulé le transport de votre colis — votre remboursement est en cours », data sans `cancellationId`.
- Refus payé, ≥ 1 alternative : titre « Demande refusée », corps « Le voyageur a refusé votre demande — remboursement en cours. N voyageur(s) alternatif(s) disponible(s) » + `cancellationId`.
- Refus payé, 0 alternative : titre « Demande refusée », corps « Le voyageur a refusé votre demande — votre remboursement est en cours », sans `cancellationId`.
- Singulier/pluriel : même règle que TRIP_CANCELLED (`n > 1 ? "s" : ""` sur voyageur/alternatif/disponible).

## 3. Backend (architecture Spring Events only)

1. **`BidRejectedEvent` enrichi (additif)** : + `boolean rematchEligible` (+ `UUID announcementId` pour éviter un reload ambigu). Constructeur existant préservé (`rematchEligible=false`). `BidService.cancelBid` pose `rematchEligible=true` si initiateur voyageur ET statut départ `ACCEPTED`/`PAYMENT_ESCROWED` ; `doRejectBid` le pose si `!isOffPlatformPending` (donc `PAYMENT_ESCROWED`) ET appel non-système — `rejectBid` passe un flag, `rejectBidBySystem` jamais.
2. **Nouveau listener `cancellation/BidLostRematchListener`** : `@EventListener` synchrone (même transaction que le service appelant, comme la génération dans `cancelTrip`). Si `event.rematchEligible` : charge bid + annonce, crée la `CancellationEntity` (reason selon `event.reason` : `CANCELLED_BY_TRAVELER` → `BID_CANCELLED_BY_TRAVELER`, sinon → `BID_REJECTED_AFTER_PAYMENT`), appelle `rematchService.generateForCancellations(announcement, List.of(bid), List.of(cancellation))`, publie `BidLostRematchPreparedEvent(senderId, bidId, cancellationId, suggestionCount, cancelledByTraveler)`.
3. **`NotificationDispatcher`** : `onBidRejected` saute quand `event.rematchEligible` (le nouveau chemin prend le relais). Nouveau `onBidLostRematchPrepared` en `@TransactionalEventListener(AFTER_COMMIT) @Async` (même pattern que `onTripCancelled`) avec les textes §2.
4. **`CancellationReason`** : + `BID_CANCELLED_BY_TRAVELER`, + `BID_REJECTED_AFTER_PAYMENT`.
5. **`BidResponse`** : les champs existants `tripCancellationId`/`tripCancellationRematchStatus` sont aussi peuplés quand la cancellation HANDOVER du bid a une reason ∈ {`BID_CANCELLED_BY_TRAVELER`, `BID_REJECTED_AFTER_PAYMENT`} (l'annonce n'est PAS annulée dans ce cas). Javadoc mise à jour : « cancellation ouvrant droit au rematch ». Zéro changement de contrat JSON.
6. **Sécurité/permission** : `GET /cancellations/{id}/rematch-suggestions` inchangé (participant-only — l'expéditeur du bid est participant de la cancellation).

### Tests back
- `BidServiceTest` : flag `rematchEligible` posé/non posé selon les 6 cas (voyageur cancel accepté/payé → oui ; sender cancel → non ; reject payé voyageur → oui ; reject cash PENDING → non ; reject système → non) ; discriminant `toResponse` étendu (bid REJECTED/CANCELLED avec cancellation nouvelle reason → champs peuplés ; annonce ACTIVE).
- `BidLostRematchListenerTest` : création cancellation + reason correcte + délégation `generateForCancellations` (args exacts) + event enrichi publié avec le bon count ; rien quand `rematchEligible=false`.
- `NotificationDispatcherTest` : skip du générique quand eligible ; les 4 corps §2 (cancel/reject × ≥1/0) + singulier n=1 + présence/absence `cancellationId`.

## 4. Frontend

1. **Routing notification** (les 2 tables — `notification_service._routeForMessage` + `notification_bottom_sheet.routeForNotification`) : `BID_REJECTED` + `cancellationId` présent et UUID valide (`_isUuid`) → `/cancellations/{id}/rematch` ; sinon comportement actuel (`/bids/{bidId}`).
2. **Billet — bid `REJECTED`** : le CTA « Voir les trajets alternatifs » existe déjà pour les bids `CANCELLED` (`_CancelledBlock`) et fonctionne sans changement (mêmes champs `BidResponse`). L'ajouter au bloc du statut `REJECTED` du billet avec la même condition 3 clauses (`isSender && tripCancellationId != null && tripCancellationRematchStatus == 'SUGGESTED'`), même style/navigation.
3. **Écran alternatives** : inchangé (self-fetching par cancellationId).

### Tests front
- Routing : les 2 tables, `BID_REJECTED` avec cancellationId valide → route rematch ; sans → `/bids/{id}` ; non-UUID → `/bids/{id}`.
- Billet : CTA visible sur bid REJECTED avec les 3 clauses ; chaque clause tuée par un test (pattern existant du bloc CANCELLED) ; absent pour non-sender/champs null/status ≠ SUGGESTED.
- `BidModel` : aucun changement de modèle (champs déjà présents).

## 5. Hors périmètre (YAGNI)

- Rematch sur no-show voyageur (`VoyageurNoShowEvent`) — mécanique de signalement propre.
- Rematch sur `refuseParcel`, `cancelAfterHandover` (flux retour du colis).
- Rematch pour rejets système (`rejectBidBySystem`).
- Pénalité de réputation du voyageur qui annule un bid (hors scope rematch).
- Correction du type `TRIP_CANCELLED` réutilisé par `VoyageurNoShowEvent` (préexistant, sans danger : pas de cancellationId → pas de deep link).

## 6. Ordre de livraison

Sur les branches/PRs existantes : back d'abord (PR #113), puis front (PR #158). Le front reste en marche dégradée sans le back (pas de `cancellationId` → route `/bids/{id}` actuelle).
