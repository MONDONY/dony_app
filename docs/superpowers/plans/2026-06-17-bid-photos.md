# Bid Photos & Content Selection — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a sender attach up to 4 optional photos to a bid (visible to the traveler before accepting, in a swipeable modal), refactor the bid content step to be driven by the announcement's accepted/refused types plus custom items, and purge photos through an `ACTIVE → DELETING → cron-purge` lifecycle.

**Architecture:** Two **separate git repos**. Backend (`dony-back`) adds a `bid_photos` child table + `BidPhotoService` (attach/markDeleting/presigned-read), a multipart upload endpoint, `photoKeys` on the two bid-creation DTOs, an event listener that marks photos `DELETING` on terminal bid events, and a daily cron that purges `DELETING` rows + defensively sweeps `ACTIVE` photos of terminal bids. Frontend (`dony_app`) adds a `BidPhoto` model + `photos` on `BidModel`, a `/bids/photos` multipart uploader, a `BidPhotosCubit` driving the form photo section, a content step driven by the announcement, a `BidPhotoViewerModal`, and a gallery in the traveler/sender detail card.

**Tech Stack:** Spring Boot 3.5 / Java 21 / JPA / Flyway / JUnit5 + Mockito + MockMvc · Flutter / flutter_bloc / Dio / json_serializable / bloc_test + mocktail.

**Repo paths:**
- Backend repo root: `/Users/aboubakardiakite/Desktop/dony/dony-back`
- Frontend repo root (this worktree): `/Users/aboubakardiakite/Desktop/dony/dony_app/.claude/worktrees/feature+bid-photos`

**Branching:** Backend work on a `feature/bid-photos` branch in `dony-back`. Frontend work on the current worktree branch. Never commit on `main`. No `Co-Authored-By: Claude`.

**Shared API contract:**
- `POST /bids/photos` — multipart `file` → `201 { "key": "bids/{senderId}/{ts}_{uuid}.jpg" }`
- `BidRequest.photoKeys: List<String>` (≤ 4) and `BidCheckoutRequest.photoKeys: List<String>` (≤ 4)
- `BidResponse.photos: List<{ id: UUID, url: presigned }>` (ACTIVE only)

---

## File Structure

### Backend (`dony-back`) — `src/main/java/com/dony/api/`
- Create `matching/BidPhotoStatus.java` — enum `ACTIVE, DELETING`.
- Create `matching/BidPhotoEntity.java` — `bid_photos` row.
- Create `matching/BidPhotoRepository.java` — queries by bid+status and by status.
- Create `matching/BidPhotoService.java` — upload / attach / activePhotos(presigned) / markDeletingForBid.
- Create `matching/BidContentRules.java` — package-private refused-type guard (shared by create + checkout).
- Create `matching/BidPhotoLifecycleListener.java` — marks photos DELETING on terminal bid events.
- Create `matching/BidPhotoCleanupScheduler.java` — daily purge + defensive sweep.
- Create `matching/dto/BidPhotoResponse.java` — `{ id, url }`.
- Modify `common/StorageService.java` — add `bids/` to `ALLOWED_PREFIXES`.
- Modify `matching/dto/BidRequest.java` — add `photoKeys` before `gridItems`.
- Modify `matching/dto/BidCheckoutRequest.java` — add `photoKeys` before `gridItems`.
- Modify `matching/dto/BidResponse.java` — add `photos` as last component.
- Modify `matching/BidController.java` — add `POST /bids/photos`.
- Modify `matching/BidService.java` — inject `BidPhotoService`; `uploadBidPhoto(...)`; refused guard + `attachPhotos` in `createBid`; populate `photos` in `toResponse`.
- Modify `matching/BidCheckoutService.java` — inject `BidPhotoService`; refused guard + `attachPhotos` in `checkout`.
- Create `src/main/resources/db/migration/V140__bid_photos.sql`.
- Tests under `src/test/java/com/dony/api/matching/`.

### Frontend (`dony_app`) — `lib/`
- Create `features/matching/data/models/bid_photo.dart` (+ generated `.g.dart`).
- Modify `features/matching/data/models/bid_model.dart` — add `photos`.
- Modify `features/matching/data/datasources/bid_remote_datasource.dart` — `uploadBidPhoto` + `photoKeys`.
- Modify `features/matching/data/repositories/bid_repository.dart` — pass-through.
- Create `features/matching/bloc/bid_photo_upload.dart` — value object + status enum.
- Create `features/matching/bloc/bid_photos_cubit.dart` — upload list state.
- Modify `features/matching/bloc/bid_event.dart` — `photoKeys` on the two create events.
- Modify `features/matching/bloc/bid_bloc.dart` — thread `photoKeys` into create + checkout.
- Modify `core/di/injection.dart` — register `BidPhotosCubit`.
- Modify `core/services/analytics_events.dart` — 3 new consts.
- Modify `features/matching/presentation/widgets/create_bid_bottom_sheet.dart` — photo section + content refactor + thread `photoKeys`.
- Create `features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart`.
- Modify `features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart` — gallery + open viewer.
- Modify `dony_app/CLAUDE.md` — analytics events table.
- Tests under `test/features/matching/`.

---

# PART A — Backend (`dony-back`)

> Run all backend commands from `/Users/aboubakardiakite/Desktop/dony/dony-back`. Create the branch first:
> ```bash
> cd /Users/aboubakardiakite/Desktop/dony/dony-back
> git checkout -b feature/bid-photos
> ```

## Task A1: `bid_photos` table + entity + repository

**Files:**
- Create: `src/main/resources/db/migration/V140__bid_photos.sql`
- Create: `src/main/java/com/dony/api/matching/BidPhotoStatus.java`
- Create: `src/main/java/com/dony/api/matching/BidPhotoEntity.java`
- Create: `src/main/java/com/dony/api/matching/BidPhotoRepository.java`
- Test: `src/test/java/com/dony/api/matching/BidPhotoRepositoryTest.java`

- [ ] **Step 1: Write the migration**

`src/main/resources/db/migration/V140__bid_photos.sql`:
```sql
-- Photos optionnelles du colis jointes à la création d'un bid.
-- Cycle de vie : ACTIVE (visible) -> DELETING (caché, en attente) -> purge cron (suppression S3 + ligne).
CREATE TABLE bid_photos (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    bid_id         UUID          NOT NULL REFERENCES bids(id),
    object_key     VARCHAR(1024) NOT NULL,
    position       INT           NOT NULL DEFAULT 0,
    status         VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE'
                       CONSTRAINT chk_bid_photos_status CHECK (status IN ('ACTIVE', 'DELETING')),
    deleting_since TIMESTAMP,
    created_at     TIMESTAMP     NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_bid_photos_bid ON bid_photos(bid_id);
CREATE INDEX idx_bid_photos_status ON bid_photos(status);
```

- [ ] **Step 2: Write the enum**

`src/main/java/com/dony/api/matching/BidPhotoStatus.java`:
```java
package com.dony.api.matching;

public enum BidPhotoStatus {
    ACTIVE,
    DELETING
}
```

- [ ] **Step 3: Write the entity**

`src/main/java/com/dony/api/matching/BidPhotoEntity.java`:
```java
package com.dony.api.matching;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

/**
 * Une photo de colis jointe à un bid. Pas de soft-delete (purge physique voulue) —
 * n'étend donc pas BaseEntity.
 */
@Entity
@Table(name = "bid_photos")
public class BidPhotoEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "bid_id", nullable = false)
    private UUID bidId;

    @Column(name = "object_key", nullable = false, length = 1024)
    private String objectKey;

    @Column(name = "position", nullable = false)
    private int position;

    @Column(name = "status", nullable = false, length = 20)
    @Enumerated(EnumType.STRING)
    private BidPhotoStatus status = BidPhotoStatus.ACTIVE;

    @Column(name = "deleting_since")
    private LocalDateTime deletingSince;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now(ZoneOffset.UTC);

    protected BidPhotoEntity() {
    }

    public BidPhotoEntity(UUID bidId, String objectKey, int position) {
        this.bidId = bidId;
        this.objectKey = objectKey;
        this.position = position;
    }

    /** Idempotent : passe en DELETING et horodate la première fois. */
    public void markDeleting() {
        if (this.status != BidPhotoStatus.DELETING) {
            this.status = BidPhotoStatus.DELETING;
            this.deletingSince = LocalDateTime.now(ZoneOffset.UTC);
        }
    }

    public UUID getId() { return id; }
    public UUID getBidId() { return bidId; }
    public String getObjectKey() { return objectKey; }
    public int getPosition() { return position; }
    public BidPhotoStatus getStatus() { return status; }
    public LocalDateTime getDeletingSince() { return deletingSince; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
```

- [ ] **Step 4: Write the repository**

`src/main/java/com/dony/api/matching/BidPhotoRepository.java`:
```java
package com.dony.api.matching;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface BidPhotoRepository extends JpaRepository<BidPhotoEntity, UUID> {

    List<BidPhotoEntity> findByBidIdAndStatusOrderByPositionAsc(UUID bidId, BidPhotoStatus status);

    List<BidPhotoEntity> findByStatus(BidPhotoStatus status);
}
```

- [ ] **Step 5: Write a JPA slice test**

`src/test/java/com/dony/api/matching/BidPhotoRepositoryTest.java`:
```java
package com.dony.api.matching;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@ActiveProfiles("test")
class BidPhotoRepositoryTest {

    @Autowired private BidPhotoRepository repository;

    @Test
    void savesAndQueriesByBidAndStatusOrderedByPosition() {
        UUID bidId = UUID.randomUUID();
        repository.save(new BidPhotoEntity(bidId, "bids/s/2_b.jpg", 1));
        repository.save(new BidPhotoEntity(bidId, "bids/s/1_a.jpg", 0));

        List<BidPhotoEntity> active =
                repository.findByBidIdAndStatusOrderByPositionAsc(bidId, BidPhotoStatus.ACTIVE);

        assertThat(active).hasSize(2);
        assertThat(active.get(0).getObjectKey()).isEqualTo("bids/s/1_a.jpg");
        assertThat(active.get(1).getObjectKey()).isEqualTo("bids/s/2_b.jpg");
    }

    @Test
    void markDeletingMovesRowOutOfActiveQuery() {
        UUID bidId = UUID.randomUUID();
        BidPhotoEntity p = repository.save(new BidPhotoEntity(bidId, "bids/s/1.jpg", 0));
        p.markDeleting();
        repository.save(p);

        assertThat(repository.findByBidIdAndStatusOrderByPositionAsc(bidId, BidPhotoStatus.ACTIVE)).isEmpty();
        assertThat(repository.findByStatus(BidPhotoStatus.DELETING)).extracting(BidPhotoEntity::getId).contains(p.getId());
    }
}
```

> Note: if `@DataJpaTest` is not used elsewhere in the repo and the `test` profile points at an embedded/throwaway DB, this slice runs Flyway/DDL automatically. If the repo's `test` profile is not configured for JPA slices, convert this to a `@SpringBootTest` test mirroring an existing repository test instead.

- [ ] **Step 6: Run tests**

Run: `./mvnw test -Dtest=BidPhotoRepositoryTest`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add src/main/resources/db/migration/V140__bid_photos.sql \
        src/main/java/com/dony/api/matching/BidPhotoStatus.java \
        src/main/java/com/dony/api/matching/BidPhotoEntity.java \
        src/main/java/com/dony/api/matching/BidPhotoRepository.java \
        src/test/java/com/dony/api/matching/BidPhotoRepositoryTest.java
git commit -m "feat(bid-photos): bid_photos table, entity, repository"
```

---

## Task A2: Allow the `bids/` storage prefix

**Files:**
- Modify: `src/main/java/com/dony/api/common/StorageService.java` (the `ALLOWED_PREFIXES` set)

- [ ] **Step 1: Add `bids/` to the whitelist**

In `StorageService.java`, change:
```java
    private static final Set<String> ALLOWED_PREFIXES = Set.of(
            "tracking/", "users/", "messaging/", "kyc/", "package_requests/", "requests/");
```
to:
```java
    private static final Set<String> ALLOWED_PREFIXES = Set.of(
            "tracking/", "users/", "messaging/", "kyc/", "package_requests/", "requests/", "bids/");
```

- [ ] **Step 2: Compile**

Run: `./mvnw -q compile`
Expected: BUILD SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add src/main/java/com/dony/api/common/StorageService.java
git commit -m "feat(bid-photos): allow bids/ storage prefix"
```

---

## Task A3: `BidPhotoService` + `BidPhotoResponse`

**Files:**
- Create: `src/main/java/com/dony/api/matching/dto/BidPhotoResponse.java`
- Create: `src/main/java/com/dony/api/matching/BidPhotoService.java`
- Test: `src/test/java/com/dony/api/matching/BidPhotoServiceTest.java`

- [ ] **Step 1: Write the response DTO**

`src/main/java/com/dony/api/matching/dto/BidPhotoResponse.java`:
```java
package com.dony.api.matching.dto;

import java.util.UUID;

public record BidPhotoResponse(UUID id, String url) {}
```

- [ ] **Step 2: Write the failing service test**

`src/test/java/com/dony/api/matching/BidPhotoServiceTest.java`:
```java
package com.dony.api.matching;

import com.dony.api.common.DonyBusinessException;
import com.dony.api.common.StorageService;
import com.dony.api.matching.dto.BidPhotoResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BidPhotoServiceTest {

    @Mock private BidPhotoRepository photoRepository;
    @Mock private StorageService storageService;
    @InjectMocks private BidPhotoService service;

    @Captor private ArgumentCaptor<List<BidPhotoEntity>> rowsCaptor;

    private static final UUID BID = UUID.randomUUID();

    @Test
    void attachPhotos_persistsActiveRowsWithPositions() {
        service.attachPhotos(BID, List.of("bids/s/1.jpg", "bids/s/2.jpg"));

        verify(photoRepository).saveAll(rowsCaptor.capture());
        List<BidPhotoEntity> rows = rowsCaptor.getValue();
        assertThat(rows).hasSize(2);
        assertThat(rows.get(0).getPosition()).isEqualTo(0);
        assertThat(rows.get(1).getPosition()).isEqualTo(1);
        assertThat(rows).allMatch(r -> r.getStatus() == BidPhotoStatus.ACTIVE);
    }

    @Test
    void attachPhotos_nullOrEmpty_doesNothing() {
        service.attachPhotos(BID, null);
        service.attachPhotos(BID, List.of());
        verify(photoRepository, never()).saveAll(any());
    }

    @Test
    void attachPhotos_tooMany_throws422() {
        assertThatThrownBy(() -> service.attachPhotos(BID,
                List.of("bids/1", "bids/2", "bids/3", "bids/4", "bids/5")))
                .isInstanceOf(DonyBusinessException.class)
                .satisfies(e -> assertThat(((DonyBusinessException) e).getStatus())
                        .isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY));
    }

    @Test
    void attachPhotos_keyOutsideBidsPrefix_throws422() {
        assertThatThrownBy(() -> service.attachPhotos(BID, List.of("kyc/evil.jpg")))
                .isInstanceOf(DonyBusinessException.class)
                .satisfies(e -> assertThat(((DonyBusinessException) e).getErrorCode())
                        .isEqualTo("invalid-photo-key"));
    }

    @Test
    void activePhotos_mapsToPresignedUrls() {
        UUID id = UUID.randomUUID();
        BidPhotoEntity row = new BidPhotoEntity(BID, "bids/s/1.jpg", 0);
        when(photoRepository.findByBidIdAndStatusOrderByPositionAsc(BID, BidPhotoStatus.ACTIVE))
                .thenReturn(List.of(row));
        when(storageService.generatePresignedUrl(eq("bids/s/1.jpg"), any()))
                .thenReturn("https://signed/1");

        List<BidPhotoResponse> out = service.activePhotos(BID);

        assertThat(out).hasSize(1);
        assertThat(out.get(0).url()).isEqualTo("https://signed/1");
    }

    @Test
    void markDeletingForBid_flipsActiveRows() {
        BidPhotoEntity row = new BidPhotoEntity(BID, "bids/s/1.jpg", 0);
        when(photoRepository.findByBidIdAndStatusOrderByPositionAsc(BID, BidPhotoStatus.ACTIVE))
                .thenReturn(List.of(row));

        service.markDeletingForBid(BID);

        assertThat(row.getStatus()).isEqualTo(BidPhotoStatus.DELETING);
        verify(photoRepository).saveAll(any());
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `./mvnw test -Dtest=BidPhotoServiceTest`
Expected: COMPILE FAIL / no `BidPhotoService` class.

- [ ] **Step 4: Write the service**

`src/main/java/com/dony/api/matching/BidPhotoService.java`:
```java
package com.dony.api.matching;

import com.dony.api.common.DonyBusinessException;
import com.dony.api.common.StorageService;
import com.dony.api.matching.dto.BidPhotoResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Cycle de vie des photos de colis : upload, attache (ACTIVE), lecture présignée, passage DELETING. */
@Service
public class BidPhotoService {

    static final int MAX_PHOTOS = 4;
    static final String PHOTO_PREFIX = "bids/";
    private static final Duration PRESIGN_TTL = Duration.ofMinutes(15);

    private final BidPhotoRepository photoRepository;
    private final StorageService storageService;

    public BidPhotoService(BidPhotoRepository photoRepository, StorageService storageService) {
        this.photoRepository = photoRepository;
        this.storageService = storageService;
    }

    /** Upload une photo sous le prefix bids/{senderId}/ ; renvoie la clé S3. */
    public String uploadPhoto(UUID senderId, MultipartFile file) {
        try {
            return storageService.uploadFile(file, PHOTO_PREFIX + senderId + "/");
        } catch (IOException e) {
            throw new DonyBusinessException(HttpStatus.UNPROCESSABLE_ENTITY,
                    "photo-upload-failed", "Photo Upload Failed",
                    "Impossible d'enregistrer la photo");
        }
    }

    /** Persiste jusqu'à MAX_PHOTOS lignes ACTIVE pour un bid fraîchement créé. */
    @Transactional
    public void attachPhotos(UUID bidId, List<String> photoKeys) {
        if (photoKeys == null || photoKeys.isEmpty()) {
            return;
        }
        if (photoKeys.size() > MAX_PHOTOS) {
            throw new DonyBusinessException(HttpStatus.UNPROCESSABLE_ENTITY,
                    "too-many-photos", "Too Many Photos",
                    "Maximum " + MAX_PHOTOS + " photos par colis");
        }
        List<BidPhotoEntity> rows = new ArrayList<>();
        int position = 0;
        for (String key : photoKeys) {
            if (key == null || !key.startsWith(PHOTO_PREFIX)) {
                throw new DonyBusinessException(HttpStatus.UNPROCESSABLE_ENTITY,
                        "invalid-photo-key", "Invalid Photo Key",
                        "Clé photo invalide");
            }
            rows.add(new BidPhotoEntity(bidId, key, position++));
        }
        photoRepository.saveAll(rows);
    }

    /** Photos ACTIVE en URLs présignées, triées par position. */
    public List<BidPhotoResponse> activePhotos(UUID bidId) {
        return photoRepository
                .findByBidIdAndStatusOrderByPositionAsc(bidId, BidPhotoStatus.ACTIVE)
                .stream()
                .map(p -> new BidPhotoResponse(p.getId(),
                        storageService.generatePresignedUrl(p.getObjectKey(), PRESIGN_TTL)))
                .toList();
    }

    /** Passe toutes les photos ACTIVE d'un bid en DELETING (idempotent). */
    @Transactional
    public void markDeletingForBid(UUID bidId) {
        List<BidPhotoEntity> active =
                photoRepository.findByBidIdAndStatusOrderByPositionAsc(bidId, BidPhotoStatus.ACTIVE);
        for (BidPhotoEntity p : active) {
            p.markDeleting();
        }
        photoRepository.saveAll(active);
    }
}
```

- [ ] **Step 5: Run tests**

Run: `./mvnw test -Dtest=BidPhotoServiceTest`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add src/main/java/com/dony/api/matching/dto/BidPhotoResponse.java \
        src/main/java/com/dony/api/matching/BidPhotoService.java \
        src/test/java/com/dony/api/matching/BidPhotoServiceTest.java
git commit -m "feat(bid-photos): BidPhotoService (upload/attach/activePhotos/markDeleting)"
```

---

## Task A4: Upload endpoint `POST /bids/photos`

**Files:**
- Modify: `src/main/java/com/dony/api/matching/BidService.java` (inject `BidPhotoService`, add `uploadBidPhoto`)
- Modify: `src/main/java/com/dony/api/matching/BidController.java` (add endpoint)
- Test: `src/test/java/com/dony/api/matching/BidPhotoControllerIntegrationTest.java`

- [ ] **Step 1: Inject `BidPhotoService` into `BidService` and add `uploadBidPhoto`**

In `BidService.java`, add a `private final BidPhotoService bidPhotoService;` field and add it as the **last** constructor parameter, assigning it in the body. Then add this method (anywhere among the public methods):
```java
    /** Upload une photo de colis pour le sender courant ; renvoie la clé S3. */
    public String uploadBidPhoto(String firebaseUid, org.springframework.web.multipart.MultipartFile file) {
        UserEntity sender = findUserByFirebaseUid(firebaseUid);
        return bidPhotoService.uploadPhoto(sender.getId(), file);
    }
```

> `findUserByFirebaseUid(...)` is the existing private resolver used throughout `BidService`.

- [ ] **Step 2: Add the controller endpoint**

In `BidController.java` add imports:
```java
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.security.access.prepost.PreAuthorize;
```
(If `PreAuthorize` is already imported, skip it.) Then add the handler:
```java
    @PostMapping("/bids/photos")
    @PreAuthorize("hasRole('SENDER')")
    public ResponseEntity<java.util.Map<String, String>> uploadBidPhoto(
            @RequestParam("file") MultipartFile file) {
        String firebaseUid = requireFirebaseUid();
        String key = bidService.uploadBidPhoto(firebaseUid, file);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(java.util.Map.of("key", key));
    }
```

- [ ] **Step 3: Update `BidService` test mocks**

In `src/test/java/com/dony/api/matching/BidServiceTest.java`, add the mock so `@InjectMocks` still wires the constructor:
```java
    @Mock private BidPhotoService bidPhotoService;
```
(Place it next to the other `@Mock` fields, before `@InjectMocks private BidService bidService;`.)

- [ ] **Step 4: Write the controller test**

`src/test/java/com/dony/api/matching/BidPhotoControllerIntegrationTest.java`:
```java
package com.dony.api.matching;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class BidPhotoControllerIntegrationTest {

    @Autowired private MockMvc mockMvc;

    @MockitoBean private BidService bidService;
    @MockitoBean private BidCheckoutService bidCheckoutService;
    @MockitoBean private com.dony.api.payments.PaymentService paymentService;
    @MockitoBean private com.dony.api.cancellation.CancellationService cancellationService;

    private static UsernamePasswordAuthenticationToken sender(String uid) {
        return new UsernamePasswordAuthenticationToken(
                uid, null, List.of(new SimpleGrantedAuthority("ROLE_SENDER")));
    }

    @Test
    void uploadPhoto_returns201WithKey() throws Exception {
        when(bidService.uploadBidPhoto(anyString(), any())).thenReturn("bids/s/1.jpg");
        MockMultipartFile file = new MockMultipartFile(
                "file", "c.jpg", "image/jpeg", new byte[]{1, 2, 3});

        mockMvc.perform(multipart("/bids/photos").file(file)
                        .with(authentication(sender("uid-sender"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.key").value("bids/s/1.jpg"));
    }

    @Test
    void uploadPhoto_unauthenticated_isRejected() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "c.jpg", "image/jpeg", new byte[]{1});
        mockMvc.perform(multipart("/bids/photos").file(file))
                .andExpect(status().is4xxClientError());
    }
}
```

> Mock the same collaborators `BidController` requires (`BidService`, `BidCheckoutService`, `PaymentService`, `CancellationService`) so the context loads. If the existing `BidControllerIntegrationTest` already declares a canonical set of `@MockitoBean`s, mirror that exact set.

- [ ] **Step 5: Run tests**

Run: `./mvnw test -Dtest=BidPhotoControllerIntegrationTest,BidServiceTest`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/main/java/com/dony/api/matching/BidService.java \
        src/main/java/com/dony/api/matching/BidController.java \
        src/test/java/com/dony/api/matching/BidServiceTest.java \
        src/test/java/com/dony/api/matching/BidPhotoControllerIntegrationTest.java
git commit -m "feat(bid-photos): POST /bids/photos multipart upload endpoint"
```

---

## Task A5: `photoKeys` on DTOs + refused-type guard + attach on create & checkout

**Files:**
- Create: `src/main/java/com/dony/api/matching/BidContentRules.java`
- Modify: `src/main/java/com/dony/api/matching/dto/BidRequest.java`
- Modify: `src/main/java/com/dony/api/matching/dto/BidCheckoutRequest.java`
- Modify: `src/main/java/com/dony/api/matching/BidService.java` (`createBid`)
- Modify: `src/main/java/com/dony/api/matching/BidCheckoutService.java` (`checkout`)
- Modify: test helpers that construct `BidRequest` / `BidCheckoutRequest`
- Test: `src/test/java/com/dony/api/matching/BidContentRulesTest.java`

- [ ] **Step 1: Add `photoKeys` to `BidRequest` (before `gridItems`, which must stay last)**

In `BidRequest.java`, add the `Size` import:
```java
import jakarta.validation.constraints.Size;
```
and insert a component between `promoCode` and `gridItems`:
```java
        String promoCode,

        @Size(max = 4, message = "Maximum 4 photos") List<String> photoKeys,

        @Valid List<BidGridItemRequest> gridItems  // peut être null ou vide — doit rester en DERNIER
) {}
```

- [ ] **Step 2: Add `photoKeys` to `BidCheckoutRequest` (before `gridItems`)**

In `BidCheckoutRequest.java`, insert between `disclaimerSigned` and `gridItems`:
```java
        @AssertTrue(message = "Le disclaimer doit être signé") Boolean disclaimerSigned,
        @Size(max = 4) List<String> photoKeys,
        @Valid List<BidGridItemRequest> gridItems
) {}
```
(`@Size` is already imported in this file.)

- [ ] **Step 3: Write the refused-type guard + its failing test**

`src/test/java/com/dony/api/matching/BidContentRulesTest.java`:
```java
package com.dony.api.matching;

import com.dony.api.common.DonyBusinessException;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class BidContentRulesTest {

    private AnnouncementEntity announcementRefusing(List<String> refused) {
        AnnouncementEntity a = new AnnouncementEntity();
        a.setRefusedTypes(refused);
        return a;
    }

    @Test
    void throwsWhenDeclaredCategoryIsRefused_caseInsensitive() {
        AnnouncementEntity a = announcementRefusing(List.of("Hi-fi", "Téléphone"));
        assertThatThrownBy(() -> BidContentRules.assertNotRefused(a, "Vêtements, hi-fi"))
                .isInstanceOf(DonyBusinessException.class);
    }

    @Test
    void passesWhenNoOverlap() {
        AnnouncementEntity a = announcementRefusing(List.of("Hi-fi"));
        assertThatCode(() -> BidContentRules.assertNotRefused(a, "Vêtements, Médicaments"))
                .doesNotThrowAnyException();
    }

    @Test
    void passesWhenRefusedListEmptyOrCategoryBlank() {
        assertThatCode(() -> BidContentRules.assertNotRefused(announcementRefusing(List.of()), "Vêtements"))
                .doesNotThrowAnyException();
        assertThatCode(() -> BidContentRules.assertNotRefused(announcementRefusing(List.of("Hi-fi")), ""))
                .doesNotThrowAnyException();
    }
}
```

> If `AnnouncementEntity` has no public `setRefusedTypes`, add a package-private setter or use the reflection `setId`-style helper used in `BidServiceTest`. Check `AnnouncementEntity` first; a `setRefusedTypes(List<String>)` setter likely already exists (the create flow sets it).

`src/main/java/com/dony/api/matching/BidContentRules.java`:
```java
package com.dony.api.matching;

import com.dony.api.common.DonyBusinessException;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Locale;

/** Règles de contenu d'un bid vis-à-vis de l'annonce (paquet matching). */
final class BidContentRules {

    private BidContentRules() {
    }

    /** Lève 422 si une catégorie déclarée figure dans les types refusés de l'annonce. */
    static void assertNotRefused(AnnouncementEntity announcement, String contentCategory) {
        if (contentCategory == null || contentCategory.isBlank()) {
            return;
        }
        List<String> refused = announcement.getRefusedTypes();
        if (refused == null || refused.isEmpty()) {
            return;
        }
        List<String> refusedLower = refused.stream()
                .map(s -> s.toLowerCase(Locale.ROOT).strip())
                .toList();
        for (String raw : contentCategory.split(",")) {
            String item = raw.toLowerCase(Locale.ROOT).strip();
            if (!item.isEmpty() && refusedLower.contains(item)) {
                throw new DonyBusinessException(HttpStatus.UNPROCESSABLE_ENTITY,
                        "content-type-refused", "Content Type Refused",
                        "Le voyageur n'accepte pas : " + raw.strip());
            }
        }
    }
}
```

- [ ] **Step 4: Wire the guard + `attachPhotos` into `BidService.createBid`**

In `createBid(...)`, right after the announcement is loaded and validated (after the `announcement.getTravelerId().equals(sender.getId())` ownership block is fine), add:
```java
        BidContentRules.assertNotRefused(announcement, request.contentCategory());
```
Then at the **end** of the method, immediately before `return toResponse(saved, sender);`, add:
```java
        bidPhotoService.attachPhotos(saved.getId(), request.photoKeys());
```

- [ ] **Step 5: Wire the guard + `attachPhotos` into `BidCheckoutService.checkout`**

In `BidCheckoutService.java`: add a `private final BidPhotoService bidPhotoService;` field, add it as the **last** constructor parameter and assign it. Then in `checkout(...)`:
- After the announcement is loaded/validated, add:
```java
        BidContentRules.assertNotRefused(announcement, req.contentCategory());
```
- After `BidEntity saved = bidRepository.save(bid);` (the first save, ~line 185) and after the grid-items loop, add:
```java
        bidPhotoService.attachPhotos(saved.getId(), req.photoKeys());
```

> Use the exact local variable names already in scope (`announcement`, `req`, `saved`). If `checkout` resolves the announcement under a different variable name, use that.

- [ ] **Step 6: Update all positional `BidRequest` / `BidCheckoutRequest` constructors in tests**

Run to find them:
```bash
grep -rn "new BidRequest(" src/test
grep -rn "new BidCheckoutRequest(" src/test
```
For every `new BidRequest(...)`, insert `null` for `photoKeys` **before** the final `gridItems` argument. Example — `BidServiceTest.buildRequest` becomes:
```java
    private BidRequest buildRequest(BigDecimal weight, BigDecimal value) {
        return new BidRequest(weight, value, "Vêtements", "CLOTHING",
                "Aminata Diallo", "+221701234567", true, null, null, null, null, null, null);
    }
```
For every `new BidCheckoutRequest(...)`, insert `null` for `photoKeys` before the final `gridItems` argument (e.g. in `BidCheckoutControllerIntegrationTest`).

- [ ] **Step 7: Add create-path photo + refused assertions to `BidServiceTest`**

Add inside `BidServiceTest.CreateBidTests`:
```java
        @Test
        @DisplayName("photoKeys présents → attachPhotos appelé")
        void createBid_withPhotoKeys_attachesPhotos() {
            UserEntity sender = buildSender();
            AnnouncementEntity announcement = buildAnnouncement();
            when(userRepository.findByFirebaseUid(SENDER_UID)).thenReturn(Optional.of(sender));
            when(announcementRepository.findById(ANNOUNCEMENT_ID)).thenReturn(Optional.of(announcement));
            when(bidRepository.existsBySenderIdAndAnnouncementIdAndStatusIn(any(), any(), any()))
                    .thenReturn(false);
            when(bidRepository.save(any(BidEntity.class))).thenAnswer(inv -> {
                BidEntity b = inv.getArgument(0);
                setId(b, BID_ID);
                return b;
            });

            BidRequest req = new BidRequest(BigDecimal.valueOf(5), BigDecimal.valueOf(100),
                    "Vêtements", "CLOTHING", "Aminata Diallo", "+221701234567", true,
                    null, null, null, null, java.util.List.of("bids/s/1.jpg"), null);

            bidService.createBid(ANNOUNCEMENT_ID, SENDER_UID, req, httpRequest);

            verify(bidPhotoService).attachPhotos(eq(BID_ID), eq(java.util.List.of("bids/s/1.jpg")));
        }
```

> The `buildAnnouncement()` helper must return an announcement whose `getRefusedTypes()` is empty (default) so the guard passes. If it returns null, add `announcement.setRefusedTypes(java.util.List.of())` in the helper or test.

- [ ] **Step 8: Run tests**

Run: `./mvnw test -Dtest=BidContentRulesTest,BidServiceTest,BidCheckoutControllerIntegrationTest`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/main/java/com/dony/api/matching/BidContentRules.java \
        src/main/java/com/dony/api/matching/dto/BidRequest.java \
        src/main/java/com/dony/api/matching/dto/BidCheckoutRequest.java \
        src/main/java/com/dony/api/matching/BidService.java \
        src/main/java/com/dony/api/matching/BidCheckoutService.java \
        src/test/java/com/dony/api/matching
git commit -m "feat(bid-photos): photoKeys on create+checkout DTOs, refused-type guard, attach photos"
```

---

## Task A6: Expose `photos` on `BidResponse`

**Files:**
- Modify: `src/main/java/com/dony/api/matching/dto/BidResponse.java`
- Modify: `src/main/java/com/dony/api/matching/BidService.java` (`toResponse`)
- Test: extend `src/test/java/com/dony/api/matching/BidServiceTest.java`

- [ ] **Step 1: Add `photos` as the last component of `BidResponse`**

In `BidResponse.java`, change the tail:
```java
        String senderAvatarUrl,
        String travelerAvatarUrl,
        java.util.List<com.dony.api.matching.dto.BidPhotoResponse> photos
) {}
```

- [ ] **Step 2: Populate it in `toResponse`**

Find the single `new BidResponse(` construction inside `BidService.toResponse(...)`. Append, as the final constructor argument (matching the new component order):
```java
                bidPhotoService.activePhotos(<bidVar>.getId())
```
Replace `<bidVar>` with the bid variable name used in `toResponse` (e.g. `bid` or `saved`). Run:
```bash
grep -rn "new BidResponse(" src/main/java
```
If `new BidResponse(` appears more than once, update each, passing `bidPhotoService.activePhotos(<that-bid>.getId())` for the bid in scope.

- [ ] **Step 3: Assert it in the existing happy-path test**

In `BidServiceTest.createBid_valid_createsBidAndAudits`, add a stub before the call and an assertion after:
```java
            when(bidPhotoService.activePhotos(any())).thenReturn(java.util.List.of());
```
```java
            assertThat(result.photos()).isEmpty();
```

- [ ] **Step 4: Run tests**

Run: `./mvnw test -Dtest=BidServiceTest`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/matching/dto/BidResponse.java \
        src/main/java/com/dony/api/matching/BidService.java \
        src/test/java/com/dony/api/matching/BidServiceTest.java
git commit -m "feat(bid-photos): expose ACTIVE photos (presigned) on BidResponse"
```

---

## Task A7: Lifecycle listener — mark photos DELETING on terminal events

**Files:**
- Create: `src/main/java/com/dony/api/matching/BidPhotoLifecycleListener.java`
- Test: `src/test/java/com/dony/api/matching/BidPhotoLifecycleListenerTest.java`

- [ ] **Step 1: Write the failing test**

`src/test/java/com/dony/api/matching/BidPhotoLifecycleListenerTest.java`:
```java
package com.dony.api.matching;

import com.dony.api.matching.events.BidExpiredOnDepartureEvent;
import com.dony.api.matching.events.BidRejectedEvent;
import com.dony.api.matching.events.ParcelRefusedEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class BidPhotoLifecycleListenerTest {

    @Mock private BidPhotoService bidPhotoService;
    @InjectMocks private BidPhotoLifecycleListener listener;

    @Test
    void onRejected_marksDeleting() {
        UUID bid = UUID.randomUUID();
        listener.onRejected(new BidRejectedEvent(bid, UUID.randomUUID(), "reason"));
        verify(bidPhotoService).markDeletingForBid(bid);
    }

    @Test
    void onParcelRefused_marksDeleting() {
        UUID bid = UUID.randomUUID();
        listener.onParcelRefused(new ParcelRefusedEvent(bid, UUID.randomUUID(), UUID.randomUUID(), "r"));
        verify(bidPhotoService).markDeletingForBid(bid);
    }

    @Test
    void onExpired_marksDeleting() {
        UUID bid = UUID.randomUUID();
        listener.onExpired(new BidExpiredOnDepartureEvent(
                bid, UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID()));
        verify(bidPhotoService).markDeletingForBid(bid);
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./mvnw test -Dtest=BidPhotoLifecycleListenerTest`
Expected: COMPILE FAIL / no `BidPhotoLifecycleListener`.

- [ ] **Step 3: Write the listener**

`src/main/java/com/dony/api/matching/BidPhotoLifecycleListener.java`:
```java
package com.dony.api.matching;

import com.dony.api.matching.events.BidExpiredOnDepartureEvent;
import com.dony.api.matching.events.BidRejectedEvent;
import com.dony.api.matching.events.ParcelRefusedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Marque les photos d'un bid en DELETING dès qu'il atteint un état terminal.
 * BidRejectedEvent couvre REJECTED et CANCELLED (cancelBid republie cet event).
 * IN_TRANSIT / NO_SHOW n'ont pas d'event dédié ici → rattrapés par le balayage
 * défensif du BidPhotoCleanupScheduler.
 */
@Component
public class BidPhotoLifecycleListener {

    private final BidPhotoService bidPhotoService;

    public BidPhotoLifecycleListener(BidPhotoService bidPhotoService) {
        this.bidPhotoService = bidPhotoService;
    }

    @EventListener
    @Transactional
    public void onRejected(BidRejectedEvent event) {
        bidPhotoService.markDeletingForBid(event.getBidId());
    }

    @EventListener
    @Transactional
    public void onParcelRefused(ParcelRefusedEvent event) {
        bidPhotoService.markDeletingForBid(event.getBidId());
    }

    @EventListener
    @Transactional
    public void onExpired(BidExpiredOnDepartureEvent event) {
        bidPhotoService.markDeletingForBid(event.getBidId());
    }
}
```

- [ ] **Step 4: Run tests**

Run: `./mvnw test -Dtest=BidPhotoLifecycleListenerTest`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/matching/BidPhotoLifecycleListener.java \
        src/test/java/com/dony/api/matching/BidPhotoLifecycleListenerTest.java
git commit -m "feat(bid-photos): mark photos DELETING on reject/cancel/refuse/expire"
```

---

## Task A8: Daily purge cron + defensive sweep

**Files:**
- Create: `src/main/java/com/dony/api/matching/BidPhotoCleanupScheduler.java`
- Test: `src/test/java/com/dony/api/matching/BidPhotoCleanupSchedulerTest.java`

- [ ] **Step 1: Write the failing test**

`src/test/java/com/dony/api/matching/BidPhotoCleanupSchedulerTest.java`:
```java
package com.dony.api.matching;

import com.dony.api.common.StorageService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BidPhotoCleanupSchedulerTest {

    @Mock private BidPhotoRepository photoRepository;
    @Mock private BidRepository bidRepository;
    @Mock private StorageService storageService;
    @InjectMocks private BidPhotoCleanupScheduler scheduler;

    private BidPhotoEntity photo(UUID bidId, String key) {
        return new BidPhotoEntity(bidId, key, 0);
    }

    private BidEntity bidWithStatus(BidStatus status) {
        BidEntity b = new BidEntity();
        b.setStatus(status);
        return b;
    }

    @Test
    void purges_deletesFileThenRow() {
        BidPhotoEntity p = photo(UUID.randomUUID(), "bids/s/1.jpg");
        when(photoRepository.findByStatus(BidPhotoStatus.ACTIVE)).thenReturn(List.of());
        when(photoRepository.findByStatus(BidPhotoStatus.DELETING)).thenReturn(List.of(p));

        scheduler.purgeDeletingPhotos();

        verify(storageService).deleteFile("bids/s/1.jpg");
        verify(photoRepository).delete(p);
    }

    @Test
    void purges_removesRowEvenIfS3DeleteFails() {
        BidPhotoEntity p = photo(UUID.randomUUID(), "bids/s/1.jpg");
        when(photoRepository.findByStatus(BidPhotoStatus.ACTIVE)).thenReturn(List.of());
        when(photoRepository.findByStatus(BidPhotoStatus.DELETING)).thenReturn(List.of(p));
        doThrow(new RuntimeException("gone")).when(storageService).deleteFile(any());

        scheduler.purgeDeletingPhotos();

        verify(photoRepository).delete(p);
    }

    @Test
    void defensiveSweep_marksActivePhotoOfTerminalBidDeleting() {
        UUID bidId = UUID.randomUUID();
        BidPhotoEntity p = photo(bidId, "bids/s/1.jpg");
        when(photoRepository.findByStatus(BidPhotoStatus.ACTIVE)).thenReturn(List.of(p));
        when(photoRepository.findByStatus(BidPhotoStatus.DELETING)).thenReturn(List.of());
        when(bidRepository.findById(bidId)).thenReturn(Optional.of(bidWithStatus(BidStatus.IN_TRANSIT)));

        scheduler.purgeDeletingPhotos();

        assertThat(p.getStatus()).isEqualTo(BidPhotoStatus.DELETING);
        verify(photoRepository).save(p);
    }

    @Test
    void defensiveSweep_marksActivePhotoOfMissingBidDeleting() {
        UUID bidId = UUID.randomUUID();
        BidPhotoEntity p = photo(bidId, "bids/s/1.jpg");
        when(photoRepository.findByStatus(BidPhotoStatus.ACTIVE)).thenReturn(List.of(p));
        when(photoRepository.findByStatus(BidPhotoStatus.DELETING)).thenReturn(List.of());
        when(bidRepository.findById(bidId)).thenReturn(Optional.empty());

        scheduler.purgeDeletingPhotos();

        assertThat(p.getStatus()).isEqualTo(BidPhotoStatus.DELETING);
    }

    @Test
    void defensiveSweep_leavesActivePhotoOfAcceptedBid() {
        UUID bidId = UUID.randomUUID();
        BidPhotoEntity p = photo(bidId, "bids/s/1.jpg");
        when(photoRepository.findByStatus(BidPhotoStatus.ACTIVE)).thenReturn(List.of(p));
        when(photoRepository.findByStatus(BidPhotoStatus.DELETING)).thenReturn(List.of());
        when(bidRepository.findById(bidId)).thenReturn(Optional.of(bidWithStatus(BidStatus.ACCEPTED)));

        scheduler.purgeDeletingPhotos();

        assertThat(p.getStatus()).isEqualTo(BidPhotoStatus.ACTIVE);
    }
}
```

> `BidEntity` has a `setStatus(...)`. If it does not expose one, set status via the same reflection helper used elsewhere, or add a package-private setter.

- [ ] **Step 2: Run it to verify it fails**

Run: `./mvnw test -Dtest=BidPhotoCleanupSchedulerTest`
Expected: COMPILE FAIL / no scheduler class.

- [ ] **Step 3: Write the scheduler**

`src/main/java/com/dony/api/matching/BidPhotoCleanupScheduler.java`:
```java
package com.dony.api.matching;

import com.dony.api.common.StorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;

/**
 * Tous les jours à minuit : purge physiquement les photos DELETING (S3 + ligne) puis
 * balaye défensivement les photos ACTIVE dont le bid a atteint un état terminal/route
 * (rattrape un listener manqué et les bids de checkout abandonné, soft-deleted).
 */
@Component
public class BidPhotoCleanupScheduler {

    private static final Logger log = LoggerFactory.getLogger(BidPhotoCleanupScheduler.class);

    /** États du bid où les photos ne sont plus nécessaires et doivent être purgées. */
    private static final Set<BidStatus> DELETING_TRIGGER_STATES = Set.of(
            BidStatus.REJECTED, BidStatus.CANCELLED, BidStatus.EXPIRED,
            BidStatus.IN_TRANSIT, BidStatus.NO_SHOW, BidStatus.PARCEL_REFUSED,
            BidStatus.COMPLETED);

    private final BidPhotoRepository photoRepository;
    private final BidRepository bidRepository;
    private final StorageService storageService;

    public BidPhotoCleanupScheduler(BidPhotoRepository photoRepository,
                                    BidRepository bidRepository,
                                    StorageService storageService) {
        this.photoRepository = photoRepository;
        this.bidRepository = bidRepository;
        this.storageService = storageService;
    }

    @Scheduled(cron = "0 0 0 * * *")
    @Transactional
    public void purgeDeletingPhotos() {
        defensiveSweep();

        List<BidPhotoEntity> toPurge = photoRepository.findByStatus(BidPhotoStatus.DELETING);
        for (BidPhotoEntity photo : toPurge) {
            try {
                storageService.deleteFile(photo.getObjectKey());
            } catch (Exception e) {
                log.warn("BidPhotoCleanup: S3 delete failed for {} (key={}): {} — removing row anyway",
                        photo.getId(), photo.getObjectKey(), e.getMessage());
            }
            photoRepository.delete(photo);
        }
        if (!toPurge.isEmpty()) {
            log.info("BidPhotoCleanup: purged {} photos", toPurge.size());
        }
    }

    /** Passe en DELETING les photos ACTIVE dont le bid est terminal/route ou absent. */
    private void defensiveSweep() {
        List<BidPhotoEntity> active = photoRepository.findByStatus(BidPhotoStatus.ACTIVE);
        for (BidPhotoEntity photo : active) {
            BidStatus status = bidRepository.findById(photo.getBidId())
                    .map(BidEntity::getStatus)
                    .orElse(null);
            if (status == null || DELETING_TRIGGER_STATES.contains(status)) {
                photo.markDeleting();
                photoRepository.save(photo);
            }
        }
    }
}
```

> `bidRepository.findById` is filtered by the entity's `@Where (deleted_at IS NULL)`, so a soft-deleted (abandoned checkout) bid resolves to empty → `status == null` → its photos are swept.

- [ ] **Step 4: Run tests**

Run: `./mvnw test -Dtest=BidPhotoCleanupSchedulerTest`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the full backend suite + coverage**

Run: `./mvnw test`
Expected: all green.
Run: `./mvnw test jacoco:report` and confirm `target/site/jacoco/index.html` overall ≥ 90 %. Add tests for any new uncovered branch.

- [ ] **Step 6: Commit**

```bash
git add src/main/java/com/dony/api/matching/BidPhotoCleanupScheduler.java \
        src/test/java/com/dony/api/matching/BidPhotoCleanupSchedulerTest.java
git commit -m "feat(bid-photos): daily DELETING purge cron + defensive sweep"
```

---

# PART B — Frontend (`dony_app`)

> Run all frontend commands from the worktree root `/Users/aboubakardiakite/Desktop/dony/dony_app/.claude/worktrees/feature+bid-photos`. Already on a feature branch.

## Task B1: `BidPhoto` model + `photos` on `BidModel`

**Files:**
- Create: `lib/features/matching/data/models/bid_photo.dart`
- Modify: `lib/features/matching/data/models/bid_model.dart`
- Test: `test/features/matching/data/bid_photo_model_test.dart`

- [ ] **Step 1: Write the failing model test**

`test/features/matching/data/bid_photo_model_test.dart`:
```dart
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BidPhoto round-trips JSON', () {
    final p = BidPhoto.fromJson({'id': 'abc', 'url': 'https://signed/1'});
    expect(p.id, 'abc');
    expect(p.url, 'https://signed/1');
    expect(p.toJson(), {'id': 'abc', 'url': 'https://signed/1'});
  });
}
```

- [ ] **Step 2: Write the model**

`lib/features/matching/data/models/bid_photo.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'bid_photo.g.dart';

/// Photo de colis présignée renvoyée par le backend (ACTIVE uniquement).
@JsonSerializable()
class BidPhoto {
  final String id;
  final String url;

  const BidPhoto({required this.id, required this.url});

  factory BidPhoto.fromJson(Map<String, dynamic> json) => _$BidPhotoFromJson(json);

  Map<String, dynamic> toJson() => _$BidPhotoToJson(this);
}
```

- [ ] **Step 3: Add `photos` to `BidModel`**

In `lib/features/matching/data/models/bid_model.dart`, add the import after the existing import line:
```dart
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:json_annotation/json_annotation.dart';
```
Add the field at the end of the field declarations (just after `travelerAvatarUrl`):
```dart
  /// Photos du colis (présignées, ACTIVE). Vide si aucune ou après passage DELETING serveur.
  @JsonKey(defaultValue: <BidPhoto>[])
  final List<BidPhoto> photos;
```
Add to the constructor (after `this.travelerAvatarUrl,`):
```dart
    this.photos = const [],
```

- [ ] **Step 4: Re-run code generation**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: regenerates `bid_photo.g.dart` and `bid_model.g.dart` with the `photos` field.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/matching/data/bid_photo_model_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/data/models/bid_photo.dart \
        lib/features/matching/data/models/bid_photo.g.dart \
        lib/features/matching/data/models/bid_model.dart \
        lib/features/matching/data/models/bid_model.g.dart \
        test/features/matching/data/bid_photo_model_test.dart
git commit -m "feat(bid-photos): BidPhoto model + photos on BidModel"
```

---

## Task B2: Datasource + repository — upload & `photoKeys`

**Files:**
- Modify: `lib/features/matching/data/datasources/bid_remote_datasource.dart`
- Modify: `lib/features/matching/data/repositories/bid_repository.dart`
- Test: `test/features/matching/data/bid_remote_datasource_photos_test.dart`

- [ ] **Step 1: Add `uploadBidPhoto` + `photoKeys` to the datasource**

In `bid_remote_datasource.dart`, add this method inside `BidRemoteDatasource`:
```dart
  /// Upload une photo de colis (multipart) → renvoie la clé S3.
  Future<String> uploadBidPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'colis.jpg'),
    });
    final response = await _apiClient.dio.post('/bids/photos', data: formData);
    return (response.data as Map<String, dynamic>)['key'] as String;
  }
```
In `createBid(...)`, add a parameter `List<String>? photoKeys,` (place it before `gridItems`) and, in the body, after the `promoCode` block and before the `gridItems` block:
```dart
    if (photoKeys != null && photoKeys.isNotEmpty) {
      body['photoKeys'] = photoKeys;
    }
```
In `checkoutBid(...)`, add a parameter `List<String>? photoKeys,` (before `gridItems`) and, in the body, before the `gridItems` block:
```dart
    if (photoKeys != null && photoKeys.isNotEmpty) {
      body['photoKeys'] = photoKeys;
    }
```

- [ ] **Step 2: Thread through the repository**

In `bid_repository.dart`, add the pass-through:
```dart
  Future<String> uploadBidPhoto(String filePath) =>
      _datasource.uploadBidPhoto(filePath);
```
Add `List<String>? photoKeys,` to both `createBid(...)` and `checkoutBid(...)` signatures (before `gridItems`) and forward `photoKeys: photoKeys,` to the matching `_datasource` calls.

- [ ] **Step 3: Write the failing datasource test**

`test/features/matching/data/bid_remote_datasource_photos_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late BidRemoteDatasource datasource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test'));
    adapter = DioAdapter(dio: dio);
    datasource = BidRemoteDatasource(ApiClient.test(dio));
  });

  test('uploadBidPhoto POSTs multipart and returns key', () async {
    adapter.onPost('/bids/photos', (s) => s.reply(201, {'key': 'bids/s/1.jpg'}));
    // filePath irrelevant — adapter intercepts before file read in CI? If MultipartFile.fromFile
    // requires a real file, point at a temp file created in the test.
    final key = await datasource.uploadBidPhoto('test/fixtures/sample.jpg');
    expect(key, 'bids/s/1.jpg');
  });
}
```

> **Adapt to the repo's test harness.** Check how existing datasource tests build `ApiClient`/`Dio` (e.g. `bid_remote_datasource` may already have a test). If there is no `ApiClient.test(...)` factory or `http_mock_adapter` dependency, mirror the existing pattern used by the closest datasource test instead, and create a tiny real fixture file `test/fixtures/sample.jpg` if `MultipartFile.fromFile` needs one. If datasource HTTP is not unit-tested anywhere, cover `uploadBidPhoto`/`photoKeys` at the repository level with a mocked datasource instead and delete this file.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/matching/data/bid_remote_datasource_photos_test.dart`
Expected: PASS (or convert to repo-style as noted).

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data/datasources/bid_remote_datasource.dart \
        lib/features/matching/data/repositories/bid_repository.dart \
        test/features/matching/data/bid_remote_datasource_photos_test.dart
git commit -m "feat(bid-photos): uploadBidPhoto + photoKeys in datasource & repository"
```

---

## Task B3: `BidPhotosCubit` (upload list state) + analytics consts

**Files:**
- Create: `lib/features/matching/bloc/bid_photo_upload.dart`
- Create: `lib/features/matching/bloc/bid_photos_cubit.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/features/matching/bloc/bid_photos_cubit_test.dart`

- [ ] **Step 1: Add the analytics consts**

In `lib/core/services/analytics_events.dart`, in the `// Bids` block, after `bidRejected`:
```dart
  static const bidPhotoAdded   = 'bid_photo_added';
  static const bidPhotoRemoved = 'bid_photo_removed';
  static const bidPhotosViewed = 'bid_photos_viewed';
```

- [ ] **Step 2: Write the value object**

`lib/features/matching/bloc/bid_photo_upload.dart`:
```dart
enum BidPhotoUploadStatus { uploading, ready, failed }

/// Une photo locale en cours/terminée d'upload dans le formulaire de bid.
class BidPhotoUpload {
  final String localId;
  final String localPath;
  final BidPhotoUploadStatus status;
  final String? remoteKey;

  const BidPhotoUpload({
    required this.localId,
    required this.localPath,
    this.status = BidPhotoUploadStatus.uploading,
    this.remoteKey,
  });

  BidPhotoUpload copyWith({BidPhotoUploadStatus? status, String? remoteKey}) =>
      BidPhotoUpload(
        localId: localId,
        localPath: localPath,
        status: status ?? this.status,
        remoteKey: remoteKey ?? this.remoteKey,
      );
}
```

- [ ] **Step 3: Write the failing cubit test**

`test/features/matching/bloc/bid_photos_cubit_test.dart`:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class MockBidRepository extends Mock implements BidRepository {}

void main() {
  late MockBidRepository repo;
  late BidPhotosCubit cubit;

  setUp(() {
    repo = MockBidRepository();
    cubit = BidPhotosCubit(repo, makeDisabledAnalytics(MockAnalyticsBackend()));
  });

  test('add uploads and marks ready with key', () async {
    when(() => repo.uploadBidPhoto(any())).thenAnswer((_) async => 'bids/s/1.jpg');
    await cubit.add('/tmp/1.jpg');
    expect(cubit.state.single.status, BidPhotoUploadStatus.ready);
    expect(cubit.readyKeys, ['bids/s/1.jpg']);
  });

  test('add marks failed on error', () async {
    when(() => repo.uploadBidPhoto(any())).thenThrow(Exception('boom'));
    await cubit.add('/tmp/1.jpg');
    expect(cubit.state.single.status, BidPhotoUploadStatus.failed);
    expect(cubit.readyKeys, isEmpty);
  });

  test('caps at 4 photos', () async {
    when(() => repo.uploadBidPhoto(any())).thenAnswer((_) async => 'bids/s/x.jpg');
    for (var i = 0; i < 5; i++) {
      await cubit.add('/tmp/$i.jpg');
    }
    expect(cubit.state.length, 4);
    expect(cubit.canAddMore, isFalse);
  });

  test('remove drops the entry', () async {
    when(() => repo.uploadBidPhoto(any())).thenAnswer((_) async => 'bids/s/1.jpg');
    await cubit.add('/tmp/1.jpg');
    cubit.remove(cubit.state.single.localId);
    expect(cubit.state, isEmpty);
  });
}
```

> Uses the shared `test/features/helpers/mock_analytics_backend.dart` (`MockAnalyticsBackend`, `makeDisabledAnalytics`) already used by `bid_bloc_test.dart`.

- [ ] **Step 4: Write the cubit**

`lib/features/matching/bloc/bid_photos_cubit.dart`:
```dart
import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gère la liste des photos en cours/terminées d'upload pendant la création d'un bid.
class BidPhotosCubit extends Cubit<List<BidPhotoUpload>> {
  BidPhotosCubit(this._repository, this._analytics) : super(const []);

  final BidRepository _repository;
  final AnalyticsService _analytics;

  static const int maxPhotos = 4;
  int _counter = 0;

  bool get canAddMore => state.length < maxPhotos;

  /// Clés S3 des photos uploadées avec succès, à envoyer à la création du bid.
  List<String> get readyKeys => state
      .where((p) => p.status == BidPhotoUploadStatus.ready && p.remoteKey != null)
      .map((p) => p.remoteKey!)
      .toList();

  Future<void> add(String localPath) async {
    if (!canAddMore) return;
    final id = 'p${_counter++}';
    emit([...state, BidPhotoUpload(localId: id, localPath: localPath)]);
    try {
      final key = await _repository.uploadBidPhoto(localPath);
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(status: BidPhotoUploadStatus.ready, remoteKey: key)
          else
            p,
      ]);
      unawaited(_analytics.logEvent(AnalyticsEvents.bidPhotoAdded));
    } catch (_) {
      emit([
        for (final p in state)
          if (p.localId == id) p.copyWith(status: BidPhotoUploadStatus.failed) else p,
      ]);
    }
  }

  void remove(String localId) {
    emit(state.where((p) => p.localId != localId).toList());
    unawaited(_analytics.logEvent(AnalyticsEvents.bidPhotoRemoved));
  }
}
```

- [ ] **Step 5: Register in DI**

In `lib/core/di/injection.dart`, after the `BidBloc` registration block, add:
```dart
  getIt.registerFactory<BidPhotosCubit>(
    () => BidPhotosCubit(getIt<BidRepository>(), getIt<AnalyticsService>()),
  );
```
Add the import near the other matching bloc imports:
```dart
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/matching/bloc/bid_photos_cubit_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/matching/bloc/bid_photo_upload.dart \
        lib/features/matching/bloc/bid_photos_cubit.dart \
        lib/core/services/analytics_events.dart \
        lib/core/di/injection.dart \
        test/features/matching/bloc/bid_photos_cubit_test.dart
git commit -m "feat(bid-photos): BidPhotosCubit upload state + analytics consts"
```

---

## Task B4: Thread `photoKeys` through the create events

**Files:**
- Modify: `lib/features/matching/bloc/bid_event.dart`
- Modify: `lib/features/matching/bloc/bid_bloc.dart`
- Test: extend `test/features/matching/bloc/bid_bloc_test.dart`

- [ ] **Step 1: Add `photoKeys` to both create events**

In `bid_event.dart`, add `final List<String>? photoKeys;` and a `this.photoKeys,` constructor entry to **both** `BidCheckoutRequested` and `BidCreateRequested`:
```dart
  /// Clés S3 des photos déjà uploadées (≤ 4). Null/empty si aucune.
  final List<String>? photoKeys;
```
(constructor: add `this.photoKeys,` alongside the other optional named params.)

- [ ] **Step 2: Forward into the repository calls**

In `bid_bloc.dart`, in `_onCheckoutRequested` add `photoKeys: event.photoKeys,` to the `_repository.checkoutBid(...)` call; in `_onCreateRequested` add `photoKeys: event.photoKeys,` to the `_repository.createBid(...)` call.

- [ ] **Step 3: Extend the bloc test**

In `test/features/matching/bloc/bid_bloc_test.dart`, add a test that a `BidCreateRequested` with `photoKeys` forwards them. Mirror the existing create test, asserting:
```dart
    verify(() => repo.createBid(
          announcementId: any(named: 'announcementId'),
          weightKg: any(named: 'weightKg'),
          declaredValueEur: any(named: 'declaredValueEur'),
          description: any(named: 'description'),
          contentCategory: any(named: 'contentCategory'),
          recipientName: any(named: 'recipientName'),
          recipientPhone: any(named: 'recipientPhone'),
          paymentMethod: any(named: 'paymentMethod'),
          phoneNumber: any(named: 'phoneNumber'),
          countryCode: any(named: 'countryCode'),
          promoCode: any(named: 'promoCode'),
          photoKeys: ['bids/s/1.jpg'],
          gridItems: any(named: 'gridItems'),
        )).called(1);
```

> Match the existing `when(() => repo.createBid(...))` stub in that file — add `photoKeys: any(named: 'photoKeys'),` to the stub's named args so mocktail still matches.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/matching/bloc/bid_bloc_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/bloc/bid_event.dart \
        lib/features/matching/bloc/bid_bloc.dart \
        test/features/matching/bloc/bid_bloc_test.dart
git commit -m "feat(bid-photos): thread photoKeys through create/checkout events"
```

---

## Task B5: Photo section in the create-bid form

**Files:**
- Modify: `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart`
- Test: `test/features/matching/presentation/create_bid_photos_section_test.dart`

- [ ] **Step 1: Provide `BidPhotosCubit` to the sheet**

In `create_bid_bottom_sheet.dart`, add imports:
```dart
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:image_picker/image_picker.dart';
```
In `show()`, create the cubit alongside the other blocs:
```dart
    final bidBloc = getIt<BidBloc>();
    final paymentBloc = getIt<PaymentBloc>();
    final photosCubit = getIt<BidPhotosCubit>();
```
Add it to the `MultiBlocProvider` providers list:
```dart
          BlocProvider<BidPhotosCubit>.value(value: photosCubit),
```
And dispose it in `.whenComplete`:
```dart
      photosCubit.close();
```
Pass it to `_CreateBidContent` (add a `required this.photosCubit` field there) OR read it via `context.read<BidPhotosCubit>()` inside the form (the provider is ambient). Prefer `context.read` to avoid threading.

- [ ] **Step 2: Add the photo section widget**

Add this private widget at the bottom of the file:
```dart
class _PhotoSection extends StatelessWidget {
  const _PhotoSection();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final cubit = context.read<BidPhotosCubit>();
    try {
      final file = await getIt<DonyMediaService>().pick(source: source);
      if (file != null) {
        await cubit.add(file.path);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image non supportée')),
        );
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pick(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BidPhotosCubit, List<BidPhotoUpload>>(
      builder: (context, photos) {
        final canAdd = photos.length < BidPhotosCubit.maxPhotos;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'PHOTOS DU COLIS (OPTIONNEL)'),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                for (final p in photos)
                  _PhotoThumb(
                    upload: p,
                    onRemove: () => context.read<BidPhotosCubit>().remove(p.localId),
                  ),
                if (canAdd)
                  GestureDetector(
                    onTap: () => _showSourceSheet(context),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: kGreenLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGreenPrimary, width: 1.5),
                      ),
                      child: const Icon(Icons.add_rounded, color: kGreenPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DonySpacing.xxl),
          ],
        );
      },
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.upload, required this.onRemove});
  final BidPhotoUpload upload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(upload.localPath),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          if (upload.status == BidPhotoUploadStatus.uploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (upload.status == BidPhotoUploadStatus.failed)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kError.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline_rounded, color: kError, size: 18),
              ),
            ),
          Positioned(
            top: -6, right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: kTextPrimary, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```
Add `import 'dart:io';` at the top of the file if not present (for `File`). Use the palette/`DonySpacing` names already imported via `design_system.dart`; if `kGreenLight`/`kError`/`kTextPrimary` are not exported there, use the equivalents that file exposes (check `design_system.dart`).

- [ ] **Step 3: Render the section in the form**

In `_buildFormStep`, insert `const _PhotoSection()` right after the content-category section (after the closing `const SizedBox(height: DonySpacing.xxl)` that follows the category `Wrap`).

- [ ] **Step 4: Pass `photoKeys` at submit**

In `_CollectedFormData`, add a `final List<String>? photoKeys;` field + `this.photoKeys,` in its constructor. In `_goToPicker()` where `_formData` is built, add:
```dart
      photoKeys: context.read<BidPhotosCubit>().readyKeys,
```
In `_confirmPayment()`, add `photoKeys: data.photoKeys,` to all three dispatched events (`BidCreateRequested` Wave/Orange branch, `BidCreateRequested` cash branch, and `BidCheckoutRequested` Stripe branch).

- [ ] **Step 5: Write a widget test for the photo section**

`test/features/matching/presentation/create_bid_photos_section_test.dart`:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

void main() {
  testWidgets('shows add tile when under cap and thumbs for uploads', (tester) async {
    final cubit = MockBidPhotosCubit();
    when(() => cubit.state).thenReturn(const [
      BidPhotoUpload(localId: 'p0', localPath: '/tmp/a.jpg', status: BidPhotoUploadStatus.ready),
    ]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BlocProvider<BidPhotosCubit>.value(
          value: cubit,
          child: const _Harness(),
        ),
      ),
    ));

    expect(find.byIcon(Icons.add_rounded), findsOneWidget); // 1 < 4 → add tile visible
  });
}
```

> Because `_PhotoSection` is a private widget in the sheet file, either (a) extract `_PhotoSection`/`_PhotoThumb` into a small public file `lib/features/matching/presentation/widgets/create_bid/photo_section.dart` and test that directly (recommended — keeps the giant sheet file from growing), or (b) drive the full sheet via `CreateBidBottomSheet.show` in the widget test. Prefer (a): create `PhotoSection` as a public widget, import it into the sheet, and point this test's `_Harness` at it. Use `mocktail` + `bloc_test`'s `MockCubit`.

- [ ] **Step 6: Run tests + analyzer**

Run: `flutter analyze`
Expected: no new errors.
Run: `flutter test test/features/matching/presentation/create_bid_photos_section_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart \
        lib/features/matching/presentation/widgets/create_bid/photo_section.dart \
        test/features/matching/presentation/create_bid_photos_section_test.dart
git commit -m "feat(bid-photos): photo section in create-bid form (max 4, upload progress)"
```

---

## Task B6: Content step driven by announcement (accepted / custom / refused)

**Files:**
- Modify: `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart`
- Test: `test/features/matching/presentation/create_bid_content_step_test.dart`

- [ ] **Step 1: Replace the static category section**

In `_buildFormStep`, replace the content section (the `_SectionLabel(label: 'CONTENU DU COLIS')` + the `Wrap` over `_contentCategories`) with a call to a new builder that derives chips from the announcement. Keep `_contentCategories` as a fallback. Add this method to `_CreateBidContentState`:
```dart
  // Catégories acceptées = annonce si fournies, sinon liste statique de secours.
  List<String> get _acceptedCategories {
    final accepted = widget.announcement.acceptedContentTypes;
    if (accepted != null && accepted.isNotEmpty) return accepted;
    return _contentCategories;
  }

  List<String> get _refusedCategories =>
      widget.announcement.refusedTypes ?? const [];

  Widget _buildContentSection(Set<String> categories) {
    final accepted = _acceptedCategories;
    final refused = _refusedCategories;
    // Éléments custom = sélectionnés qui ne sont ni acceptés ni refusés.
    final custom = categories.where((c) => !accepted.contains(c)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'CONTENU DU COLIS'),
        const SizedBox(height: DonySpacing.md),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final cat in accepted)
              _CategoryChip(
                label: cat,
                selected: categories.contains(cat),
                onTap: () => _toggleCategory(categories, cat),
              ),
            for (final cat in custom)
              _CategoryChip(
                label: cat,
                selected: true,
                onTap: () => _toggleCategory(categories, cat),
              ),
            _AddCustomChip(onAdd: (value) {
              final v = value.trim();
              if (v.isEmpty) return;
              if (_refusedCategories
                  .map((e) => e.toLowerCase())
                  .contains(v.toLowerCase())) {
                return; // refusé → ignoré
              }
              final updated = Set<String>.from(categories)..add(v);
              _categoriesNotifier.value = updated;
            }),
          ],
        ).animate().fadeIn(delay: 60.ms),
        if (refused.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.md),
          const _SectionLabel(label: 'REFUSÉ PAR LE VOYAGEUR'),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: [
              for (final cat in refused) _RefusedChip(label: cat),
            ],
          ),
        ],
        const SizedBox(height: DonySpacing.xxl),
      ],
    );
  }

  void _toggleCategory(Set<String> categories, String cat) {
    final updated = Set<String>.from(categories);
    if (updated.contains(cat)) {
      updated.remove(cat);
    } else {
      updated.add(cat);
    }
    _categoriesNotifier.value = updated;
  }
```
Then in `_buildFormStep`, replace the old inline content block with:
```dart
            ValueListenableBuilder<Set<String>>(
              valueListenable: _categoriesNotifier,
              builder: (_, categories, __) => _buildContentSection(categories),
            ),
```
(If the existing code already wraps the category `Wrap` in a `ValueListenableBuilder` over `_categoriesNotifier`, reuse that builder's `categories` value and just swap its child for `_buildContentSection(categories)`.)

- [ ] **Step 2: Add the custom-add chip + refused chip widgets**

Add at the bottom of the file:
```dart
class _AddCustomChip extends StatelessWidget {
  const _AddCustomChip({required this.onAdd});
  final ValueChanged<String> onAdd;

  Future<void> _prompt(BuildContext context) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un élément'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex : Épices maison'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (value != null) onAdd(value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _prompt(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGreenPrimary, width: 1.4, style: BorderStyle.solid),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: kGreenPrimary),
            SizedBox(width: 4),
            Text('Ajouter', style: TextStyle(color: kGreenPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RefusedChip extends StatelessWidget {
  const _RefusedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kTextHint,
          decoration: TextDecoration.lineThrough,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```
(Use whatever palette tokens `design_system.dart` exposes for `kSurface`/`kBackground`/`kBorder`/`kTextHint`/`kGreenPrimary`; substitute if the names differ.)

- [ ] **Step 3: Write the content-step widget test**

`test/features/matching/presentation/create_bid_content_step_test.dart` — pump the create-bid sheet (or the extracted content section) with an `AnnouncementModel` whose `acceptedContentTypes: ['Vêtements']` and `refusedTypes: ['Hi-fi']`, then assert:
- `find.text('Vêtements')` is present and tappable (selectable chip),
- `find.text('Hi-fi')` is present,
- `find.text('REFUSÉ PAR LE VOYAGEUR')` is present,
- tapping `Ajouter` opens the dialog (`find.text('Ajouter un élément')`).

> Mirror an existing create-bid widget test (`create_bid_weight_section_test.dart`) for the harness (how it builds the `AnnouncementModel`, provides the blocs, and pumps the sheet). Reuse its `AnnouncementModel` builder and add the `acceptedContentTypes`/`refusedTypes` fields.

- [ ] **Step 4: Run tests + analyzer**

Run: `flutter analyze`
Run: `flutter test test/features/matching/presentation/create_bid_content_step_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart \
        test/features/matching/presentation/create_bid_content_step_test.dart
git commit -m "feat(bid-photos): content step driven by announcement accepted/refused + custom"
```

---

## Task B7: `BidPhotoViewerModal`

**Files:**
- Create: `lib/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart`
- Test: `test/features/matching/presentation/bid_photo_viewer_modal_test.dart`

- [ ] **Step 1: Write the failing widget test**

`test/features/matching/presentation/bid_photo_viewer_modal_test.dart`:
```dart
import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows counter and pages through photos', (tester) async {
    const photos = [
      BidPhoto(id: '1', url: 'https://x/1.jpg'),
      BidPhoto(id: '2', url: 'https://x/2.jpg'),
      BidPhoto(id: '3', url: 'https://x/3.jpg'),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: BidPhotoViewerModal(photos: photos, initialIndex: 1),
      ),
    ));
    await tester.pump();

    expect(find.text('Photo 2 / 3'), findsOneWidget);
  });
}
```

> `CachedNetworkImage` will try to load the network URLs; in a widget test it stays on the placeholder, which is fine — we assert on the counter, not the image. If the test environment complains about network image loading, wrap the pump in `mockNetworkImagesFor(() async { ... })` from `network_image_mock` if that dependency exists; otherwise the placeholder path is exercised without error.

- [ ] **Step 2: Write the viewer**

`lib/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:flutter/material.dart';

/// Visionneuse modale (carte arrondie, pas plein écran) des photos d'un colis.
/// Swipe + flèches + dots + compteur, fermeture par ✕ ou tap hors carte.
class BidPhotoViewerModal extends StatefulWidget {
  final List<BidPhoto> photos;
  final int initialIndex;

  const BidPhotoViewerModal({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<BidPhoto> photos,
    int initialIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (_) => BidPhotoViewerModal(photos: photos, initialIndex: initialIndex),
    );
  }

  @override
  State<BidPhotoViewerModal> createState() => _BidPhotoViewerModalState();
}

class _BidPhotoViewerModalState extends State<BidPhotoViewerModal> {
  late final PageController _controller;
  late final ValueNotifier<int> _index;

  @override
  void initState() {
    super.initState();
    _index = ValueNotifier<int>(widget.initialIndex);
    _controller = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.bidPhotosViewed,
        properties: {'photo_count': widget.photos.length},
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.photos.length;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorbe les taps dans la carte
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _index,
                        builder: (_, i, __) => Text(
                          'Photo ${i + 1} / $count',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: kBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 16, color: kTextPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: count,
                        onPageChanged: (i) => _index.value = i,
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: widget.photos[i].url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: kGreenPrimary),
                          ),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined, color: kTextHint),
                        ),
                      ),
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: _index,
                      builder: (_, current, __) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < count; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3.5),
                              width: i == current ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == current ? kGreenPrimary : kBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```
(Substitute palette tokens to match `design_system.dart` exports. Per AVD memory, this viewer deliberately avoids `InteractiveViewer`/`Opacity`/`RepaintBoundary` compositing layers that the test emulator struggles with.)

- [ ] **Step 3: Run tests + analyzer**

Run: `flutter analyze`
Run: `flutter test test/features/matching/presentation/bid_photo_viewer_modal_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart \
        test/features/matching/presentation/bid_photo_viewer_modal_test.dart
git commit -m "feat(bid-photos): swipeable modal photo viewer"
```

---

## Task B8: Gallery in the bid detail card + analytics table

**Files:**
- Modify: `lib/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart`
- Modify: `dony_app/CLAUDE.md` (analytics events table)
- Test: `test/features/matching/presentation/colis_destinataire_card_photos_test.dart`

- [ ] **Step 1: Add a photo gallery to the card**

In `colis_destinataire_card.dart`, add imports:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart';
```
Inside the `DetailCard`'s `Column`, before the existing `InfoRow(label: 'Colis', ...)`, add:
```dart
          if (bid.photos.isNotEmpty) ...[
            _PhotoGallery(photos: bid.photos),
            const SizedBox(height: DonySpacing.md),
          ],
```
Add the gallery widget at the bottom of the file:
```dart
class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.photos});
  final List<BidPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final shown = photos.take(3).toList();
    final extra = photos.length - shown.length;
    return Row(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => BidPhotoViewerModal.show(context, photos: photos, initialIndex: i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: shown[i].url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: kBackground),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, color: kTextHint),
                      ),
                      if (i == shown.length - 1 && extra > 0)
                        Container(
                          alignment: Alignment.center,
                          color: Colors.black54,
                          child: Text(
                            '+$extra',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (i != shown.length - 1) const SizedBox(width: DonySpacing.sm),
        ],
      ],
    );
  }
}
```
Add `import 'package:dony/features/matching/data/models/bid_photo.dart';` if not transitively available (it's referenced via `BidModel`).

- [ ] **Step 2: Update the analytics events table in `dony_app/CLAUDE.md`**

In the "Events actuellement implémentés" table, add rows:
```
| `bid_photo_added` | BidPhotosCubit.add() — photo de colis uploadée à la création de l'offre |
| `bid_photo_removed` | BidPhotosCubit.remove() — photo retirée avant soumission |
| `bid_photos_viewed` | BidPhotoViewerModal.initState — ouverture de la visionneuse (propriété `photo_count`) |
```

- [ ] **Step 3: Write the failing widget test**

`test/features/matching/presentation/colis_destinataire_card_photos_test.dart`:
```dart
import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BidModel bidWith(List<BidPhoto> photos) => BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        status: 'PENDING',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        photos: photos,
      );

  testWidgets('renders gallery when photos present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ColisDestinataireCard(
          bid: bidWith(const [BidPhoto(id: '1', url: 'https://x/1.jpg')]),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(ColisDestinataireCard), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets); // tappable thumbnail
  });

  testWidgets('no gallery when no photos', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ColisDestinataireCard(bid: bidWith(const []))),
    ));
    await tester.pump();
    expect(find.byType(ColisDestinataireCard), findsOneWidget);
  });
}
```

> Confirm `BidModel`'s required ctor args against the current model (id/announcementId/senderId/status/createdAt/updatedAt are required; the rest are optional). Adjust the builder if a required field was added since.

- [ ] **Step 4: Run tests + analyzer**

Run: `flutter analyze`
Run: `flutter test test/features/matching/presentation/colis_destinataire_card_photos_test.dart`
Expected: PASS.

- [ ] **Step 5: Full suite + coverage**

Run: `flutter test --coverage`
Expected: all green, overall ≥ 90 %. Add tests for any new uncovered branch.

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart \
        ../../../CLAUDE.md \
        test/features/matching/presentation/colis_destinataire_card_photos_test.dart
git commit -m "feat(bid-photos): photo gallery in bid detail + analytics events table"
```

> The `CLAUDE.md` path above is `dony_app/CLAUDE.md`; from the worktree root it is `CLAUDE.md`. Use `git add CLAUDE.md`.

---

## Final verification (both repos)

- [ ] Backend: `cd /Users/aboubakardiakite/Desktop/dony/dony-back && ./mvnw test` → all green; `./mvnw test jacoco:report` ≥ 90 %.
- [ ] Frontend: from worktree root `flutter analyze && flutter test --coverage` → all green, ≥ 90 %.
- [ ] Manual smoke (optional, emulator): create a bid with 2 photos (Stripe path → checkout, and cash path → create), open the traveler detail, tap a thumbnail → modal swipes; reject the bid → next cron tick (or a manual call to `purgeDeletingPhotos`) removes the rows.
- [ ] Open PRs separately: one in `dony-back` (`feature/bid-photos`), one in `dony_app` (this branch). Cross-link them; the frontend depends on the backend contract being deployed.

---

## Spec coverage check
- Photos optional, max 4 → A1/A3 (`MAX_PHOTOS`), B3 (`maxPhotos`), B5 (add tile hidden at 4). ✅
- Traveler sees photos before accepting, swipeable modal (not fullscreen) → A6 (`photos` on response), B7 viewer, B8 gallery. ✅
- Photos persist after acceptance (ACTIVE while ACCEPTED/HANDED_OVER) → A8 trigger set excludes ACCEPTED/HANDED_OVER. ✅
- DELETING on route/reject/cancel/etc. + daily midnight purge, single path → A7 listener, A8 cron `0 0 0 * * *`. ✅
- Refuse → photos deleted via same path → A7 `onRejected` (REJECTED) + A8 purge. ✅
- Content driven by announcement accepted/refused + custom, pass-through → A5 refused guard, B6 content step. ✅
- Pre-upload then reference (`photoKeys`) → A4 endpoint, A5 DTOs, B2 datasource. ✅
- Analytics + table → B3 consts, B8 table. ✅
- Tests ≥ 90 % both repos → per-task tests + final verification. ✅
