# Signalement d'absence à la livraison — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à l'expéditeur et au voyageur de signaler une absence à la remise du colis au destinataire (arrivée), symétrique au no-show du départ, avec contestation → litige et **jamais de paiement automatique**.

**Architecture:** Backend : le package `cancellation/` gagne un `scope` (`HANDOVER` existant / `DELIVERY` nouveau) sur `CancellationEntity`, avec 3 nouveaux endpoints (signaler ×2, contester) et un scheduler pour le cas non-contesté. `disputes/` gagne 2 nouveaux types de litige contestés + 2 non-contestés, réutilisant le DTO déjà livré. Frontend : nouvelle section sur l'écran détail d'envoi (cellule discrète → bottom sheet → bannière), réutilisant le `CancellationBloc` existant et l'écran « Mes litiges » déjà livré.

**Tech Stack:** Spring Boot 3.5 / JPA / Mockito · Flutter / flutter_bloc / GoRouter / Dio / GetIt / mocktail / bloc_test / json_serializable.

**Spec :** `docs/superpowers/specs/2026-07-15-delivery-noshow-design.md` (maquette : https://claude.ai/code/artifact/df21f560-f287-4598-b0c1-e82276ae1db8)

## Global Constraints

- 2 repos git séparés : Partie A dans `dony-back` (branche `feature/delivery-noshow-backend`), Partie B dans `dony_app` (branche `feature/delivery-noshow`, déjà créée avec la spec committée).
- Jamais de commit sur `main` ; pas de `Co-Authored-By`.
- **Jamais de paiement/remboursement automatique** pour ce flux — ni au signalement, ni à la contestation, ni à l'expiration du délai sans contestation. L'admin tranche systématiquement (`refundFrozen=true` dans tous les cas).
- Délai de contestation = `commissionProperties.noShowContestationHours()` existant (config actuelle : **24 h**, PAS 48 h — le texte Flutter existant pour le no-show départ dit à tort "48 h", ne pas reproduire cette erreur dans le nouveau code).
- Backend : erreurs RFC 7807 (`DonyBusinessException`/`GlobalExceptionHandler`), pas d'injection de *services* cross-package (repositories OK, précédent `BidService`→`cancellationRepository`), `@PreAuthorize` correct par rôle, schedulers idempotents, tests verts avant tout commit.
- Flutter : BLoC only, GoRouter only, Dio via `ApiClient`, DI GetIt (`registerLazySingleton` data / `registerFactory` bloc), analytics via `AnalyticsService` + noms dans `AnalyticsEvents`, aucune PII, boutons de bottom sheet dans `stickyBottom` (jamais dans le `child` scrollable).
- Vérification tests : TOUJOURS `cmd > log 2>&1; echo "EXIT_CODE=$?" >> log` puis lire le log — jamais `cmd | tail`.
- Couverture ≥ 90 % sur le code nouveau.
- Ne PAS toucher au texte "48 h" existant dans `traveler_hero_card.dart`/`sender_hero_card.dart` (bug pré-existant hors scope).

---

# Partie A — Backend (dony-back)

### Task A1: Cancellation — scope HANDOVER/DELIVERY (fondations, zéro régression)

**Files:**
- Create: `src/main/resources/db/migration/V173__cancellations_delivery_scope.sql`
- Create: `src/main/java/com/dony/api/cancellation/CancellationScope.java`
- Modify: `src/main/java/com/dony/api/cancellation/CancellationEntity.java`
- Modify: `src/main/java/com/dony/api/cancellation/CancellationRepository.java`
- Test: `src/test/java/com/dony/api/cancellation/CancellationRepositoryScopeTest.java`

**Interfaces:**
- Consumes: rien (fondations).
- Produces: `CancellationScope` enum (`HANDOVER`, `DELIVERY`), `CancellationEntity.getScope()/setScope()` (défaut `HANDOVER`), et sur `CancellationRepository` — **méthodes existantes inchangées en signature** (`findByBidId`, `existsByBidIdAndNoShowStatusIn`, `findExpiredPending` filtrent désormais implicitement `scope='HANDOVER'` via `@Query`, zéro fichier appelant à modifier) — plus 3 **nouvelles** méthodes : `findByBidIdAndScope(UUID bidId, CancellationScope scope)`, `existsByBidIdAndScopeAndNoShowStatusIn(UUID bidId, CancellationScope scope, List<CancellationStatus> statuses)`, `findExpiredPendingByScope(CancellationScope scope, OffsetDateTime now)` — utilisées par la Task A3 (report/contest delivery) et A6 (scheduler).

- [ ] **Step 1: Créer la branche**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony-back
git checkout main && git pull origin main --ff-only
git checkout -b feature/delivery-noshow-backend
```

- [ ] **Step 2: Migration**

```sql
-- V173__cancellations_delivery_scope.sql
-- Un bid peut désormais avoir DEUX enregistrements cancellations distincts au
-- cours de sa vie : un HANDOVER (départ, existant) et un DELIVERY (arrivée,
-- nouveau) — ex. un no-show départ contesté puis résolu en faveur du voyageur
-- laisse le bid reprendre son cours jusqu'à l'arrivée, où un nouveau no-show
-- peut survenir. L'unicité passe donc de (bid_id) à (bid_id, scope).

ALTER TABLE cancellations ADD COLUMN scope VARCHAR(20) NOT NULL DEFAULT 'HANDOVER'
    CHECK (scope IN ('HANDOVER', 'DELIVERY'));

ALTER TABLE cancellations DROP CONSTRAINT uq_cancellations_bid_id;
ALTER TABLE cancellations ADD CONSTRAINT uq_cancellations_bid_id_scope UNIQUE (bid_id, scope);
```

- [ ] **Step 3: `CancellationScope` enum**

```java
package com.dony.api.cancellation;

/** HANDOVER = remise expéditeur→voyageur au départ (existant).
 *  DELIVERY = remise voyageur→destinataire à l'arrivée (nouveau). */
public enum CancellationScope {
    HANDOVER,
    DELIVERY
}
```

- [ ] **Step 4: `CancellationEntity` — ajouter le champ scope**

Dans `CancellationEntity.java`, après le champ `noShowStatus` (avant `contestationDeadline`) :

```java
    @Enumerated(EnumType.STRING)
    @Column(name = "scope", nullable = false, length = 20)
    private CancellationScope scope = CancellationScope.HANDOVER;
```

Et les accesseurs, après `getNoShowStatus/setNoShowStatus` :

```java
    public CancellationScope getScope() { return scope; }
    public void setScope(CancellationScope scope) { this.scope = scope; }
```

- [ ] **Step 5: Test rouge — nouvelles méthodes repository**

```java
package com.dony.api.cancellation;

import com.dony.api.matching.BidEntity;
import com.dony.api.matching.BidRepository;
import com.dony.api.matching.BidStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@ActiveProfiles("test")
class CancellationRepositoryScopeTest {

    @Autowired CancellationRepository cancellationRepository;
    @Autowired BidRepository bidRepository;

    @Test
    void aBidCanHaveOneHandoverAndOneDeliveryCancellation() {
        BidEntity bid = persistBid();

        CancellationEntity handover = new CancellationEntity();
        handover.setBidId(bid.getId());
        handover.setCancelledBy(bid.getSenderId());
        handover.setReason("SENDER_NO_SHOW");
        handover.setScope(CancellationScope.HANDOVER);
        cancellationRepository.save(handover);

        CancellationEntity delivery = new CancellationEntity();
        delivery.setBidId(bid.getId());
        delivery.setCancelledBy(bid.getSenderId());
        delivery.setReason("RECIPIENT_NO_SHOW");
        delivery.setScope(CancellationScope.DELIVERY);
        cancellationRepository.save(delivery);

        assertThat(cancellationRepository.findByBidId(bid.getId())).isPresent();
        assertThat(cancellationRepository.findByBidId(bid.getId()).get().getScope())
                .isEqualTo(CancellationScope.HANDOVER);
        assertThat(cancellationRepository.findByBidIdAndScope(bid.getId(), CancellationScope.DELIVERY))
                .isPresent();
        assertThat(cancellationRepository.findByBidIdAndScope(bid.getId(), CancellationScope.DELIVERY).get().getReason())
                .isEqualTo("RECIPIENT_NO_SHOW");
    }

    @Test
    void existsByBidIdAndScopeAndNoShowStatusIn_filtersByScope() {
        BidEntity bid = persistBid();
        CancellationEntity delivery = new CancellationEntity();
        delivery.setBidId(bid.getId());
        delivery.setCancelledBy(bid.getSenderId());
        delivery.setReason("RECIPIENT_NO_SHOW");
        delivery.setScope(CancellationScope.DELIVERY);
        delivery.setNoShowStatus(CancellationStatus.PENDING_CONFIRMATION);
        cancellationRepository.save(delivery);

        assertThat(cancellationRepository.existsByBidIdAndScopeAndNoShowStatusIn(
                bid.getId(), CancellationScope.DELIVERY,
                List.of(CancellationStatus.PENDING_CONFIRMATION))).isTrue();
        assertThat(cancellationRepository.existsByBidIdAndScopeAndNoShowStatusIn(
                bid.getId(), CancellationScope.HANDOVER,
                List.of(CancellationStatus.PENDING_CONFIRMATION))).isFalse();
    }

    @Test
    void findExpiredPendingByScope_onlyReturnsMatchingScope() {
        BidEntity bid = persistBid();
        CancellationEntity delivery = new CancellationEntity();
        delivery.setBidId(bid.getId());
        delivery.setCancelledBy(bid.getSenderId());
        delivery.setReason("RECIPIENT_NO_SHOW");
        delivery.setScope(CancellationScope.DELIVERY);
        delivery.setNoShowStatus(CancellationStatus.PENDING_CONFIRMATION);
        delivery.setContestationDeadline(OffsetDateTime.now().minusHours(1));
        cancellationRepository.save(delivery);

        List<CancellationEntity> expiredDelivery = cancellationRepository
                .findExpiredPendingByScope(CancellationScope.DELIVERY, OffsetDateTime.now());
        List<CancellationEntity> expiredHandover = cancellationRepository
                .findExpiredPendingByScope(CancellationScope.HANDOVER, OffsetDateTime.now());

        assertThat(expiredDelivery).hasSize(1);
        assertThat(expiredHandover).isEmpty();
    }

    private BidEntity persistBid() {
        // Réutilise un helper existant si CancellationRepositoryTest ou un autre
        // test @DataJpaTest du package en possède un ; sinon construire un
        // BidEntity minimal valide (announcementId, senderId, weightKg, status
        // ACCEPTED) et bidRepository.save(). Vérifier `grep -rn "@DataJpaTest" 
        // src/test/java/com/dony/api/cancellation/` pour un fixture existant à
        // réutiliser avant d'en écrire un nouveau.
        BidEntity bid = new BidEntity();
        bid.setAnnouncementId(UUID.randomUUID());
        bid.setSenderId(UUID.randomUUID());
        bid.setWeightKg(new java.math.BigDecimal("5.0"));
        bid.setStatus(BidStatus.IN_TRANSIT);
        bid.setCreatedAt(LocalDateTime.now());
        bid.setUpdatedAt(LocalDateTime.now());
        return bidRepository.save(bid);
    }
}
```

- [ ] **Step 6: Vérifier l'échec**

```bash
./mvnw test -Dtest=CancellationRepositoryScopeTest > /tmp/dony-a1-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a1-red.log
tail -20 /tmp/dony-a1-red.log
```
Attendu : erreur de compilation (`findByBidIdAndScope` n'existe pas, colonne `scope` absente de l'entité tant que Steps 3-4 ne sont pas faits — si déjà faits, le test échoue faute des méthodes repository du Step 7).

- [ ] **Step 7: Réécrire `CancellationRepository.java`**

```java
package com.dony.api.cancellation;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CancellationRepository extends JpaRepository<CancellationEntity, UUID> {
    List<CancellationEntity> findByCancelledBy(UUID userId);
    long countByCancelledBy(UUID userId);

    // ── Scope HANDOVER implicite — préserve le comportement et les signatures
    // existantes (aucun appelant, production ou test, n'a besoin de changer). ──

    @Query("SELECT c FROM CancellationEntity c WHERE c.bidId = :bidId AND c.scope = 'HANDOVER'")
    Optional<CancellationEntity> findByBidId(@Param("bidId") UUID bidId);

    @Query("SELECT COUNT(c) > 0 FROM CancellationEntity c WHERE c.bidId = :bidId " +
           "AND c.scope = 'HANDOVER' AND c.noShowStatus IN :statuses")
    boolean existsByBidIdAndNoShowStatusIn(@Param("bidId") UUID bidId,
                                           @Param("statuses") List<CancellationStatus> statuses);

    @Query("SELECT c FROM CancellationEntity c WHERE c.scope = 'HANDOVER' " +
           "AND c.noShowStatus = 'PENDING_CONFIRMATION' AND c.contestationDeadline < :now")
    List<CancellationEntity> findExpiredPending(@Param("now") OffsetDateTime now);

    // ── Scope explicite — nouveau, utilisé par le flux DELIVERY. ──

    Optional<CancellationEntity> findByBidIdAndScope(UUID bidId, CancellationScope scope);

    boolean existsByBidIdAndScopeAndNoShowStatusIn(UUID bidId, CancellationScope scope,
                                                    List<CancellationStatus> statuses);

    @Query("SELECT c FROM CancellationEntity c WHERE c.scope = :scope " +
           "AND c.noShowStatus = 'PENDING_CONFIRMATION' AND c.contestationDeadline < :now")
    List<CancellationEntity> findExpiredPendingByScope(@Param("scope") CancellationScope scope,
                                                        @Param("now") OffsetDateTime now);

    @Query("SELECT c FROM CancellationEntity c WHERE (:noShowStatus IS NULL OR c.noShowStatus = :noShowStatus)")
    Page<CancellationEntity> findAdminFiltered(@Param("noShowStatus") CancellationStatus noShowStatus, Pageable pageable);
}
```

- [ ] **Step 8: Vérifier que le nouveau test passe, puis la suite complète (preuve de zéro régression)**

```bash
./mvnw test -Dtest=CancellationRepositoryScopeTest > /tmp/dony-a1-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a1-green.log
tail -10 /tmp/dony-a1-green.log
./mvnw test > /tmp/dony-a1-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a1-full.log
grep -E "Tests run|BUILD|EXIT_CODE" /tmp/dony-a1-full.log | tail -5
```
Attendu : `CancellationRepositoryScopeTest` 3/3 vert. Suite complète : **exactement le même nombre de tests qu'avant** (aucun fichier de test existant modifié, `findByBidId`/`existsByBidIdAndNoShowStatusIn`/`findExpiredPending` gardent leurs signatures) — `BUILD SUCCESS`, EXIT_CODE=0.

- [ ] **Step 9: Commit**

```bash
git add src/main/resources/db/migration/V173__cancellations_delivery_scope.sql \
        src/main/java/com/dony/api/cancellation/CancellationScope.java \
        src/main/java/com/dony/api/cancellation/CancellationEntity.java \
        src/main/java/com/dony/api/cancellation/CancellationRepository.java \
        src/test/java/com/dony/api/cancellation/CancellationRepositoryScopeTest.java
git commit -m "feat(cancellation): scope HANDOVER/DELIVERY sur CancellationEntity, zéro régression"
```

### Task A2: Disputes — dispatch par type (fondations, zéro régression)

**Files:**
- Create: `src/main/resources/db/migration/V174__disputes_unique_bid_id_type.sql`
- Modify: `src/main/java/com/dony/api/disputes/DisputeRepository.java`
- Modify: `src/main/java/com/dony/api/disputes/DisputeService.java`
- Modify: `src/main/java/com/dony/api/disputes/events/DisputeOpenedEvent.java`
- Modify: `src/main/java/com/dony/api/disputes/DisputeOpenedEventListener.java`
- Test: `src/test/java/com/dony/api/disputes/DisputeServiceTest.java` (ajout, pas de suppression)
- Test: `src/test/java/com/dony/api/disputes/DisputeOpenedEventListenerTest.java` (nouveau)

**Interfaces:**
- Consumes: rien de la Task A1 directement (fichiers disjoints).
- Produces: `DisputeService.openDeliveryNoShowDispute(UUID bidId, UUID senderId, UUID travelerId, String type) → DisputeEntity`, `DisputeRepository.findByBidIdAndType(UUID bidId, String type)`, `DisputeOpenedEvent(UUID bidId, UUID senderId, UUID travelerId, String type)` (4-arg, le constructeur 3-arg existant reste, défaut `"SENDER_NO_SHOW_CONTESTED"`) — utilisés par la Task A4 (contestation) et A6 (scheduler).

- [ ] **Step 1: Migration**

```sql
-- V174__disputes_unique_bid_id_type.sql
-- Un bid peut avoir un litige de départ (SENDER_NO_SHOW_CONTESTED) ET,
-- plus tard dans sa vie, un litige d'arrivée (RECIPIENT_NO_SHOW_CONTESTED /
-- TRAVELER_DELIVERY_NO_SHOW_CONTESTED / leurs variantes non-contestées).
-- L'unicité passe de (bid_id) à (bid_id, type).

ALTER TABLE disputes DROP CONSTRAINT uq_disputes_bid_id;
ALTER TABLE disputes ADD CONSTRAINT uq_disputes_bid_id_type UNIQUE (bid_id, type);
```

- [ ] **Step 2: `DisputeOpenedEvent` — ajouter le type, préserver l'existant**

```java
package com.dony.api.disputes.events;

import java.util.UUID;

public class DisputeOpenedEvent {
    private final UUID bidId;
    private final UUID senderId;
    private final UUID travelerId;
    private final String type;

    /** Rétrocompatible : litige no-show départ (seul type existant avant cette feature). */
    public DisputeOpenedEvent(UUID bidId, UUID senderId, UUID travelerId) {
        this(bidId, senderId, travelerId, "SENDER_NO_SHOW_CONTESTED");
    }

    public DisputeOpenedEvent(UUID bidId, UUID senderId, UUID travelerId, String type) {
        this.bidId = bidId;
        this.senderId = senderId;
        this.travelerId = travelerId;
        this.type = type;
    }

    public UUID getBidId()      { return bidId; }
    public UUID getSenderId()   { return senderId; }
    public UUID getTravelerId() { return travelerId; }
    public String getType()     { return type; }
}
```

- [ ] **Step 3: `DisputeRepository` — méthode `findByBidId` scope-safe + nouvelle méthode par type**

```java
package com.dony.api.disputes;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DisputeRepository extends JpaRepository<DisputeEntity, UUID> {

    // Préserve le comportement existant (seul type en usage avant cette feature) —
    // aucun appelant existant à modifier.
    @Query("SELECT d FROM DisputeEntity d WHERE d.bidId = :bidId AND d.type = 'SENDER_NO_SHOW_CONTESTED'")
    Optional<DisputeEntity> findByBidId(@Param("bidId") UUID bidId);

    // Nouveau — idempotence par type pour les litiges d'arrivée.
    Optional<DisputeEntity> findByBidIdAndType(UUID bidId, String type);

    List<DisputeEntity> findBySenderIdOrTravelerIdOrderByCreatedAtDesc(UUID senderId, UUID travelerId);

    @Query("SELECT d FROM DisputeEntity d WHERE (:status IS NULL OR d.status = :status) ORDER BY d.createdAt DESC")
    Page<DisputeEntity> findAdminFiltered(@Param("status") String status, Pageable pageable);

    List<DisputeEntity> findAllByCreatedAtBetweenOrderByCreatedAtAsc(
            java.time.LocalDateTime from, java.time.LocalDateTime to);

    List<DisputeEntity> findAllByResolutionTypeAndResolvedAtBetweenOrderByResolvedAtAsc(
            String resolutionType, java.time.OffsetDateTime from, java.time.OffsetDateTime to);
}
```

- [ ] **Step 4: Test rouge — `DisputeService.openDeliveryNoShowDispute`**

Ajouter dans `DisputeServiceTest.java` (ne pas toucher aux tests existants) :

```java
@Test
void openDeliveryNoShowDispute_createsDisputeWithGivenType() {
    UUID bidId = UUID.randomUUID();
    UUID senderId = UUID.randomUUID();
    UUID travelerId = UUID.randomUUID();
    when(disputeRepository.findByBidIdAndType(bidId, "RECIPIENT_NO_SHOW_CONTESTED"))
            .thenReturn(Optional.empty());
    when(disputeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    DisputeEntity result = disputeService.openDeliveryNoShowDispute(
            bidId, senderId, travelerId, "RECIPIENT_NO_SHOW_CONTESTED");

    assertThat(result.getType()).isEqualTo("RECIPIENT_NO_SHOW_CONTESTED");
    assertThat(result.getStatus()).isEqualTo("OPEN");
    assertThat(result.isRefundFrozen()).isTrue();
    assertThat(result.getSenderId()).isEqualTo(senderId);
    assertThat(result.getTravelerId()).isEqualTo(travelerId);
}

@Test
void openDeliveryNoShowDispute_idempotent_returnsExistingIfAlreadyOpen() {
    UUID bidId = UUID.randomUUID();
    DisputeEntity existing = new DisputeEntity();
    existing.setType("TRAVELER_DELIVERY_NO_SHOW");
    when(disputeRepository.findByBidIdAndType(bidId, "TRAVELER_DELIVERY_NO_SHOW"))
            .thenReturn(Optional.of(existing));

    DisputeEntity result = disputeService.openDeliveryNoShowDispute(
            bidId, UUID.randomUUID(), UUID.randomUUID(), "TRAVELER_DELIVERY_NO_SHOW");

    assertThat(result).isSameAs(existing);
    verify(disputeRepository, never()).save(any());
}
```
(Imports déjà présents dans le fichier : `assertThat`, `when`, `verify`, `any`, `Optional`, `UUID` — vérifier `never()` est importé, sinon ajouter `import static org.mockito.Mockito.never;`.)

- [ ] **Step 5: Vérifier l'échec**

```bash
./mvnw test -Dtest=DisputeServiceTest > /tmp/dony-a2-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-red.log
tail -20 /tmp/dony-a2-red.log
```
Attendu : erreur de compilation (`openDeliveryNoShowDispute` n'existe pas).

- [ ] **Step 6: Implémenter `DisputeService.openDeliveryNoShowDispute`**

Dans `DisputeService.java`, après `openSenderNoShowDispute` :

```java
    public DisputeEntity openDeliveryNoShowDispute(UUID bidId, UUID senderId, UUID travelerId, String type) {
        Optional<DisputeEntity> existing = disputeRepository.findByBidIdAndType(bidId, type);
        if (existing.isPresent()) {
            return existing.get();
        }

        DisputeEntity dispute = new DisputeEntity();
        dispute.setBidId(bidId);
        dispute.setSenderId(senderId);
        dispute.setTravelerId(travelerId);
        dispute.setType(type);
        dispute.setStatus(STATUS_OPEN);
        dispute.setRefundFrozen(true);

        DisputeEntity saved = disputeRepository.save(dispute);

        auditService.log("DISPUTE", saved.getId(), "DELIVERY_NOSHOW_DISPUTE_OPENED", senderId,
                Map.of("bidId", bidId.toString(), "travelerId", travelerId.toString(), "type", type));

        return saved;
    }
```

- [ ] **Step 7: Vérifier vert**

```bash
./mvnw test -Dtest=DisputeServiceTest > /tmp/dony-a2-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-green.log
tail -10 /tmp/dony-a2-green.log
```
Attendu : tous verts (existants + 2 nouveaux).

- [ ] **Step 8: `DisputeOpenedEventListener` — dispatch par type + test**

```java
package com.dony.api.disputes;

import com.dony.api.disputes.events.DisputeOpenedEvent;
import org.springframework.context.event.TransactionPhase;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionalEventListener;

public class DisputeOpenedEventListener {

    private final DisputeService disputeService;

    public DisputeOpenedEventListener(DisputeService disputeService) {
        this.disputeService = disputeService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void handleDisputeOpened(DisputeOpenedEvent event) {
        if ("SENDER_NO_SHOW_CONTESTED".equals(event.getType())) {
            disputeService.openSenderNoShowDispute(
                    event.getBidId(), event.getSenderId(), event.getTravelerId());
        } else {
            disputeService.openDeliveryNoShowDispute(
                    event.getBidId(), event.getSenderId(), event.getTravelerId(), event.getType());
        }
    }
}
```

Test (nouveau fichier, aucun test préexistant pour cette classe) :

```java
package com.dony.api.disputes;

import com.dony.api.disputes.events.DisputeOpenedEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.junit.jupiter.api.extension.ExtendWith;

import java.util.UUID;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.never;

@ExtendWith(MockitoExtension.class)
class DisputeOpenedEventListenerTest {

    @Mock DisputeService disputeService;
    DisputeOpenedEventListener listener;

    @BeforeEach
    void setUp() {
        listener = new DisputeOpenedEventListener(disputeService);
    }

    @Test
    void defaultConstructor_routesToSenderNoShow() {
        UUID bidId = UUID.randomUUID(), senderId = UUID.randomUUID(), travelerId = UUID.randomUUID();
        listener.handleDisputeOpened(new DisputeOpenedEvent(bidId, senderId, travelerId));

        verify(disputeService).openSenderNoShowDispute(bidId, senderId, travelerId);
        verify(disputeService, never()).openDeliveryNoShowDispute(any(), any(), any(), any());
    }

    @Test
    void deliveryType_routesToDeliveryDispute() {
        UUID bidId = UUID.randomUUID(), senderId = UUID.randomUUID(), travelerId = UUID.randomUUID();
        listener.handleDisputeOpened(
                new DisputeOpenedEvent(bidId, senderId, travelerId, "RECIPIENT_NO_SHOW_CONTESTED"));

        verify(disputeService).openDeliveryNoShowDispute(
                bidId, senderId, travelerId, "RECIPIENT_NO_SHOW_CONTESTED");
        verify(disputeService, never()).openSenderNoShowDispute(any(), any(), any());
    }

    private static UUID any() { return org.mockito.ArgumentMatchers.any(); }
}
```
Note : le helper `any()` local ci-dessus court-circuite l'ambiguïté de type — préférer `import static org.mockito.ArgumentMatchers.any;` en tête de fichier et supprimer le helper si le compilateur résout correctement l'appel `openDeliveryNoShowDispute(any(), any(), any(), any())` (4 paramètres `UUID,UUID,UUID,String` — `any()` générique convient aux deux types sans ambiguïté avec `Mockito.any()` standard importé une seule fois).

- [ ] **Step 9: Vérifier vert + suite complète**

```bash
./mvnw test -Dtest=DisputeOpenedEventListenerTest > /tmp/dony-a2-listener.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-listener.log
tail -10 /tmp/dony-a2-listener.log
./mvnw test > /tmp/dony-a2-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-full.log
grep -E "Tests run|BUILD|EXIT_CODE" /tmp/dony-a2-full.log | tail -5
```
Attendu : nouveaux tests verts, suite complète = tests existants inchangés + 4 nouveaux (2 DisputeServiceTest + 2 DisputeOpenedEventListenerTest), 0 échec.

- [ ] **Step 10: Commit**

```bash
git add src/main/resources/db/migration/V174__disputes_unique_bid_id_type.sql \
        src/main/java/com/dony/api/disputes/DisputeRepository.java \
        src/main/java/com/dony/api/disputes/DisputeService.java \
        src/main/java/com/dony/api/disputes/events/DisputeOpenedEvent.java \
        src/main/java/com/dony/api/disputes/DisputeOpenedEventListener.java \
        src/test/java/com/dony/api/disputes/DisputeServiceTest.java \
        src/test/java/com/dony/api/disputes/DisputeOpenedEventListenerTest.java
git commit -m "feat(disputes): dispatch par type de litige, ouvre la voie aux litiges d'arrivée"
```

### Task A3: CancellationService — signalement + contestation à la livraison

**Files:**
- Create: `src/main/java/com/dony/api/cancellation/events/DeliveryNoShowReportedEvent.java`
- Modify: `src/main/java/com/dony/api/cancellation/CancellationService.java`
- Test: `src/test/java/com/dony/api/cancellation/CancellationServiceDeliveryNoShowTest.java`

**Interfaces:**
- Consumes: `CancellationRepository.findByBidIdAndScope`, `.existsByBidIdAndScopeAndNoShowStatusIn` (A1) ; `DisputeOpenedEvent(bidId, senderId, travelerId, type)` (A2).
- Produces: `CancellationService.reportDeliveryNoShow(UUID bidId, UUID travelerId)`, `.reportTravelerDeliveryNoShow(UUID bidId, UUID senderId)`, `.contestDeliveryNoShow(UUID bidId, UUID callerId)` — utilisées par la Task A4 (controller) et A6 (scheduler regarde les mêmes statuts).

- [ ] **Step 1: `DeliveryNoShowReportedEvent`**

```java
package com.dony.api.cancellation.events;

import java.util.UUID;

/** Publié quand une partie signale une absence à la remise du destinataire (arrivée).
 *  Écouté par NotificationDispatcher pour notifier l'autre partie. */
public class DeliveryNoShowReportedEvent {
    private final UUID bidId;
    private final UUID senderId;
    private final UUID travelerId;
    private final boolean reportedByTraveler; // true = voyageur signale destinataire absent

    public DeliveryNoShowReportedEvent(UUID bidId, UUID senderId, UUID travelerId, boolean reportedByTraveler) {
        this.bidId = bidId;
        this.senderId = senderId;
        this.travelerId = travelerId;
        this.reportedByTraveler = reportedByTraveler;
    }

    public UUID getBidId() { return bidId; }
    public UUID getSenderId() { return senderId; }
    public UUID getTravelerId() { return travelerId; }
    public boolean isReportedByTraveler() { return reportedByTraveler; }
}
```

- [ ] **Step 2: Test rouge (guards + signalement + contestation, les deux sens)**

```java
package com.dony.api.cancellation;

import com.dony.api.cancellation.events.DeliveryNoShowReportedEvent;
import com.dony.api.common.AuditService;
import com.dony.api.disputes.events.DisputeOpenedEvent;
import com.dony.api.matching.AnnouncementEntity;
import com.dony.api.matching.AnnouncementRepository;
import com.dony.api.matching.BidEntity;
import com.dony.api.matching.BidRepository;
import com.dony.api.matching.BidStatus;
import com.dony.api.auth.UserRepository;
import com.dony.api.payments.cash.CommissionProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CancellationServiceDeliveryNoShowTest {

    @Mock CancellationRepository cancellationRepository;
    @Mock RematchSuggestionRepository rematchSuggestionRepository;
    @Mock BidRepository bidRepository;
    @Mock AnnouncementRepository announcementRepository;
    @Mock UserRepository userRepository;
    @Mock AuditService auditService;
    @Mock ApplicationEventPublisher eventPublisher;

    CancellationService service;
    static final UUID BID_ID = UUID.randomUUID();
    static final UUID SENDER_ID = UUID.randomUUID();
    static final UUID TRAVELER_ID = UUID.randomUUID();
    static final UUID ANNOUNCEMENT_ID = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        CommissionProperties props = new CommissionProperties(BigDecimal.ZERO, BigDecimal.ZERO, 24);
        service = new CancellationService(cancellationRepository, rematchSuggestionRepository,
                bidRepository, announcementRepository, userRepository, auditService, eventPublisher, props);
    }

    private BidEntity inTransitBid(LocalDateTime departureDate) {
        BidEntity bid = new BidEntity();
        ReflectionTestUtils.setField(bid, "id", BID_ID);
        bid.setSenderId(SENDER_ID);
        bid.setAnnouncementId(ANNOUNCEMENT_ID);
        bid.setStatus(BidStatus.IN_TRANSIT);
        return bid;
    }

    private AnnouncementEntity announcement(java.time.LocalDate departureDate) {
        AnnouncementEntity a = new AnnouncementEntity();
        ReflectionTestUtils.setField(a, "id", ANNOUNCEMENT_ID);
        a.setTravelerId(TRAVELER_ID);
        a.setDepartureDate(departureDate);
        return a;
    }

    @Test
    void reportDeliveryNoShow_rejectsIfBidNotInTransit() {
        BidEntity bid = inTransitBid(null);
        bid.setStatus(BidStatus.ACCEPTED);
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(bid));

        assertThatThrownBy(() -> service.reportDeliveryNoShow(BID_ID, TRAVELER_ID))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void reportDeliveryNoShow_rejectsIfTripNotYetDeparted() {
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));
        when(announcementRepository.findById(ANNOUNCEMENT_ID))
                .thenReturn(Optional.of(announcement(java.time.LocalDate.now().plusDays(1))));

        assertThatThrownBy(() -> service.reportDeliveryNoShow(BID_ID, TRAVELER_ID))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void reportDeliveryNoShow_rejectsIfAlreadyPendingOrContested() {
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));
        when(announcementRepository.findById(ANNOUNCEMENT_ID))
                .thenReturn(Optional.of(announcement(java.time.LocalDate.now().minusDays(1))));
        when(cancellationRepository.existsByBidIdAndScopeAndNoShowStatusIn(
                BID_ID, CancellationScope.DELIVERY,
                List.of(CancellationStatus.PENDING_CONFIRMATION, CancellationStatus.CONTESTED)))
                .thenReturn(true);

        assertThatThrownBy(() -> service.reportDeliveryNoShow(BID_ID, TRAVELER_ID))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void reportDeliveryNoShow_createsPendingCancellationAndPublishesEvent() {
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));
        when(announcementRepository.findById(ANNOUNCEMENT_ID))
                .thenReturn(Optional.of(announcement(java.time.LocalDate.now().minusDays(1))));
        when(cancellationRepository.existsByBidIdAndScopeAndNoShowStatusIn(any(), any(), any()))
                .thenReturn(false);
        when(cancellationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CancellationEntity result = service.reportDeliveryNoShow(BID_ID, TRAVELER_ID);

        assertThat(result.getScope()).isEqualTo(CancellationScope.DELIVERY);
        assertThat(result.getNoShowStatus()).isEqualTo(CancellationStatus.CONFIRMED == result.getNoShowStatus() ? null : CancellationStatus.PENDING_CONFIRMATION);
        assertThat(result.getContestationDeadline()).isAfter(OffsetDateTime.now());
        verify(eventPublisher).publishEvent(any(DeliveryNoShowReportedEvent.class));
    }

    @Test
    void reportTravelerDeliveryNoShow_forbiddenIfNotSenderOfBid() {
        BidEntity bid = inTransitBid(null);
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(bid));

        assertThatThrownBy(() -> service.reportTravelerDeliveryNoShow(BID_ID, UUID.randomUUID()))
                .isInstanceOf(com.dony.api.common.DonyBusinessException.class);
    }

    @Test
    void reportTravelerDeliveryNoShow_createsPendingCancellation() {
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));
        when(announcementRepository.findById(ANNOUNCEMENT_ID))
                .thenReturn(Optional.of(announcement(java.time.LocalDate.now().minusDays(1))));
        when(cancellationRepository.existsByBidIdAndScopeAndNoShowStatusIn(any(), any(), any()))
                .thenReturn(false);
        when(cancellationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CancellationEntity result = service.reportTravelerDeliveryNoShow(BID_ID, SENDER_ID);

        assertThat(result.getScope()).isEqualTo(CancellationScope.DELIVERY);
        assertThat(result.getCancelledBy()).isEqualTo(SENDER_ID);
        verify(eventPublisher).publishEvent(any(DeliveryNoShowReportedEvent.class));
    }

    @Test
    void contestDeliveryNoShow_rejectsIfDeadlinePassed() {
        CancellationEntity c = new CancellationEntity();
        c.setBidId(BID_ID);
        c.setScope(CancellationScope.DELIVERY);
        c.setReason("RECIPIENT_NO_SHOW");
        c.setContestationDeadline(OffsetDateTime.now().minusHours(1));
        when(cancellationRepository.findByBidIdAndScope(BID_ID, CancellationScope.DELIVERY))
                .thenReturn(Optional.of(c));
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));

        assertThatThrownBy(() -> service.contestDeliveryNoShow(BID_ID, SENDER_ID))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void contestDeliveryNoShow_bySender_publishesRecipientNoShowContestedDispute() {
        CancellationEntity c = new CancellationEntity();
        c.setBidId(BID_ID);
        c.setScope(CancellationScope.DELIVERY);
        c.setReason("RECIPIENT_NO_SHOW"); // signalé par le voyageur → contesté par le sender
        c.setContestationDeadline(OffsetDateTime.now().plusHours(1));
        when(cancellationRepository.findByBidIdAndScope(BID_ID, CancellationScope.DELIVERY))
                .thenReturn(Optional.of(c));
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));
        when(announcementRepository.findById(ANNOUNCEMENT_ID))
                .thenReturn(Optional.of(announcement(java.time.LocalDate.now().minusDays(1))));

        service.contestDeliveryNoShow(BID_ID, SENDER_ID);

        assertThat(c.getNoShowStatus()).isEqualTo(CancellationStatus.CONTESTED);
        verify(eventPublisher).publishEvent(argThat((DisputeOpenedEvent e) ->
                "RECIPIENT_NO_SHOW_CONTESTED".equals(e.getType())
                        && e.getBidId().equals(BID_ID)));
    }

    @Test
    void contestDeliveryNoShow_byTraveler_publishesTravelerDeliveryNoShowContestedDispute() {
        CancellationEntity c = new CancellationEntity();
        c.setBidId(BID_ID);
        c.setScope(CancellationScope.DELIVERY);
        c.setReason("TRAVELER_DELIVERY_NO_SHOW"); // signalé par l'expéditeur → contesté par le voyageur
        c.setContestationDeadline(OffsetDateTime.now().plusHours(1));
        when(cancellationRepository.findByBidIdAndScope(BID_ID, CancellationScope.DELIVERY))
                .thenReturn(Optional.of(c));
        when(bidRepository.findById(BID_ID)).thenReturn(Optional.of(inTransitBid(null)));
        when(announcementRepository.findById(ANNOUNCEMENT_ID))
                .thenReturn(Optional.of(announcement(java.time.LocalDate.now().minusDays(1))));

        service.contestDeliveryNoShow(BID_ID, TRAVELER_ID);

        assertThat(c.getNoShowStatus()).isEqualTo(CancellationStatus.CONTESTED);
        verify(eventPublisher).publishEvent(argThat((DisputeOpenedEvent e) ->
                "TRAVELER_DELIVERY_NO_SHOW_CONTESTED".equals(e.getType())));
    }
}
```

- [ ] **Step 3: Vérifier l'échec**

```bash
./mvnw test -Dtest=CancellationServiceDeliveryNoShowTest > /tmp/dony-a3-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a3-red.log
tail -25 /tmp/dony-a3-red.log
```
Attendu : erreur de compilation (les 3 méthodes n'existent pas encore).

- [ ] **Step 4: Implémenter dans `CancellationService.java`**

Ajouter les imports en tête de fichier : `import com.dony.api.cancellation.events.DeliveryNoShowReportedEvent;`

Ajouter après `reportTravelerNoShow` (avant `cancelAfterHandover`) :

```java
    private static final String REASON_RECIPIENT_NO_SHOW = "RECIPIENT_NO_SHOW";
    private static final String REASON_TRAVELER_DELIVERY_NO_SHOW = "TRAVELER_DELIVERY_NO_SHOW";

    /** Le voyageur signale que le destinataire ne s'est pas présenté à la remise (arrivée). */
    @Transactional
    public CancellationEntity reportDeliveryNoShow(UUID bidId, UUID travelerId) {
        BidEntity bid = bidRepository.findById(bidId)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "bid-not-found", "Not Found", "Bid introuvable"));
        assertDeliveryReportable(bid);

        CancellationEntity c = new CancellationEntity();
        c.setBidId(bidId);
        c.setCancelledBy(travelerId);
        c.setReason(REASON_RECIPIENT_NO_SHOW);
        c.setScope(CancellationScope.DELIVERY);
        c.setNoShowStatus(CancellationStatus.PENDING_CONFIRMATION);
        c.setContestationDeadline(
                OffsetDateTime.now().plusHours(commissionProperties.noShowContestationHours()));
        CancellationEntity saved = cancellationRepository.save(c);

        auditService.log("BID", bidId, "DELIVERY_NOSHOW_REPORTED_BY_TRAVELER", travelerId,
                Map.of("bidId", bidId.toString()));
        eventPublisher.publishEvent(new DeliveryNoShowReportedEvent(
                bidId, bid.getSenderId(), travelerId, true));

        return saved;
    }

    /** L'expéditeur signale que le voyageur ne livre pas / est injoignable à l'arrivée. */
    @Transactional
    public CancellationEntity reportTravelerDeliveryNoShow(UUID bidId, UUID senderId) {
        BidEntity bid = bidRepository.findById(bidId)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "bid-not-found", "Not Found", "Bid introuvable"));
        if (!bid.getSenderId().equals(senderId)) {
            throw new DonyBusinessException(HttpStatus.FORBIDDEN, "forbidden", "Forbidden",
                    "Vous n'êtes pas l'expéditeur de ce bid.");
        }
        assertDeliveryReportable(bid);

        AnnouncementEntity announcement = announcementRepository.findById(bid.getAnnouncementId())
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "announcement-not-found", "Not Found", "Annonce introuvable"));

        CancellationEntity c = new CancellationEntity();
        c.setBidId(bidId);
        c.setCancelledBy(senderId);
        c.setReason(REASON_TRAVELER_DELIVERY_NO_SHOW);
        c.setScope(CancellationScope.DELIVERY);
        c.setNoShowStatus(CancellationStatus.PENDING_CONFIRMATION);
        c.setContestationDeadline(
                OffsetDateTime.now().plusHours(commissionProperties.noShowContestationHours()));
        CancellationEntity saved = cancellationRepository.save(c);

        auditService.log("BID", bidId, "DELIVERY_NOSHOW_REPORTED_BY_SENDER", senderId,
                Map.of("bidId", bidId.toString()));
        eventPublisher.publishEvent(new DeliveryNoShowReportedEvent(
                bidId, senderId, announcement.getTravelerId(), false));

        return saved;
    }

    /** Garde commune aux deux signalements de livraison : bid IN_TRANSIT, trajet déjà
     *  parti, aucun signalement DELIVERY déjà en cours ou contesté sur ce bid. */
    private void assertDeliveryReportable(BidEntity bid) {
        if (bid.getStatus() != BidStatus.IN_TRANSIT) {
            throw new IllegalStateException("Le bid doit être en statut IN_TRANSIT.");
        }
        AnnouncementEntity announcement = announcementRepository.findById(bid.getAnnouncementId())
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "announcement-not-found", "Not Found", "Annonce introuvable"));
        if (announcement.getDepartureDate() == null
                || !announcement.getDepartureDate().isBefore(LocalDate.now().plusDays(1))) {
            throw new IllegalStateException("Le trajet n'est pas encore parti.");
        }
        if (cancellationRepository.existsByBidIdAndScopeAndNoShowStatusIn(bid.getId(), CancellationScope.DELIVERY,
                List.of(CancellationStatus.PENDING_CONFIRMATION, CancellationStatus.CONTESTED))) {
            throw new IllegalStateException("Un signalement d'absence à la livraison est déjà en cours pour ce bid.");
        }
    }

    /** La partie adverse à celle qui a signalé conteste, avant la deadline.
     *  `reason` du signalement détermine le type de litige ouvert :
     *  RECIPIENT_NO_SHOW → contesté par le sender → RECIPIENT_NO_SHOW_CONTESTED ;
     *  TRAVELER_DELIVERY_NO_SHOW → contesté par le traveler → TRAVELER_DELIVERY_NO_SHOW_CONTESTED. */
    @Transactional
    public void contestDeliveryNoShow(UUID bidId, UUID callerId) {
        CancellationEntity c = cancellationRepository.findByBidIdAndScope(bidId, CancellationScope.DELIVERY)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "cancellation-not-found", "Not Found",
                        "Aucun signalement d'absence à la livraison pour ce bid"));
        if (c.getContestationDeadline() == null
                || OffsetDateTime.now().isAfter(c.getContestationDeadline())) {
            throw new IllegalStateException("Le délai de contestation est dépassé.");
        }

        BidEntity bid = bidRepository.findById(bidId).orElseThrow();
        AnnouncementEntity announcement = announcementRepository.findById(bid.getAnnouncementId()).orElseThrow();

        c.setNoShowStatus(CancellationStatus.CONTESTED);
        cancellationRepository.save(c);

        String disputeType = REASON_RECIPIENT_NO_SHOW.equals(c.getReason())
                ? "RECIPIENT_NO_SHOW_CONTESTED"
                : "TRAVELER_DELIVERY_NO_SHOW_CONTESTED";

        eventPublisher.publishEvent(new DisputeOpenedEvent(
                bidId, bid.getSenderId(), announcement.getTravelerId(), disputeType));
        auditService.log("CANCELLATION", c.getId(), "DELIVERY_NOSHOW_CONTESTED", callerId,
                Map.of("bidId", bidId.toString(), "type", disputeType));
    }
```

Note : `LocalDate` est déjà importé (`java.time.LocalDate`, utilisé ailleurs dans le fichier) — vérifier `grep -n "^import java.time" src/main/java/com/dony/api/cancellation/CancellationService.java` avant d'ajouter un import dupliqué.

- [ ] **Step 5: Vérifier vert**

```bash
./mvnw test -Dtest=CancellationServiceDeliveryNoShowTest > /tmp/dony-a3-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a3-green.log
tail -15 /tmp/dony-a3-green.log
```
Attendu : 9/9 verts.

- [ ] **Step 6: Commit**

```bash
git add src/main/java/com/dony/api/cancellation/events/DeliveryNoShowReportedEvent.java \
        src/main/java/com/dony/api/cancellation/CancellationService.java \
        src/test/java/com/dony/api/cancellation/CancellationServiceDeliveryNoShowTest.java
git commit -m "feat(cancellation): signalement et contestation d'absence à la livraison (deux sens)"
```

### Task A4: CancellationController — endpoints delivery no-show

**Files:**
- Modify: `src/main/java/com/dony/api/cancellation/CancellationController.java`
- Test: `src/test/java/com/dony/api/cancellation/CancellationControllerDeliveryNoShowTest.java`

**Interfaces:**
- Consumes: `CancellationService.reportDeliveryNoShow/.reportTravelerDeliveryNoShow/.contestDeliveryNoShow` (A3).
- Produces: `POST /cancellations/bids/{bidId}/report-delivery-noshow` (TRAVELER), `POST /cancellations/bids/{bidId}/report-traveler-delivery-noshow` (SENDER), `POST /cancellations/bids/{bidId}/contest-delivery-noshow` (SENDER ou TRAVELER) — consommés par la Partie B (Task B2 datasource).

- [ ] **Step 1: Test rouge**

```java
package com.dony.api.cancellation;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.UUID;

import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class CancellationControllerDeliveryNoShowTest {

    @Autowired MockMvc mockMvc;
    @MockBean CancellationService cancellationService;
    @MockBean com.dony.api.auth.UserRepository userRepository;

    static final UUID BID_ID = UUID.randomUUID();

    private static UsernamePasswordAuthenticationToken asRole(String uid, String role) {
        return new UsernamePasswordAuthenticationToken(
                uid, null, List.of(new SimpleGrantedAuthority("ROLE_" + role)));
    }

    private void stubUser(String uid) {
        com.dony.api.auth.UserEntity user = new com.dony.api.auth.UserEntity();
        org.springframework.test.util.ReflectionTestUtils.setField(user, "id", UUID.randomUUID());
        when(userRepository.findByFirebaseUid(uid)).thenReturn(java.util.Optional.of(user));
    }

    @Test
    void reportDeliveryNoShow_okForTraveler() throws Exception {
        stubUser("uid-traveler");
        mockMvc.perform(post("/cancellations/bids/{bidId}/report-delivery-noshow", BID_ID)
                        .with(authentication(asRole("uid-traveler", "TRAVELER"))))
                .andExpect(status().isOk());
        verify(cancellationService).reportDeliveryNoShow(eq(BID_ID), any());
    }

    @Test
    void reportDeliveryNoShow_forbiddenForSender() throws Exception {
        mockMvc.perform(post("/cancellations/bids/{bidId}/report-delivery-noshow", BID_ID)
                        .with(authentication(asRole("uid-sender", "SENDER"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void reportTravelerDeliveryNoShow_okForSender() throws Exception {
        stubUser("uid-sender");
        mockMvc.perform(post("/cancellations/bids/{bidId}/report-traveler-delivery-noshow", BID_ID)
                        .with(authentication(asRole("uid-sender", "SENDER"))))
                .andExpect(status().isOk());
        verify(cancellationService).reportTravelerDeliveryNoShow(eq(BID_ID), any());
    }

    @Test
    void reportTravelerDeliveryNoShow_forbiddenForTraveler() throws Exception {
        mockMvc.perform(post("/cancellations/bids/{bidId}/report-traveler-delivery-noshow", BID_ID)
                        .with(authentication(asRole("uid-traveler", "TRAVELER"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void contestDeliveryNoShow_okForSender() throws Exception {
        stubUser("uid-sender");
        mockMvc.perform(post("/cancellations/bids/{bidId}/contest-delivery-noshow", BID_ID)
                        .with(authentication(asRole("uid-sender", "SENDER"))))
                .andExpect(status().isOk());
    }

    @Test
    void contestDeliveryNoShow_okForTraveler() throws Exception {
        stubUser("uid-traveler");
        mockMvc.perform(post("/cancellations/bids/{bidId}/contest-delivery-noshow", BID_ID)
                        .with(authentication(asRole("uid-traveler", "TRAVELER"))))
                .andExpect(status().isOk());
    }

    private static UUID eq(UUID v) { return org.mockito.ArgumentMatchers.eq(v); }
    private static UUID any() { return org.mockito.ArgumentMatchers.any(); }
}
```

- [ ] **Step 2: Vérifier l'échec**

```bash
./mvnw test -Dtest=CancellationControllerDeliveryNoShowTest > /tmp/dony-a4-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a4-red.log
tail -20 /tmp/dony-a4-red.log
```
Attendu : 404 (routes inexistantes) sur les tests "ok".

- [ ] **Step 3: Ajouter les 3 endpoints dans `CancellationController.java`**

Après `reportTravelerNoShow` (avant `confirmReturn`) :

```java
    @PostMapping("/bids/{bidId}/report-delivery-noshow")
    @PreAuthorize("hasRole('TRAVELER')")
    public ResponseEntity<Void> reportDeliveryNoShow(@PathVariable UUID bidId) {
        UUID travelerId = resolveUserId();
        cancellationService.reportDeliveryNoShow(bidId, travelerId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/bids/{bidId}/report-traveler-delivery-noshow")
    @PreAuthorize("hasRole('SENDER')")
    public ResponseEntity<Void> reportTravelerDeliveryNoShow(@PathVariable UUID bidId) {
        UUID senderId = resolveUserId();
        cancellationService.reportTravelerDeliveryNoShow(bidId, senderId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/bids/{bidId}/contest-delivery-noshow")
    @PreAuthorize("hasAnyRole('SENDER', 'TRAVELER')")
    public ResponseEntity<Void> contestDeliveryNoShow(@PathVariable UUID bidId) {
        UUID callerId = resolveUserId();
        cancellationService.contestDeliveryNoShow(bidId, callerId);
        return ResponseEntity.ok().build();
    }
```

- [ ] **Step 4: Vérifier vert**

```bash
./mvnw test -Dtest=CancellationControllerDeliveryNoShowTest > /tmp/dony-a4-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a4-green.log
tail -10 /tmp/dony-a4-green.log
```
Attendu : 6/6 verts.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/cancellation/CancellationController.java \
        src/test/java/com/dony/api/cancellation/CancellationControllerDeliveryNoShowTest.java
git commit -m "feat(cancellation): endpoints signalement/contestation absence livraison"
```

### Task A5: Notification au signalement

**Files:**
- Modify: `src/main/java/com/dony/api/notifications/NotificationDispatcher.java`
- Test: `src/test/java/com/dony/api/notifications/NotificationDispatcherDeliveryNoShowTest.java` (nouveau — vérifier d'abord s'il existe un test dédié par event dans ce package via `ls src/test/java/com/dony/api/notifications/` pour suivre le même format)

**Interfaces:**
- Consumes: `DeliveryNoShowReportedEvent` (A3).
- Produces: notification FCM aux deux parties au signalement (le litige lui-même, ouvert plus tard par la contestation ou le scheduler, est déjà notifié par `onDisputeOpened` existant — inchangé).

- [ ] **Step 1: Vérifier le format de test existant**

```bash
ls src/test/java/com/dony/api/notifications/ | grep -i dispatcher
```
Lire le fichier trouvé pour reproduire exactement le pattern de mock (`@MockBean` vs `@Mock`, `notifyUser`/`notificationService.persist` stubbing) avant d'écrire le test ci-dessous — adapter si le pattern diffère.

- [ ] **Step 2: Test rouge**

```java
package com.dony.api.notifications;

import com.dony.api.cancellation.events.DeliveryNoShowReportedEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationDispatcherDeliveryNoShowTest {

    @Mock FcmService fcmService;
    @Mock SmsService smsService;
    @Mock com.dony.api.auth.UserRepository userRepository;
    @Mock NotificationService notificationService;

    @Test
    void onDeliveryNoShowReportedByTraveler_notifiesSenderOnly() {
        NotificationDispatcher dispatcher = new NotificationDispatcher(
                fcmService, smsService, userRepository, notificationService);
        UUID bidId = UUID.randomUUID(), senderId = UUID.randomUUID(), travelerId = UUID.randomUUID();
        var saved = mock(com.dony.api.notifications.NotificationEntity.class);
        when(saved.getId()).thenReturn(UUID.randomUUID());
        when(notificationService.persist(eq(senderId), any(), any(), any(), any(), anyBoolean()))
                .thenReturn(saved);

        dispatcher.onDeliveryNoShowReported(
                new DeliveryNoShowReportedEvent(bidId, senderId, travelerId, true));

        verify(notificationService).persist(eq(senderId), eq("DELIVERY_NOSHOW_REPORTED"), any(), any(), any(), eq(false));
        verify(fcmService).sendToUser(eq(senderId), any(), any(), any());
        verifyNoInteractions(smsService);
    }

    @Test
    void onDeliveryNoShowReportedBySender_notifiesTravelerOnly() {
        NotificationDispatcher dispatcher = new NotificationDispatcher(
                fcmService, smsService, userRepository, notificationService);
        UUID bidId = UUID.randomUUID(), senderId = UUID.randomUUID(), travelerId = UUID.randomUUID();
        var saved = mock(com.dony.api.notifications.NotificationEntity.class);
        when(saved.getId()).thenReturn(UUID.randomUUID());
        when(notificationService.persist(eq(travelerId), any(), any(), any(), any(), anyBoolean()))
                .thenReturn(saved);

        dispatcher.onDeliveryNoShowReported(
                new DeliveryNoShowReportedEvent(bidId, senderId, travelerId, false));

        verify(notificationService).persist(eq(travelerId), eq("DELIVERY_NOSHOW_REPORTED"), any(), any(), any(), eq(false));
        verify(fcmService).sendToUser(eq(travelerId), any(), any(), any());
    }
}
```
Adapter les noms exacts de classe (`NotificationEntity` — vérifier `grep -n "notificationService.persist" src/main/java/com/dony/api/notifications/NotificationDispatcher.java` pour le type de retour réel) et de méthode (`sendToUser`) au fichier réellement lu au Step 1 si différent.

- [ ] **Step 3: Vérifier l'échec**

```bash
./mvnw test -Dtest=NotificationDispatcherDeliveryNoShowTest > /tmp/dony-a5-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a5-red.log
tail -20 /tmp/dony-a5-red.log
```
Attendu : compilation error (`onDeliveryNoShowReported` n'existe pas).

- [ ] **Step 4: Ajouter le listener**

Import en tête : `import com.dony.api.cancellation.events.DeliveryNoShowReportedEvent;`

Après `onTripCancelled` (avant les "Critical events") :

```java
    @EventListener @Async
    public void onDeliveryNoShowReported(DeliveryNoShowReportedEvent event) {
        Map<String, String> data = Map.of("type", "DELIVERY_NOSHOW_REPORTED", "bidId", event.getBidId().toString());
        if (event.isReportedByTraveler()) {
            notifyUser(event.getSenderId(), "Absence signalée à la livraison",
                    "Le voyageur signale que votre destinataire ne s'est pas présenté", data);
        } else {
            notifyUser(event.getTravelerId(), "Absence signalée à la livraison",
                    "L'expéditeur signale que vous n'avez pas livré le colis", data);
        }
    }
```

- [ ] **Step 5: Vérifier vert**

```bash
./mvnw test -Dtest=NotificationDispatcherDeliveryNoShowTest > /tmp/dony-a5-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a5-green.log
tail -10 /tmp/dony-a5-green.log
```

- [ ] **Step 6: Commit**

```bash
git add src/main/java/com/dony/api/notifications/NotificationDispatcher.java \
        src/test/java/com/dony/api/notifications/NotificationDispatcherDeliveryNoShowTest.java
git commit -m "feat(notifications): notifie l'autre partie au signalement d'absence à la livraison"
```

### Task A6: Scheduler — non-contestation

**Files:**
- Create: `src/main/java/com/dony/api/cancellation/DeliveryNoShowUncontestedScheduler.java`
- Test: `src/test/java/com/dony/api/cancellation/DeliveryNoShowUncontestedSchedulerTest.java`

**Interfaces:**
- Consumes: `CancellationRepository.findExpiredPendingByScope` (A1), `DisputeService.openDeliveryNoShowDispute` (A2).
- Produces: job idempotent qui ouvre un litige (type non-contesté) pour tout signalement DELIVERY expiré sans contestation — aucune capture/remboursement.

- [ ] **Step 1: Test rouge**

```java
package com.dony.api.cancellation;

import com.dony.api.common.AuditService;
import com.dony.api.disputes.DisputeService;
import com.dony.api.matching.BidEntity;
import com.dony.api.matching.BidRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DeliveryNoShowUncontestedSchedulerTest {

    @Mock CancellationRepository cancellationRepository;
    @Mock BidRepository bidRepository;
    @Mock DisputeService disputeService;
    @Mock AuditService auditService;

    DeliveryNoShowUncontestedScheduler scheduler;

    @BeforeEach
    void setUp() {
        scheduler = new DeliveryNoShowUncontestedScheduler(
                cancellationRepository, bidRepository, disputeService, auditService);
    }

    @Test
    void run_opensUncontestedDisputeForExpiredRecipientNoShow() {
        UUID bidId = UUID.randomUUID();
        CancellationEntity c = new CancellationEntity();
        c.setBidId(bidId);
        c.setScope(CancellationScope.DELIVERY);
        c.setReason("RECIPIENT_NO_SHOW");
        c.setNoShowStatus(CancellationStatus.PENDING_CONFIRMATION);
        when(cancellationRepository.findExpiredPendingByScope(eq(CancellationScope.DELIVERY), any()))
                .thenReturn(List.of(c));

        BidEntity bid = new BidEntity();
        ReflectionTestUtils.setField(bid, "id", bidId);
        UUID senderId = UUID.randomUUID();
        bid.setSenderId(senderId);
        UUID annId = UUID.randomUUID();
        bid.setAnnouncementId(annId);
        when(bidRepository.findById(bidId)).thenReturn(Optional.of(bid));

        com.dony.api.matching.AnnouncementEntity ann = new com.dony.api.matching.AnnouncementEntity();
        UUID travelerId = UUID.randomUUID();
        ann.setTravelerId(travelerId);
        // AnnouncementRepository non mocké ici : le scheduler doit résoudre le
        // travelerId via bidRepository/announcementRepository comme les autres
        // méthodes de CancellationService — si le scheduler a besoin d'un
        // AnnouncementRepository, l'ajouter au constructeur et au mock ci-dessus.

        scheduler.run();

        verify(disputeService).openDeliveryNoShowDispute(eq(bidId), eq(senderId), any(), eq("RECIPIENT_NO_SHOW"));
    }

    @Test
    void run_isIdempotent_noExpiredEntities() {
        when(cancellationRepository.findExpiredPendingByScope(eq(CancellationScope.DELIVERY), any()))
                .thenReturn(List.of());

        scheduler.run();

        verifyNoInteractions(disputeService);
    }
}
```

Note d'implémentation : le scheduler a besoin du `travelerId` pour appeler `openDeliveryNoShowDispute` — ajouter `AnnouncementRepository` au constructeur (comme `CancellationService`) plutôt que de le déduire autrement ; adapter le test ci-dessus en conséquence (mock `announcementRepository.findById(annId)` retournant l'annonce avec `travelerId`).

- [ ] **Step 2: Vérifier l'échec**

```bash
./mvnw test -Dtest=DeliveryNoShowUncontestedSchedulerTest > /tmp/dony-a6-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a6-red.log
tail -20 /tmp/dony-a6-red.log
```

- [ ] **Step 3: Implémenter le scheduler**

```java
package com.dony.api.cancellation;

import com.dony.api.common.AuditService;
import com.dony.api.disputes.DisputeService;
import com.dony.api.matching.AnnouncementEntity;
import com.dony.api.matching.AnnouncementRepository;
import com.dony.api.matching.BidEntity;
import com.dony.api.matching.BidRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.Map;

/**
 * Signalement d'absence à la livraison expiré sans contestation → ouvre un
 * litige "non contesté" (pas de {@code _CONTESTED}). Jamais de capture ni de
 * remboursement automatique — l'admin tranche toujours. Idempotent : relire
 * ce job après un crash ne rouvre pas de litige (openDeliveryNoShowDispute
 * est lui-même idempotent par (bidId, type)).
 */
@Component
public class DeliveryNoShowUncontestedScheduler {

    private final CancellationRepository cancellationRepository;
    private final BidRepository bidRepository;
    private final AnnouncementRepository announcementRepository;
    private final DisputeService disputeService;
    private final AuditService auditService;

    public DeliveryNoShowUncontestedScheduler(CancellationRepository cancellationRepository,
                                              BidRepository bidRepository,
                                              AnnouncementRepository announcementRepository,
                                              DisputeService disputeService,
                                              AuditService auditService) {
        this.cancellationRepository = cancellationRepository;
        this.bidRepository = bidRepository;
        this.announcementRepository = announcementRepository;
        this.disputeService = disputeService;
        this.auditService = auditService;
    }

    @Scheduled(cron = "0 0 * * * *", zone = "UTC")
    @Transactional
    public void run() {
        cancellationRepository.findExpiredPendingByScope(CancellationScope.DELIVERY, OffsetDateTime.now())
                .forEach(this::openUncontestedDispute);
    }

    private void openUncontestedDispute(CancellationEntity c) {
        BidEntity bid = bidRepository.findById(c.getBidId()).orElse(null);
        if (bid == null) return;
        AnnouncementEntity announcement = announcementRepository.findById(bid.getAnnouncementId()).orElse(null);
        if (announcement == null) return;

        String type = "RECIPIENT_NO_SHOW".equals(c.getReason())
                ? "RECIPIENT_NO_SHOW"
                : "TRAVELER_DELIVERY_NO_SHOW";

        disputeService.openDeliveryNoShowDispute(
                c.getBidId(), bid.getSenderId(), announcement.getTravelerId(), type);
        auditService.log("CANCELLATION", c.getId(), "DELIVERY_NOSHOW_UNCONTESTED_DISPUTE_OPENED", null,
                Map.of("bidId", c.getBidId().toString(), "type", type));
    }
}
```

Adapter le test du Step 1 pour mocker `announcementRepository.findById(annId)` en conséquence (constructeur à 5 arguments).

- [ ] **Step 4: Vérifier vert**

```bash
./mvnw test -Dtest=DeliveryNoShowUncontestedSchedulerTest > /tmp/dony-a6-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a6-green.log
tail -15 /tmp/dony-a6-green.log
```

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/cancellation/DeliveryNoShowUncontestedScheduler.java \
        src/test/java/com/dony/api/cancellation/DeliveryNoShowUncontestedSchedulerTest.java
git commit -m "feat(cancellation): scheduler litige non-contesté pour absence livraison expirée"
```

### Task A7: BidResponse — exposer le statut delivery no-show + suite complète + PR

**Files:**
- Modify: `src/main/java/com/dony/api/matching/dto/BidResponse.java`
- Modify: `src/main/java/com/dony/api/matching/BidService.java`
- Test: `src/test/java/com/dony/api/matching/BidServiceTest.java` (ajout, pas de suppression)

**Interfaces:**
- Consumes: `CancellationRepository.findByBidIdAndScope` (A1).
- Produces: `BidResponse.deliveryNoShowStatus` (String, nullable), `BidResponse.deliveryNoShowContestationDeadline` (OffsetDateTime, nullable), `BidResponse.deliveryNoShowReportedByTraveler` (Boolean, nullable — true si le voyageur a signalé, false si l'expéditeur a signalé, null si aucun signalement) — consommés par la Partie B (Task B1, `BidModel`) et par B4 (savoir qui est l'auteur du signalement).

- [ ] **Step 1: Test rouge**

Ajouter dans `BidServiceTest.java` (chercher un test existant proche de `cancellationNoShowStatus` pour suivre exactement le même pattern de setup, ex. autour de la ligne 1873 vue précédemment) :

```java
@Test
void getBidResponse_exposesDeliveryNoShowStatusWhenPresent() {
    // Setup identique aux tests existants du même fichier (bid IN_TRANSIT, sender/traveler mockés).
    // Ajouter :
    CancellationEntity delivery = new CancellationEntity();
    delivery.setScope(CancellationScope.DELIVERY);
    delivery.setNoShowStatus(CancellationStatus.PENDING_CONFIRMATION);
    delivery.setContestationDeadline(java.time.OffsetDateTime.now().plusHours(24));
    delivery.setReason("RECIPIENT_NO_SHOW"); // signalé par le voyageur
    when(cancellationRepository.findByBidIdAndScope(BID_ID, CancellationScope.DELIVERY))
            .thenReturn(Optional.of(delivery));

    BidResponse response = bidService.getBidResponse(/* mêmes arguments que le test voisin */);

    assertThat(response.deliveryNoShowStatus()).isEqualTo("PENDING_CONFIRMATION");
    assertThat(response.deliveryNoShowContestationDeadline()).isNotNull();
    assertThat(response.deliveryNoShowReportedByTraveler()).isTrue();
}

@Test
void getBidResponse_deliveryNoShowStatusNullWhenNoDeliveryCancellation() {
    when(cancellationRepository.findByBidIdAndScope(BID_ID, CancellationScope.DELIVERY))
            .thenReturn(Optional.empty());

    BidResponse response = bidService.getBidResponse(/* mêmes arguments que le test voisin */);

    assertThat(response.deliveryNoShowStatus()).isNull();
    assertThat(response.deliveryNoShowContestationDeadline()).isNull();
    assertThat(response.deliveryNoShowReportedByTraveler()).isNull();
}
```
Adapter le nom exact de la méthode testée et ses arguments en lisant le test existant voisin de la ligne 1873 de `BidServiceTest.java` (celui qui stub déjà `cancellationRepository.findByBidId`) — reproduire son setup à l'identique, n'ajouter que le stub `findByBidIdAndScope` et les 2 nouvelles assertions.

- [ ] **Step 2: Vérifier l'échec**

```bash
./mvnw test -Dtest=BidServiceTest > /tmp/dony-a7-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a7-red.log
tail -25 /tmp/dony-a7-red.log
```
Attendu : compilation error (`deliveryNoShowStatus()` n'existe pas sur `BidResponse`).

- [ ] **Step 3: Ajouter les 2 champs à `BidResponse.java`**

Après `contestationDeadline` (ligne 60) :

```java
        String cancellationNoShowStatus,
        java.time.OffsetDateTime contestationDeadline,
        String deliveryNoShowStatus,
        java.time.OffsetDateTime deliveryNoShowContestationDeadline,
        Boolean deliveryNoShowReportedByTraveler,
        String paymentMethod,
```

- [ ] **Step 4: Peupler les champs dans `BidService.java`**

Après la ligne 914 (`OffsetDateTime contestationDeadline = ...`), ajouter :

```java
        var deliveryCancellation = cancellationRepository
                .findByBidIdAndScope(bid.getId(), com.dony.api.cancellation.CancellationScope.DELIVERY)
                .orElse(null);
        String deliveryNoShowStatus = deliveryCancellation != null
                ? deliveryCancellation.getNoShowStatus().name()
                : null;
        java.time.OffsetDateTime deliveryContestationDeadline = deliveryCancellation != null
                ? deliveryCancellation.getContestationDeadline()
                : null;
        Boolean deliveryNoShowReportedByTraveler = deliveryCancellation != null
                ? "RECIPIENT_NO_SHOW".equals(deliveryCancellation.getReason())
                : null;
```

Puis dans l'appel du constructeur `new BidResponse(...)`, après `contestationDeadline,` (ligne 1005) :

```java
                cancellationNoShowStatus,
                contestationDeadline,
                deliveryNoShowStatus,
                deliveryContestationDeadline,
                deliveryNoShowReportedByTraveler,
                bid.getPaymentMethod() != null ? bid.getPaymentMethod().name() : "STRIPE",
```

Ajouter l'import `com.dony.api.cancellation.CancellationScope` en tête de `BidService.java` si pas déjà présent via le nom complet utilisé ci-dessus (ou ajouter `import com.dony.api.cancellation.CancellationScope;` et simplifier l'appel).

- [ ] **Step 5: Vérifier vert, puis la suite complète des 2 repos**

```bash
./mvnw test -Dtest=BidServiceTest > /tmp/dony-a7-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a7-green.log
tail -10 /tmp/dony-a7-green.log
./mvnw test > /tmp/dony-a7-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a7-full.log
grep -E "Tests run|BUILD|EXIT_CODE" /tmp/dony-a7-full.log | tail -5
```
Attendu : suite complète verte, EXIT_CODE=0.

- [ ] **Step 6: Commit + push + PR draft**

```bash
git add src/main/java/com/dony/api/matching/dto/BidResponse.java \
        src/main/java/com/dony/api/matching/BidService.java \
        src/test/java/com/dony/api/matching/BidServiceTest.java
git commit -m "feat(matching): expose le statut delivery no-show sur BidResponse"
git push -u origin feature/delivery-noshow-backend
gh pr create --draft --title "feat(delivery-noshow): signalement d'absence à la livraison (backend)" --body "Implémente le backend du signalement d'absence à la remise du destinataire (arrivée), symétrique au no-show départ. Spec : dony_app docs/superpowers/specs/2026-07-15-delivery-noshow-design.md. Scope HANDOVER/DELIVERY sur CancellationEntity, litiges par type, jamais de paiement automatique — l'admin tranche toujours."
```

---

# Partie B — Frontend (dony_app)

Toutes les tasks sur la branche existante `feature/delivery-noshow` (contient déjà la spec). **Dépend de la Partie A mergée** (nouveau shape JSON sur `BidModel`, nouveaux endpoints).

### Task B1: BidModel — champs delivery no-show

**Files:**
- Modify: `lib/features/matching/data/models/bid_model.dart`
- Test: `test/features/matching/data/models/bid_model_test.dart` (chercher le fichier exact via `find test -iname "bid_model_test.dart"` — ajouter dedans, pas de suppression)

**Interfaces:**
- Consumes: rien.
- Produces: `BidModel.deliveryNoShowStatus` (String?), `BidModel.deliveryNoShowContestationDeadline` (DateTime?), `BidModel.canReportDeliveryNoShow` (bool getter) — utilisés par B4/B5.

- [ ] **Step 1: Test rouge**

```dart
test('canReportDeliveryNoShow: true si IN_TRANSIT, trajet parti, aucun signalement', () {
  final bid = BidModel(
    id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5,
    status: 'IN_TRANSIT',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    departureAt: DateTime.now().subtract(const Duration(days: 1)),
    deliveryNoShowStatus: null,
  );
  expect(bid.canReportDeliveryNoShow, isTrue);
});

test('canReportDeliveryNoShow: false si un signalement existe déjà', () {
  final bid = BidModel(
    id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5,
    status: 'IN_TRANSIT',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    departureAt: DateTime.now().subtract(const Duration(days: 1)),
    deliveryNoShowStatus: 'PENDING_CONFIRMATION',
  );
  expect(bid.canReportDeliveryNoShow, isFalse);
});

test('canReportDeliveryNoShow: false si le trajet n\'est pas encore parti', () {
  final bid = BidModel(
    id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5,
    status: 'IN_TRANSIT',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    departureAt: DateTime.now().add(const Duration(days: 1)),
  );
  expect(bid.canReportDeliveryNoShow, isFalse);
});

test('fromJson mappe deliveryNoShowStatus et deliveryNoShowContestationDeadline', () {
  final json = {
    'id': 'b1', 'announcementId': 'a1', 'senderId': 's1', 'weightKg': 5.0,
    'status': 'IN_TRANSIT',
    'createdAt': '2026-01-01T00:00:00', 'updatedAt': '2026-01-01T00:00:00',
    'deliveryNoShowStatus': 'CONTESTED',
    'deliveryNoShowContestationDeadline': '2026-07-16T10:00:00Z',
  };
  final bid = BidModel.fromJson(json);
  expect(bid.deliveryNoShowStatus, 'CONTESTED');
  expect(bid.deliveryNoShowContestationDeadline, isNotNull);
});
```
(Compléter les champs `required`/non-nullable manquants du constructeur `BidModel` selon ce qu'exige le compilateur — vérifier `bid_model.dart` pour la liste exacte des paramètres obligatoires avant d'exécuter.)

- [ ] **Step 2: Vérifier l'échec**

```bash
flutter test test/features/matching/data/models/bid_model_test.dart > /tmp/dony-b1-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b1-red.log
tail -20 /tmp/dony-b1-red.log
```

- [ ] **Step 3: Ajouter les champs à `BidModel`**

Après le champ `cancellationNoShowStatus` (ligne 105) :

```dart
  final String? deliveryNoShowStatus;
  final DateTime? deliveryNoShowContestationDeadline;
```

Dans le constructeur, après `this.cancellationNoShowStatus,` (ligne 196) :

```dart
    this.deliveryNoShowStatus,
    this.deliveryNoShowContestationDeadline,
    this.deliveryNoShowReportedByTraveler,
```

Après le getter `canCancelAfterHandover` (ligne ~267), ajouter :

```dart
  /// Signalement d'absence à la livraison possible : bid IN_TRANSIT, trajet
  /// déjà parti, aucun signalement en cours ou contesté sur ce bid.
  bool get canReportDeliveryNoShow =>
      status == 'IN_TRANSIT' &&
      deliveryNoShowStatus == null &&
      resolvedDepartureAt != null &&
      DateTime.now().isAfter(resolvedDepartureAt!);
```

- [ ] **Step 4: Régénérer le codegen JSON**

```bash
flutter pub run build_runner build --delete-conflicting-outputs > /tmp/dony-b1-codegen.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b1-codegen.log
tail -15 /tmp/dony-b1-codegen.log
```
Attendu : EXIT_CODE=0, `bid_model.g.dart` régénéré avec les 2 nouveaux champs.

- [ ] **Step 5: Vérifier vert**

```bash
flutter test test/features/matching/data/models/bid_model_test.dart > /tmp/dony-b1-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b1-green.log
tail -10 /tmp/dony-b1-green.log
flutter analyze lib/features/matching/data/models/bid_model.dart 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/data/models/bid_model.dart \
        lib/features/matching/data/models/bid_model.g.dart \
        test/features/matching/data/models/bid_model_test.dart
git commit -m "feat(matching): champs delivery no-show sur BidModel + canReportDeliveryNoShow"
```

### Task B2: Cancellation — events/states/repository/datasource delivery + bloc + analytics

**Files:**
- Modify: `lib/features/cancellation/bloc/cancellation_event.dart`
- Modify: `lib/features/cancellation/bloc/cancellation_state.dart`
- Modify: `lib/features/cancellation/bloc/cancellation_bloc.dart`
- Modify: `lib/features/cancellation/data/datasources/cancellation_remote_datasource.dart`
- Modify: `lib/features/cancellation/data/repositories/cancellation_repository.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Test: `test/features/cancellation/bloc/cancellation_bloc_test.dart`
- Test: `test/features/cancellation/data/datasources/cancellation_remote_datasource_test.dart` (chercher le fichier exact, sinon l'omettre si aucun test datasource dédié n'existe déjà pour ce repo — dans ce cas ajouter la couverture au niveau bloc uniquement)

**Interfaces:**
- Consumes: endpoints backend Partie A4 (`/cancellations/bids/{bidId}/report-delivery-noshow`, `.../report-traveler-delivery-noshow`, `.../contest-delivery-noshow`).
- Produces: events `DeliveryNoShowReportRequested(bidId)`, `TravelerDeliveryNoShowReportRequested(bidId)`, `DeliveryNoShowContestRequested(bidId)` ; state `DeliveryNoShowReported()` (partagé, mirroring `NoShowReported()`), `DeliveryNoShowContested()` — consommés par B3/B4.

- [ ] **Step 1: Analytics — nouvelles constantes**

Dans `analytics_events.dart`, après `noShowReportedByTraveler` (section Cancellations) :

```dart
  static const deliveryNoShowReportedByTraveler = 'delivery_no_show_reported_by_traveler';
  static const deliveryNoShowReportedBySender   = 'delivery_no_show_reported_by_sender';
  static const deliveryNoShowContested          = 'delivery_no_show_contested';
```

- [ ] **Step 2: Events**

Dans `cancellation_event.dart`, après `TravelerNoShowReportRequested` :

```dart
/// Le voyageur signale que le destinataire n'est pas venu à la remise (arrivée).
class DeliveryNoShowReportRequested extends CancellationEvent {
  final String bidId;
  DeliveryNoShowReportRequested(this.bidId);
}

/// L'expéditeur signale que le voyageur ne livre pas / est injoignable (arrivée).
class TravelerDeliveryNoShowReportRequested extends CancellationEvent {
  final String bidId;
  TravelerDeliveryNoShowReportRequested(this.bidId);
}

/// La partie adverse conteste un signalement d'absence à la livraison.
class DeliveryNoShowContestRequested extends CancellationEvent {
  final String bidId;
  DeliveryNoShowContestRequested(this.bidId);
}
```

- [ ] **Step 3: States**

Dans `cancellation_state.dart`, après `NoShowContested` :

```dart
class DeliveryNoShowReported extends CancellationState {}

class DeliveryNoShowContested extends CancellationState {}
```

- [ ] **Step 4: Datasource + Repository**

Dans `cancellation_remote_datasource.dart`, après `reportTravelerNoShow` :

```dart
  Future<void> reportDeliveryNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/report-delivery-noshow');
  }

  Future<void> reportTravelerDeliveryNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/report-traveler-delivery-noshow');
  }

  Future<void> contestDeliveryNoShow(String bidId) async {
    await _apiClient.dio.post('/cancellations/bids/$bidId/contest-delivery-noshow');
  }
```

Dans `cancellation_repository.dart`, après `reportTravelerNoShow` :

```dart
  Future<void> reportDeliveryNoShow(String bidId) =>
      _datasource.reportDeliveryNoShow(bidId);

  Future<void> reportTravelerDeliveryNoShow(String bidId) =>
      _datasource.reportTravelerDeliveryNoShow(bidId);

  Future<void> contestDeliveryNoShow(String bidId) =>
      _datasource.contestDeliveryNoShow(bidId);
```

- [ ] **Step 5: Test rouge (bloc)**

Ajouter dans `cancellation_bloc_test.dart`, en suivant le pattern des `group()` existants pour `NoShowReportRequested` :

```dart
group('DeliveryNoShowReportRequested', () {
  blocTest<CancellationBloc, CancellationState>(
    'émet Loading puis DeliveryNoShowReported au succès + analytics',
    build: () {
      when(() => repository.reportDeliveryNoShow('bid-1')).thenAnswer((_) async {});
      return CancellationBloc(repository, analytics);
    },
    act: (bloc) => bloc.add(DeliveryNoShowReportRequested('bid-1')),
    expect: () => [isA<CancellationLoading>(), isA<DeliveryNoShowReported>()],
    verify: (_) {
      verify(() => analytics.logEvent(AnalyticsEvents.deliveryNoShowReportedByTraveler)).called(1);
    },
  );

  blocTest<CancellationBloc, CancellationState>(
    'émet CancellationError sur DioException',
    build: () {
      when(() => repository.reportDeliveryNoShow('bid-1'))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/x')));
      return CancellationBloc(repository, analytics);
    },
    act: (bloc) => bloc.add(DeliveryNoShowReportRequested('bid-1')),
    expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
  );
});

group('TravelerDeliveryNoShowReportRequested', () {
  blocTest<CancellationBloc, CancellationState>(
    'émet Loading puis DeliveryNoShowReported au succès + analytics',
    build: () {
      when(() => repository.reportTravelerDeliveryNoShow('bid-1')).thenAnswer((_) async {});
      return CancellationBloc(repository, analytics);
    },
    act: (bloc) => bloc.add(TravelerDeliveryNoShowReportRequested('bid-1')),
    expect: () => [isA<CancellationLoading>(), isA<DeliveryNoShowReported>()],
    verify: (_) {
      verify(() => analytics.logEvent(AnalyticsEvents.deliveryNoShowReportedBySender)).called(1);
    },
  );
});

group('DeliveryNoShowContestRequested', () {
  blocTest<CancellationBloc, CancellationState>(
    'émet Loading puis DeliveryNoShowContested au succès + analytics',
    build: () {
      when(() => repository.contestDeliveryNoShow('bid-1')).thenAnswer((_) async {});
      return CancellationBloc(repository, analytics);
    },
    act: (bloc) => bloc.add(DeliveryNoShowContestRequested('bid-1')),
    expect: () => [isA<CancellationLoading>(), isA<DeliveryNoShowContested>()],
    verify: (_) {
      verify(() => analytics.logEvent(AnalyticsEvents.deliveryNoShowContested)).called(1);
    },
  );
});
```
(Adapter les noms des mocks `repository`/`analytics` à ceux réellement déclarés en tête du fichier de test existant — reproduire exactement le `setUp()` déjà présent.)

- [ ] **Step 6: Vérifier l'échec**

```bash
flutter test test/features/cancellation/bloc/cancellation_bloc_test.dart > /tmp/dony-b2-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b2-red.log
tail -25 /tmp/dony-b2-red.log
```

- [ ] **Step 7: Implémenter les handlers dans `CancellationBloc`**

Dans le constructeur, après `on<TravelerNoShowReportRequested>(_onTravelerNoShowReport);` :

```dart
    on<DeliveryNoShowReportRequested>(_onDeliveryNoShowReport);
    on<TravelerDeliveryNoShowReportRequested>(_onTravelerDeliveryNoShowReport);
    on<DeliveryNoShowContestRequested>(_onDeliveryNoShowContest);
```

Après `_onTravelerNoShowReport` :

```dart
  Future<void> _onDeliveryNoShowReport(
    DeliveryNoShowReportRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.reportDeliveryNoShow(event.bidId);
      emit(DeliveryNoShowReported());
      unawaited(_analytics.logEvent(AnalyticsEvents.deliveryNoShowReportedByTraveler));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onTravelerDeliveryNoShowReport(
    TravelerDeliveryNoShowReportRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.reportTravelerDeliveryNoShow(event.bidId);
      emit(DeliveryNoShowReported());
      unawaited(_analytics.logEvent(AnalyticsEvents.deliveryNoShowReportedBySender));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onDeliveryNoShowContest(
    DeliveryNoShowContestRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.contestDeliveryNoShow(event.bidId);
      emit(DeliveryNoShowContested());
      unawaited(_analytics.logEvent(AnalyticsEvents.deliveryNoShowContested));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }
```

- [ ] **Step 8: Vérifier vert**

```bash
flutter test test/features/cancellation/ > /tmp/dony-b2-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b2-green.log
tail -15 /tmp/dony-b2-green.log
flutter analyze lib/features/cancellation lib/core/services/analytics_events.dart 2>&1 | tail -5
```

- [ ] **Step 9: Commit**

```bash
git add lib/features/cancellation lib/core/services/analytics_events.dart \
        test/features/cancellation
git commit -m "feat(cancellation): events/states/repo/bloc delivery no-show + analytics"
```

### Task B3: Cellule CTA discrète (avant tout signalement)

**Files:**
- Create: `lib/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart`
- Modify: `lib/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart`
- Modify: `lib/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart`
- Test: `test/features/cancellation/presentation/widgets/delivery_noshow_cta_cell_test.dart`

**Interfaces:**
- Consumes: `BidModel.canReportDeliveryNoShow` (B1), `CancellationBloc`/`DeliveryNoShowReportRequested`/`TravelerDeliveryNoShowReportRequested` (B2).
- Produces: `DeliveryNoShowCtaCell({required BidModel bid, required bool isSender})` — inséré dans les deux `*_detail_body.dart`.

- [ ] **Step 1: Test rouge**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

BidModel _inTransitBid() => BidModel(
      id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5,
      status: 'IN_TRANSIT',
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      departureAt: DateTime.now().subtract(const Duration(days: 1)),
    );

Widget _harness(Widget child, CancellationBloc bloc) => MaterialApp(
      home: Scaffold(
        body: BlocProvider<CancellationBloc>.value(value: bloc, child: child),
      ),
    );

void main() {
  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    whenListen(bloc, const Stream<CancellationState>.empty(),
        initialState: CancellationInitial());
  });

  testWidgets('voyageur : cellule visible si canReportDeliveryNoShow', (tester) async {
    await tester.pumpWidget(_harness(
        DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: false), bloc));
    expect(find.text("Signaler l'absence du destinataire"), findsOneWidget);
  });

  testWidgets('expéditeur : cellule visible avec le libellé symétrique', (tester) async {
    await tester.pumpWidget(_harness(
        DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: true), bloc));
    expect(find.text('Le voyageur ne livre pas'), findsOneWidget);
  });

  testWidgets('masquée si un signalement existe déjà (canReportDeliveryNoShow=false)',
      (tester) async {
    final bid = BidModel(
      id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5,
      status: 'IN_TRANSIT',
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      departureAt: DateTime.now().subtract(const Duration(days: 1)),
      deliveryNoShowStatus: 'PENDING_CONFIRMATION',
    );
    await tester.pumpWidget(_harness(
        DeliveryNoShowCtaCell(bid: bid, isSender: false), bloc));
    expect(find.byType(DeliveryNoShowCtaCell), findsOneWidget);
    expect(find.text("Signaler l'absence du destinataire"), findsNothing);
  });

  testWidgets('tap voyageur → confirmer → dispatch DeliveryNoShowReportRequested',
      (tester) async {
    await tester.pumpWidget(_harness(
        DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: false), bloc));
    await tester.tap(find.text("Signaler l'absence du destinataire"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer le signalement'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(DeliveryNoShowReportRequested('b1'))).called(1);
  });

  testWidgets('tap expéditeur → confirmer → dispatch TravelerDeliveryNoShowReportRequested',
      (tester) async {
    await tester.pumpWidget(_harness(
        DeliveryNoShowCtaCell(bid: _inTransitBid(), isSender: true), bloc));
    await tester.tap(find.text('Le voyageur ne livre pas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer le signalement'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(TravelerDeliveryNoShowReportRequested('b1'))).called(1);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

```bash
flutter test test/features/cancellation/presentation/widgets/delivery_noshow_cta_cell_test.dart > /tmp/dony-b3-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b3-red.log
tail -20 /tmp/dony-b3-red.log
```

- [ ] **Step 3: Implémenter le widget**

Vérifier d'abord l'API réelle de `DonyIcon`/`DonyBottomSheet`/`DonyButton`/tokens (`DonyColors`, `DonySpacing`, `DonyRadius`) déjà utilisés dans `traveler_hero_card.dart` avant d'écrire — ce widget doit suivre exactement les mêmes imports et conventions.

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cellule discrète (pas d'alarme) proposant de signaler une absence à la
/// remise du destinataire — visible tant qu'aucun signalement n'existe.
/// Une fois signalé, la bannière (hero card) prend le relais (cf. Task B4).
class DeliveryNoShowCtaCell extends StatelessWidget {
  const DeliveryNoShowCtaCell({
    super.key,
    required this.bid,
    required this.isSender,
  });

  final BidModel bid;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    if (!bid.canReportDeliveryNoShow) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = isSender
        ? 'Le voyageur ne livre pas'
        : "Signaler l'absence du destinataire";
    final subtitle = isSender
        ? 'Injoignable ou refus de remettre le colis'
        : "Si vous êtes sur place et qu'il ne répond pas";

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => _showSheet(context),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Icon(
                  isSender ? Icons.flight_rounded : Icons.person_off_rounded,
                  color: cs.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final bloc = context.read<CancellationBloc>();
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: isSender
          ? "Le voyageur ne s'est pas présenté à la remise ?"
          : "Le destinataire ne s'est pas présenté à la remise ?",
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Confirmer le signalement',
          iconAsset: 'user-x',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSender
                  ? "Le voyageur ne livre pas le colis à votre destinataire."
                  : "Le destinataire ne s'est pas présenté au point de remise.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              "L'autre partie aura 24 h pour contester. Le paiement reste "
              'gelé le temps de l\'instruction — aucun versement automatique.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (isSender) {
      bloc.add(TravelerDeliveryNoShowReportRequested(bid.id));
    } else {
      bloc.add(DeliveryNoShowReportRequested(bid.id));
    }
  }
}
```
Note : `bloc` est capturé via `context.read` AVANT le `await DonyBottomSheet.show` (pas après) — pattern obligatoire du projet (cf. mémoire `feedback_no_auto_worktrees`-adjacent sur Slidable/dialogs : capturer le BLoC avant tout `await`, ne pas dépendre de `context.mounted` pour le dispatch BLoC après fermeture d'un sheet).

- [ ] **Step 4: Vérifier vert**

```bash
flutter test test/features/cancellation/presentation/widgets/delivery_noshow_cta_cell_test.dart > /tmp/dony-b3-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b3-green.log
tail -15 /tmp/dony-b3-green.log
```

- [ ] **Step 5: Wiring dans les deux `*_detail_body.dart`**

Dans `traveler_detail_body.dart`, ligne 96, après `TravelerHeroCard(bid: widget.bid),` :

```dart
      TravelerHeroCard(bid: widget.bid),
      DeliveryNoShowCtaCell(bid: widget.bid, isSender: false),
```
Ajouter l'import : `import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';`

Dans `sender_detail_body.dart`, ligne 96, symétriquement :

```dart
      SenderHeroCard(bid: widget.bid),
      DeliveryNoShowCtaCell(bid: widget.bid, isSender: true),
```
Même import ajouté.

- [ ] **Step 6: Vérifier que les tests existants de ces deux écrans passent toujours**

```bash
flutter test test/features/matching/presentation/widgets/bid_detail/ > /tmp/dony-b3-bodies.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b3-bodies.log
tail -20 /tmp/dony-b3-bodies.log
```
Attendu : 0 échec (le widget se masque tout seul via `SizedBox.shrink()` si `canReportDeliveryNoShow` est faux — ne doit rien casser sur les bids ACCEPTED/COMPLETED/etc. déjà testés).

- [ ] **Step 7: Commit**

```bash
git add lib/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart \
        lib/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart \
        lib/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart \
        test/features/cancellation/presentation/widgets/delivery_noshow_cta_cell_test.dart
git commit -m "feat(cancellation): cellule CTA signalement absence livraison (deux rôles)"
```

### Task B4: Bannières post-signalement (hero cards)

**Files:**
- Modify: `lib/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart`
- Modify: `lib/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart`
- Test: `test/features/matching/presentation/widgets/bid_detail/traveler_hero_card_test.dart` (chercher le fichier exact via `find test -iname "traveler_hero_card_test.dart"`)
- Test: `test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart` (idem)

**Interfaces:**
- Consumes: `BidModel.deliveryNoShowStatus` (B1), `DeliveryNoShowContestRequested` (B2).
- Produces: bannière "Absence signalée" (auteur du signalement) / "L'autre partie signale une absence" + CTA contester (destinataire du signalement) — priorité juste après la priorité 1 existante (no-show départ), avant la priorité 2 (fenêtre départ dépassée).

- [ ] **Step 1: Test rouge — `traveler_hero_card_test.dart`**

Ajouter (en suivant le pattern des tests existants du fichier — vérifier `_dispute`/`_bid` helper local avant d'en écrire un nouveau) :

```dart
testWidgets('bannière "Absence signalée" si deliveryNoShowReportedByTraveler=true (je suis l\'auteur)', (tester) async {
  final bid = /* helper existant du fichier */ BidModel(
    id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5, status: 'IN_TRANSIT',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    deliveryNoShowStatus: 'PENDING_CONFIRMATION',
    deliveryNoShowReportedByTraveler: true,
  );
  await tester.pumpWidget(/* harness existant du fichier avec TravelerHeroCard(bid: bid) */);
  expect(find.textContaining('Absence signalée'), findsOneWidget);
});

testWidgets('bannière "Une absence est signalée" + Contester si deliveryNoShowReportedByTraveler=false (je suis l\'adversaire)', (tester) async {
  final bid = /* helper existant du fichier */ BidModel(
    id: 'b1', announcementId: 'a1', senderId: 's1', weightKg: 5, status: 'IN_TRANSIT',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    deliveryNoShowStatus: 'PENDING_CONFIRMATION',
    deliveryNoShowReportedByTraveler: false,
  );
  await tester.pumpWidget(/* harness existant du fichier avec TravelerHeroCard(bid: bid) */);
  expect(find.textContaining('Une absence est signalée'), findsOneWidget);
  expect(find.text('Contester ce signalement'), findsOneWidget);
});
```

- [ ] **Step 2: Vérifier l'échec**

```bash
flutter test test/features/matching/presentation/widgets/bid_detail/traveler_hero_card_test.dart > /tmp/dony-b4-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b4-red.log
tail -20 /tmp/dony-b4-red.log
```

- [ ] **Step 3: Insérer la priorité delivery dans `traveler_hero_card.dart`**

Après le bloc "Priorité 1" existant (ligne 42, juste avant "// ── Priorité 2 : fenêtre dépassée"), insérer :

```dart
    // ── Priorité 1b : absence à la livraison déjà signalée ────────────────
    // bid.deliveryNoShowReportedByTraveler distingue qui a signalé : le
    // voyageur (true, lui-même) ou l'expéditeur (false, l'adversaire) — sans
    // ce champ, deliveryNoShowStatus seul ne suffit pas à savoir qui doit
    // voir "Absence signalée" (auteur) vs "Une absence est signalée" (adversaire).
    final deliveryStatus = bid.deliveryNoShowStatus;
    if (deliveryStatus == 'PENDING_CONFIRMATION' || deliveryStatus == 'CONTESTED') {
      final iAmReporter = bid.deliveryNoShowReportedByTraveler == true;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _DeliveryNoShowHero(
          bid: bid,
          iAmReporter: iAmReporter,
          contested: deliveryStatus == 'CONTESTED',
          key: ValueKey('TRAVELER_DELIVERY_NOSHOW_$deliveryStatus${bid.id}'),
        ),
      );
    }

```

- [ ] **Step 4: Widget `_DeliveryNoShowHero` (partagé, ajouté en bas de `traveler_hero_card.dart`)**

```dart
// ── Hero : absence à la livraison signalée ────────────────────────────────────

class _DeliveryNoShowHero extends StatelessWidget {
  const _DeliveryNoShowHero({
    super.key,
    required this.bid,
    required this.iAmReporter,
    required this.contested,
  });

  final BidModel bid;
  final bool iAmReporter;
  final bool contested;

  @override
  Widget build(BuildContext context) {
    if (iAmReporter) {
      return _HeroShell(
        variant: TravelerHeroVariant.wait,
        title: contested ? '⚖ Absence contestée' : '⏳ Absence signalée',
        subtitle: contested
            ? "L'autre partie conteste votre signalement. Notre équipe examine "
                'la demande et vous tiendra informé.'
            : "Signalement envoyé. L'autre partie a 24 h pour contester. "
                'Notre équipe tranche ensuite.',
      );
    }
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: TravelerHeroVariant.alert,
          title: '⚠ Une absence est signalée',
          subtitle: 'Une absence à la livraison a été signalée sur cet envoi. '
              'Vous pouvez contester si ce signalement est erroné.',
          footer: contested
              ? null
              : _HeroButton(
                  label: 'Contester ce signalement',
                  isLoading: isLoading,
                  onPressed: () => context
                      .read<CancellationBloc>()
                      .add(DeliveryNoShowContestRequested(bid.id)),
                ),
        );
      },
    );
  }
}
```
Ajouter l'import `import 'package:dony/features/cancellation/bloc/cancellation_event.dart';` s'il n'est pas déjà présent (il l'est — ligne 3 du fichier).

- [ ] **Step 5: Répéter Steps 1-4 pour `sender_hero_card.dart`** (symétrique : `iAmReporter = bid.deliveryNoShowReportedByTraveler == false`, insertion après la priorité 1 existante ligne 38, avant "// ── Priorité 2").

- [ ] **Step 6: Vérifier vert (les deux fichiers + suite bid_detail complète)**

```bash
flutter test test/features/matching/presentation/widgets/bid_detail/ > /tmp/dony-b4-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b4-green.log
tail -20 /tmp/dony-b4-green.log
flutter analyze lib/features/matching/presentation/widgets/bid_detail/ 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart \
        lib/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart \
        test/features/matching/presentation/widgets/bid_detail/traveler_hero_card_test.dart \
        test/features/matching/presentation/widgets/bid_detail/sender_hero_card_test.dart
git commit -m "feat(matching): bannières absence livraison + contestation sur les hero cards"
```

### Task B5: Labels litiges + finalisation — CLAUDE.md, suites complètes, PR

**Files:**
- Modify: `lib/features/disputes/presentation/utils/dispute_labels.dart`
- Modify: `CLAUDE.md` (racine dony_app — table analytics)
- Test: `test/features/disputes/presentation/dispute_list_screen_test.dart` (ou fichier équivalent testant `disputeTypeLabel`/`disputeStatusLabel` — chercher via `grep -rln "disputeTypeLabel" test/`)

**Interfaces:**
- Consumes: rien de nouveau (réutilise l'écran Mes litiges déjà livré).
- Produces: labels français pour les 4 nouveaux types de litige.

- [ ] **Step 1: Test rouge**

Ajouter dans le fichier de test identifié au Step 0 (ou un nouveau `test/features/disputes/presentation/utils/dispute_labels_test.dart` si aucun test unitaire dédié n'existe déjà pour cette fonction) :

```dart
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disputeTypeLabel traduit les types delivery no-show', () {
    expect(disputeTypeLabel('RECIPIENT_NO_SHOW_CONTESTED'), 'Absence du destinataire');
    expect(disputeTypeLabel('RECIPIENT_NO_SHOW'), 'Absence du destinataire');
    expect(disputeTypeLabel('TRAVELER_DELIVERY_NO_SHOW_CONTESTED'), 'Défaut de livraison');
    expect(disputeTypeLabel('TRAVELER_DELIVERY_NO_SHOW'), 'Défaut de livraison');
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

```bash
flutter test test/features/disputes/presentation/utils/dispute_labels_test.dart > /tmp/dony-b5-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b5-red.log
tail -15 /tmp/dony-b5-red.log
```
(Si le fichier n'existe pas encore, le créer d'abord avec juste l'import + le test ci-dessus — l'échec attendu est alors une assertion `Expected: 'Absence du destinataire' Actual: 'RECIPIENT_NO_SHOW_CONTESTED'`, le switch actuel retournant le type brut par défaut.)

- [ ] **Step 3: Étendre `disputeTypeLabel`**

Dans `dispute_labels.dart`, le switch actuel est :
```dart
String disputeTypeLabel(String type) => switch (type) {
      'SENDER_NO_SHOW_CONTESTED' => 'Contestation d\'absence',
      _ => type,
    };
```
Remplacer par :
```dart
String disputeTypeLabel(String type) => switch (type) {
      'SENDER_NO_SHOW_CONTESTED' => "Contestation d'absence",
      'RECIPIENT_NO_SHOW_CONTESTED' || 'RECIPIENT_NO_SHOW' => 'Absence du destinataire',
      'TRAVELER_DELIVERY_NO_SHOW_CONTESTED' || 'TRAVELER_DELIVERY_NO_SHOW' => 'Défaut de livraison',
      _ => type,
    };
```
(Vérifier le texte exact actuel de la première ligne — `dispute_labels.dart` a été modifié pour le français lors d'une session précédente ; lire le fichier avant de remplacer pour préserver l'échappement exact des apostrophes.)

- [ ] **Step 4: Vérifier vert**

```bash
flutter test test/features/disputes/ > /tmp/dony-b5-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b5-green.log
tail -10 /tmp/dony-b5-green.log
```

- [ ] **Step 5: CLAUDE.md — table analytics**

Ajouter dans la table « Events actuellement implémentés » (après `no_show_reported_by_sender`/`no_show_reported_by_traveler`) :

```markdown
| `delivery_no_show_reported_by_traveler` | CancellationBloc._onDeliveryNoShowReport — voyageur signale l'absence du destinataire à la livraison |
| `delivery_no_show_reported_by_sender` | CancellationBloc._onTravelerDeliveryNoShowReport — expéditeur signale que le voyageur ne livre pas |
| `delivery_no_show_contested` | CancellationBloc._onDeliveryNoShowContest — contestation d'un signalement d'absence à la livraison |
```

- [ ] **Step 6: Suite Flutter complète**

```bash
flutter test > /tmp/dony-b5-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b5-full.log
tail -10 /tmp/dony-b5-full.log
```
Attendu : 0 nouvel échec vs baseline main.

- [ ] **Step 7: Couverture**

```bash
flutter test --coverage test/features/cancellation test/features/matching/data/models/bid_model_test.dart test/features/disputes > /tmp/dony-b5-cov.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-b5-cov.log
```
Vérifier ≥ 90 % sur `lib/features/cancellation/` et les fichiers modifiés (`bid_model.dart`, hero cards, `dispute_labels.dart`) via `coverage/lcov.info`.

- [ ] **Step 8: Commit + push + PR draft**

```bash
git add -A && git status --short   # vérifier : uniquement les fichiers de cette feature
git commit -m "feat(disputes): labels absence/défaut livraison + doc analytics"
git push -u origin feature/delivery-noshow
gh pr create --draft --title "feat(delivery-noshow): signalement d'absence à la livraison (frontend)" --body "Écran détail envoi : cellule CTA + bottom sheet + bannières + contestation, deux rôles. Réutilise l'écran Mes litiges déjà livré (4 nouveaux libellés). Spec : docs/superpowers/specs/2026-07-15-delivery-noshow-design.md. Dépend de dony-back (PR backend delivery-noshow)."
```

- [ ] **Step 9: Rappel dépendance de déploiement**

Merger le backend AVANT le frontend (nouveau shape `BidResponse` + nouveaux endpoints). Sans le backend, les nouveaux boutons appelleraient des routes inexistantes (404 propre via `CancellationError`, pas de crash) — dégradation gracieuse le temps du déploiement, mais l'ordre back→front reste la séquence normale.
