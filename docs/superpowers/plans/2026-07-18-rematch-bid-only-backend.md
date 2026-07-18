# Rematch bid-only (backend) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Déclencher le rematch (suggestions + notification enrichie + exposition BidResponse) quand le voyageur annule le transport d'un colis ou refuse une demande payée, sans annulation du trajet.

**Architecture:** `BidService` (matching/) pose un flag `rematchEligible` sur le `BidRejectedEvent` existant → nouveau listener synchrone `cancellation/BidLostRematchListener` crée la `CancellationEntity` + réutilise `RematchService.generateForCancellations` → publie `BidLostRematchPreparedEvent` → `NotificationDispatcher` (AFTER_COMMIT) envoie la notification enrichie et saute la générique.

**Tech Stack:** Spring Boot 3.4, Java 21, JPA. Repo `dony-back`, branche `feature/rematch-auto` (PR #113 existante).

**Spec :** `dony_app/docs/superpowers/specs/2026-07-18-rematch-bid-only-design.md` (textes exacts §2)

## Global Constraints

- Déclencheurs : cancelBid initié par le VOYAGEUR (bid ACCEPTED/PAYMENT_ESCROWED) ; rejectBid utilisateur (non système) sur bid PAYMENT_ESCROWED. Tout le reste exclu (sender cancel, cash PENDING, rejectBidBySystem, no-shows, refuseParcel, cancelAfterHandover).
- UNE seule notification (générique sautée quand eligible), type `BID_REJECTED` conservé, `cancellationId` dans data seulement si count > 0. Textes EXACTS de la spec §2.
- `RematchService.generateForCancellations` réutilisé TEL QUEL (aucune modification de sa logique).
- Cross-package via Spring Events uniquement. Le listener cancellation/ peut lire les repositories matching/ (précédent existant).
- AUCUNE migration Flyway. Jamais commit sur main. Pas de Co-Authored-By. `./mvnw test` vert.

---

### Task 1: Flag rematchEligible sur BidRejectedEvent + pose dans BidService

**Files:**
- Modify: `src/main/java/com/dony/api/matching/events/BidRejectedEvent.java`
- Modify: `src/main/java/com/dony/api/matching/BidService.java` (cancelBid ~:634-698, rejectBid ~:554, rejectBidBySystem ~:571, doRejectBid ~:585)
- Test: `src/test/java/com/dony/api/matching/BidServiceTest.java`

**Interfaces:**
- Produces: `BidRejectedEvent` avec `getAnnouncementId()` (UUID, nullable), `isRematchEligible()` (boolean). Constructeur legacy 3 args préservé (`announcementId=null`, `rematchEligible=false`). Nouveau constructeur 5 args `(bidId, senderId, reason, announcementId, rematchEligible)`.
- Consumed by: Task 2 (listener), Task 3 (dispatcher skip).

- [ ] **Step 1: Écrire les tests qui échouent** — dans `BidServiceTest`, capturer l'event publié (`ArgumentCaptor<BidRejectedEvent>` sur l'eventPublisher mocké) :

```java
// cancelBid par le voyageur, bid ACCEPTED → eligible
cancelBid_byTraveler_onAcceptedBid_publishesRematchEligibleEvent()
// assert captor.getValue().isRematchEligible() == true
// assert captor.getValue().getAnnouncementId().equals(announcement.getId())

// cancelBid par le voyageur, bid PAYMENT_ESCROWED → eligible
cancelBid_byTraveler_onEscrowedBid_publishesRematchEligibleEvent()

// cancelBid par le SENDER (même bid ACCEPTED) → NON eligible
cancelBid_bySender_publishesNonEligibleEvent()

// cancelBid par le voyageur, bid PENDING → NON eligible (pas de transport perdu confirmé)
cancelBid_byTraveler_onPendingBid_publishesNonEligibleEvent()

// rejectBid voyageur sur PAYMENT_ESCROWED → eligible
rejectBid_onEscrowedBid_publishesRematchEligibleEvent()

// rejectBid sur bid cash PENDING (isOffPlatformPending) → NON eligible
rejectBid_onOffPlatformPendingBid_publishesNonEligibleEvent()

// rejectBidBySystem sur PAYMENT_ESCROWED → NON eligible
rejectBidBySystem_publishesNonEligibleEvent()
```

- [ ] **Step 2: Run pour vérifier l'échec** — `./mvnw test -Dtest=BidServiceTest` → FAIL (méthodes inexistantes sur l'event).

- [ ] **Step 3: Implémenter** —

`BidRejectedEvent.java` (champ additif, constructeurs chaînés) :

```java
public class BidRejectedEvent {
    private final UUID bidId;
    private final UUID senderId;
    private final String reason;
    private final UUID announcementId;      // nullable (legacy)
    private final boolean rematchEligible;

    public BidRejectedEvent(UUID bidId, UUID senderId, String reason) {
        this(bidId, senderId, reason, null, false);
    }

    public BidRejectedEvent(UUID bidId, UUID senderId, String reason,
                            UUID announcementId, boolean rematchEligible) {
        this.bidId = bidId;
        this.senderId = senderId;
        this.reason = reason;
        this.announcementId = announcementId;
        this.rematchEligible = rematchEligible;
    }
    // getters existants + getAnnouncementId() + isRematchEligible()
}
```

`BidService.cancelBid` — capturer le statut AVANT `bid.setStatus(CANCELLED)` :

```java
BidStatus statusBeforeCancel = bid.getStatus();
...
boolean rematchEligible = isTraveler
        && (statusBeforeCancel == BidStatus.ACCEPTED
            || statusBeforeCancel == BidStatus.PAYMENT_ESCROWED);
eventPublisher.publishEvent(new BidRejectedEvent(
        bid.getId(), bid.getSenderId(), reason,
        bid.getAnnouncementId(), rematchEligible));
```

`doRejectBid` — nouveau paramètre `boolean systemInitiated` (rejectBid passe `false`, rejectBidBySystem passe `true`) :

```java
boolean rematchEligible = !systemInitiated && !isOffPlatformPending;
eventPublisher.publishEvent(new BidRejectedEvent(
        bid.getId(), bid.getSenderId(), bid.getRejectionReason(),
        bid.getAnnouncementId(), rematchEligible));
```

(`requireBidStatus(bid, PAYMENT_ESCROWED)` garantit déjà que le chemin non-off-platform est un bid payé.)

- [ ] **Step 4: Run vert** — `./mvnw test -Dtest=BidServiceTest` → PASS. Vérifier par grep qu'AUCUN autre call site ne construit `BidRejectedEvent` (sinon les mettre à jour avec le constructeur legacy).

- [ ] **Step 5: Commit** — `feat(matching): flag rematchEligible sur BidRejectedEvent (annulation/refus voyageur d'un bid payé)`

---

### Task 2: BidLostRematchListener (cancellation/) — cancellation + suggestions + event enrichi

**Files:**
- Modify: `src/main/java/com/dony/api/cancellation/CancellationReason.java` (+2 valeurs)
- Create: `src/main/java/com/dony/api/cancellation/events/BidLostRematchPreparedEvent.java`
- Create: `src/main/java/com/dony/api/cancellation/BidLostRematchListener.java`
- Test: `src/test/java/com/dony/api/cancellation/BidLostRematchListenerTest.java`

**Interfaces:**
- Consumes: `BidRejectedEvent` (Task 1), `RematchService.generateForCancellations(AnnouncementEntity, List<BidEntity>, List<CancellationEntity>) → Map<UUID, RematchInfo(cancellationId, suggestionCount)>` (existant, NE PAS modifier).
- Produces: `BidLostRematchPreparedEvent(UUID senderId, UUID bidId, UUID cancellationId, int suggestionCount, boolean cancelledByTraveler)` — record ou classe simple, consommé par Task 3.
- `CancellationReason` : + `BID_CANCELLED_BY_TRAVELER`, + `BID_REJECTED_AFTER_PAYMENT`.

- [ ] **Step 1: Tests qui échouent** — `BidLostRematchListenerTest` (MockitoExtension, mocks repos + RematchService + ApplicationEventPublisher) :

```java
// eligible + reason CANCELLED_BY_TRAVELER → CancellationEntity créée
//   (bidId, cancelledBy=travelerId de l'annonce, reason=BID_CANCELLED_BY_TRAVELER.name(), scope HANDOVER défaut)
//   + generateForCancellations(announcement, [bid], [cancellation]) vérifié args exacts (isSameAs / captor)
//   + BidLostRematchPreparedEvent publié avec cancellationId + count de la map retournée + cancelledByTraveler=true
onBidRejected_eligibleCancel_createsCancellationAndPublishesPrepared()

// eligible + reason quelconque ≠ CANCELLED_BY_TRAVELER (refus payé) → reason=BID_REJECTED_AFTER_PAYMENT, cancelledByTraveler=false
onBidRejected_eligibleReject_usesRejectReason()

// non eligible → AUCUNE interaction (verifyNoInteractions repos/rematchService, aucun event publié)
onBidRejected_notEligible_doesNothing()

// eligible mais count 0 (map avec suggestionCount=0) → event publié avec count=0
onBidRejected_zeroSuggestions_publishesCountZero()

// annonce introuvable (deleted) → pas d'exception, rien de publié (log warn) — l'annulation ne doit pas casser
onBidRejected_missingAnnouncement_doesNotThrow()
```

- [ ] **Step 2: Run FAIL** — `./mvnw test -Dtest=BidLostRematchListenerTest` → classe inexistante.

- [ ] **Step 3: Implémenter** —

```java
@Component
public class BidLostRematchListener {
    // injections : BidRepository, AnnouncementRepository (lecture cross-package OK),
    // CancellationRepository, RematchService, ApplicationEventPublisher

    /**
     * Synchrone, même transaction que cancelBid/rejectBid : la cancellation et les
     * suggestions committent atomiquement avec le changement de statut du bid
     * (même garantie que la génération dans cancelTrip).
     */
    @EventListener
    public void onBidRejected(BidRejectedEvent event) {
        if (!event.isRematchEligible()) return;
        // charge bid + announcement (via event.getAnnouncementId(), fallback bid.getAnnouncementId())
        // si annonce absente → log.warn + return (jamais d'exception : le refund AFTER_COMMIT dépend du commit)
        boolean cancelledByTraveler = "CANCELLED_BY_TRAVELER".equals(event.getReason());
        CancellationEntity cancellation = new CancellationEntity();
        cancellation.setBidId(event.getBidId());
        cancellation.setCancelledBy(announcement.getTravelerId());
        cancellation.setReason(cancelledByTraveler
                ? CancellationReason.BID_CANCELLED_BY_TRAVELER.name()
                : CancellationReason.BID_REJECTED_AFTER_PAYMENT.name());
        cancellationRepository.save(cancellation);

        Map<UUID, RematchService.RematchInfo> bySender = rematchService
                .generateForCancellations(announcement, List.of(bid), List.of(cancellation));
        RematchService.RematchInfo info = bySender.get(bid.getSenderId());
        int count = info != null ? info.suggestionCount() : 0;

        eventPublisher.publishEvent(new BidLostRematchPreparedEvent(
                bid.getSenderId(), bid.getId(), cancellation.getId(), count, cancelledByTraveler));
    }
}
```

⚠️ Aligner les setters de `CancellationEntity` sur ceux réellement utilisés par `CancellationService.cancelTrip` (~:119-131) — mêmes champs obligatoires (announcementId ? refundStatus ? vérifier sur place et reproduire), scope laissé au défaut HANDOVER.

- [ ] **Step 4: Run vert** — `./mvnw test -Dtest='BidLostRematchListenerTest,RematchServiceTest,CancellationServiceTest'` → PASS.

- [ ] **Step 5: Commit** — `feat(cancellation): rematch sur annulation/refus voyageur d'un bid payé (listener + reasons)`

---

### Task 3: NotificationDispatcher — skip générique + notification enrichie

**Files:**
- Modify: `src/main/java/com/dony/api/notifications/NotificationDispatcher.java` (`onBidRejected` ~:112-117 + nouvelle méthode)
- Test: `src/test/java/com/dony/api/notifications/NotificationDispatcherTest.java`

**Interfaces:**
- Consumes: `BidRejectedEvent.isRematchEligible()` (Task 1), `BidLostRematchPreparedEvent` (Task 2).

- [ ] **Step 1: Tests qui échouent** (appel direct des méthodes, pattern existant du fichier) :

```java
// eligible → onBidRejected n'envoie RIEN
onBidRejected_rematchEligible_skipsGenericNotification()
// non eligible → générique inchangée ("Demande refusée" / "Le voyageur a refusé votre demande" / {type, bidId})
onBidRejected_notEligible_keepsGenericNotification()

// prepared, cancel, n=3 → titre "Transport annulé",
//   corps "Le voyageur a annulé le transport de votre colis — remboursement en cours. 3 voyageurs alternatifs disponibles",
//   data {type: BID_REJECTED, bidId, cancellationId}
onBidLostRematchPrepared_cancelWithSuggestions_notifiesWithDeepLink()
// prepared, cancel, n=1 → singulier "1 voyageur alternatif disponible"
onBidLostRematchPrepared_singleSuggestion_usesSingularWording()
// prepared, cancel, n=0 → "Le voyageur a annulé le transport de votre colis — votre remboursement est en cours", data SANS cancellationId
onBidLostRematchPrepared_cancelZero_refundOnlyBody()
// prepared, reject, n=2 → titre "Demande refusée",
//   "Le voyageur a refusé votre demande — remboursement en cours. 2 voyageurs alternatifs disponibles" + cancellationId
onBidLostRematchPrepared_rejectWithSuggestions_usesRejectWording()
// prepared, reject, n=0 → "Le voyageur a refusé votre demande — votre remboursement est en cours", SANS cancellationId
onBidLostRematchPrepared_rejectZero_refundOnlyBody()
```

- [ ] **Step 2: Run FAIL** — `./mvnw test -Dtest=NotificationDispatcherTest`.

- [ ] **Step 3: Implémenter** —

```java
@EventListener @Async
public void onBidRejected(BidRejectedEvent event) {
    if (event.isRematchEligible()) return; // remplacée par onBidLostRematchPrepared
    ... // corps existant inchangé
}

// Même pattern AFTER_COMMIT que onTripCancelled (deep link jamais avant commit).
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
@Async
public void onBidLostRematchPrepared(BidLostRematchPreparedEvent event) {
    String title = event.cancelledByTraveler() ? "Transport annulé" : "Demande refusée";
    String prefix = event.cancelledByTraveler()
            ? "Le voyageur a annulé le transport de votre colis"
            : "Le voyageur a refusé votre demande";
    int n = event.suggestionCount();
    if (n > 0) {
        notifyUser(event.senderId(), title,
                prefix + " — remboursement en cours. " + n
                        + " voyageur" + (n > 1 ? "s" : "") + " alternatif" + (n > 1 ? "s" : "")
                        + " disponible" + (n > 1 ? "s" : ""),
                Map.of("type", "BID_REJECTED",
                       "bidId", event.bidId().toString(),
                       "cancellationId", event.cancellationId().toString()));
    } else {
        notifyUser(event.senderId(), title,
                prefix + " — votre remboursement est en cours",
                Map.of("type", "BID_REJECTED", "bidId", event.bidId().toString()));
    }
}
```

- [ ] **Step 4: Run vert** — `./mvnw test -Dtest=NotificationDispatcherTest` → PASS.

- [ ] **Step 5: Commit** — `feat(notifications): notification enrichie rematch pour bid annulé/refusé par le voyageur`

---

### Task 4: Discriminant BidResponse étendu (reasons rematch bid-only)

**Files:**
- Modify: `src/main/java/com/dony/api/matching/BidService.java` (`toResponse`, autour de `NON_TRIP_HANDOVER_REASONS` ~:864 et ~:940-970)
- Test: `src/test/java/com/dony/api/matching/BidServiceTest.java`

**Interfaces:**
- Consumes: `CancellationReason.BID_CANCELLED_BY_TRAVELER` / `BID_REJECTED_AFTER_PAYMENT` (Task 2).
- Produces: `BidResponse.tripCancellationId`/`tripCancellationRematchStatus` peuplés aussi pour ces cancellations (annonce NON annulée). Contrat JSON inchangé.

- [ ] **Step 1: Tests qui échouent** :

```java
// bid CANCELLED, annonce ACTIVE, cancellation HANDOVER reason=BID_CANCELLED_BY_TRAVELER, rematchStatus=SUGGESTED
//   → tripCancellationId = id de la cancellation, tripCancellationRematchStatus = "SUGGESTED"
toResponse_bidCancelledByTraveler_populatesRematchCancellationFields()
// bid REJECTED, reason=BID_REJECTED_AFTER_PAYMENT → champs peuplés
toResponse_bidRejectedAfterPayment_populatesRematchCancellationFields()
// contrôle : reason=SENDER_NO_SHOW + annonce ACTIVE → champs null (comportement existant préservé)
```

- [ ] **Step 2: Run FAIL**.

- [ ] **Step 3: Implémenter** — dans `toResponse`, étendre la condition existante :

```java
private static final Set<String> REMATCH_BID_REASONS = Set.of(
        CancellationReason.BID_CANCELLED_BY_TRAVELER.name(),
        CancellationReason.BID_REJECTED_AFTER_PAYMENT.name());

boolean isRematchCancellation =
        (tripWasCancelled && cancellation.getReason() != null
                && !NON_TRIP_HANDOVER_REASONS.contains(cancellation.getReason()))
        || (cancellation.getReason() != null
                && REMATCH_BID_REASONS.contains(cancellation.getReason()));
```

Mettre à jour la javadoc des champs `BidResponse` : « id de la cancellation ouvrant droit au rematch (trajet annulé OU transport annulé/refusé par le voyageur) ».

- [ ] **Step 4: Run vert** — `./mvnw test -Dtest=BidServiceTest`.

- [ ] **Step 5: Commit** — `feat(matching): expose la cancellation rematch des bids annulés/refusés sans annulation de trajet`

---

### Task 5: Vérification globale + push

- [ ] **Step 1:** `./mvnw test` — suite complète, 0 échec exigé (foreground, attendre la fin).
- [ ] **Step 2:** `git push` (la PR #113 existe déjà — pas de nouvelle PR). Mettre à jour la description de la PR #113 (section « Extension bid-only » : déclencheurs, notification, discriminant) via `gh pr edit 113 --body ...`.
- [ ] **Step 3:** Mettre à jour `docs/stories-done/story-5.6-rematch-automatique.md` (section extension bid-only) et committer.

## Self-review

- Spec §2 : chaque règle a une task (déclencheurs → T1 ; génération/cancellation → T2 ; notification/textes → T3 ; BidResponse → T4 ; migration : aucune ✓).
- Types inter-tasks : `BidRejectedEvent` 5-args (T1) consommé par T2/T3 ; `BidLostRematchPreparedEvent(senderId, bidId, cancellationId, suggestionCount, cancelledByTraveler)` produit T2, consommé T3 ; reasons enum T2 consommées T4.
- Point d'attention documenté (T2 Step 3 ⚠️) : champs obligatoires de `CancellationEntity` à aligner sur `cancelTrip` — l'implémenteur vérifie sur place.
