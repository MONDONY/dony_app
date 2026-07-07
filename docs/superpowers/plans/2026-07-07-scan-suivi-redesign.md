# Scan & Suivi Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the voyageur "Scan & Suivi" hub into a colis-first screen (per-colis progress + quick scan actions + inline number entry + scan history), supporting multiple simultaneous active trips.

**Architecture:** One small backend addition (a grouped scan-history endpoint, reusing existing `TrackingEventEntity`/`BidEntity` data with no schema change) plus a frontend rewrite of `scan_hub_selectors.dart`, `scan_hub_cubit.dart`, and `scan_hub_screen.dart` in `dony_app`. Existing screens (`ScanIdentifyScreen`, `ScanPhotoScreen`, `OfflineScanQueueScreen`) are reused unchanged — this plan only touches the hub itself plus the small backend/data-layer additions it needs.

**Tech Stack:** Spring Boot 3 / Java 21 (dony-back), Flutter/Dart with flutter_bloc + GetIt (dony_app).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-07-scan-suivi-redesign-design.md` (dony_app repo) — every requirement in this plan traces back to it.
- **Two separate git repos.** Task 1 is in `dony-back` (needs its own dedicated branch/worktree — do NOT run it inside the `dony_app` worktree). Tasks 2–6 are in `dony_app`, in the current worktree (`scan-suivi-redesign`, branch `worktree-scan-suivi-redesign`).
- Never commit directly on `main` in either repo — always a dedicated branch (already satisfied: this plan's frontend tasks run on `worktree-scan-suivi-redesign`; Task 1 needs its own `dony-back` branch, e.g. `feature/scan-hub-history-endpoint`).
- No `Co-Authored-By: Claude` in any commit message.
- Backend: RFC 7807 errors via `DonyBusinessException` (existing pattern) — never raw exceptions from the controller.
- Frontend: BLoC only (no `setState`), GoRouter only (no `Navigator.push`) — already the case in the touched files, preserve it.
- `selectScannableTrip` (singular) is used ONLY inside `scan_hub_cubit.dart`, `scan_hub_selectors.dart`, and their own test files — confirmed via repo-wide search. Safe to rename to `selectScannableTrips` (plural) with no wrapper needed elsewhere.

---

### Task 1: Backend — grouped scan-history endpoint

**Repo:** `dony-back` — create a dedicated branch (e.g. `git checkout -b feature/scan-hub-history-endpoint`) before starting. Do not run this task inside the `dony_app` worktree.

**Files:**
- Modify: `dony-back/src/main/java/com/dony/api/tracking/TrackingEventRepository.java`
- Create: `dony-back/src/main/java/com/dony/api/tracking/dto/TripScanHistoryEntryDto.java`
- Modify: `dony-back/src/main/java/com/dony/api/tracking/TrackingService.java`
- Modify: `dony-back/src/main/java/com/dony/api/tracking/TrackingController.java`
- Test: `dony-back/src/test/java/com/dony/api/tracking/TrackingServiceTest.java`

**Interfaces:**
- Consumes: existing `BidRepository.findByAnnouncementId(UUID)` (already exists — confirmed in `BidRepository.java:124`), existing `AnnouncementRepository.findById`, `UserRepository.findByFirebaseUid`, `BidEntity.getTrackingNumber()`/`getRecipientName()`, `TrackingEventEntity.getBidId()`/`getEventType()`/`getScannedAt()`.
- Produces: `GET /tracking/announcements/{announcementId}/events` → `List<TripScanHistoryEntryDto>` (fields: `donNumber`, `recipientName`, `eventType`, `scannedAt`), most recent first. 401 if unauthenticated, 403 if the caller isn't the trip's traveler, 404 if the announcement doesn't exist. Frontend Task 3 calls this endpoint.

- [ ] **Step 1: Write the failing tests**

Append to `dony-back/src/test/java/com/dony/api/tracking/TrackingServiceTest.java`, just before the final closing `}` of the class (after the `getEvents_withHttpPhotoUrl_returnsUrlAsIs` test):

```java
    // ── getTripScanHistory ────────────────────────────────────────────────────

    @Test
    void getTripScanHistory_announcementNotFound_throwsNotFound() {
        when(announcementRepository.findById(annId)).thenReturn(Optional.empty());
        assertDonyError(() -> service.getTripScanHistory(annId, "uid-traveler"), "announcement-not-found");
    }

    @Test
    void getTripScanHistory_notTraveler_throwsForbidden() {
        AnnouncementEntity ann = buildAnnouncement();
        UserEntity outsider = buildUser(UUID.randomUUID(), "uid-other");
        when(announcementRepository.findById(annId)).thenReturn(Optional.of(ann));
        when(userRepository.findByFirebaseUid("uid-other")).thenReturn(Optional.of(outsider));

        assertDonyError(() -> service.getTripScanHistory(annId, "uid-other"), "forbidden");
    }

    @Test
    void getTripScanHistory_noBids_returnsEmptyList() {
        AnnouncementEntity ann = buildAnnouncement();
        UserEntity traveler = buildUser(travelerId, "uid-traveler");
        when(announcementRepository.findById(annId)).thenReturn(Optional.of(ann));
        when(userRepository.findByFirebaseUid("uid-traveler")).thenReturn(Optional.of(traveler));
        when(bidRepository.findByAnnouncementId(annId)).thenReturn(List.of());

        List<TripScanHistoryEntryDto> result = service.getTripScanHistory(annId, "uid-traveler");

        assertThat(result).isEmpty();
    }

    @Test
    void getTripScanHistory_success_returnsSortedEvents() {
        AnnouncementEntity ann = buildAnnouncement();
        UserEntity traveler = buildUser(travelerId, "uid-traveler");
        BidEntity bid = buildBid(BidStatus.HANDED_OVER, "qt");
        bid.setRecipientName("Awa Ndiaye");
        TrackingEventEntity event = new TrackingEventEntity();
        setId(event, UUID.randomUUID());
        event.setBidId(bidId);
        event.setEventType(TrackingEventType.DEPART);
        event.setScannedAt(LocalDateTime.now(ZoneOffset.UTC));

        when(announcementRepository.findById(annId)).thenReturn(Optional.of(ann));
        when(userRepository.findByFirebaseUid("uid-traveler")).thenReturn(Optional.of(traveler));
        when(bidRepository.findByAnnouncementId(annId)).thenReturn(List.of(bid));
        when(trackingEventRepository.findByBidIdInOrderByScannedAtDesc(List.of(bidId)))
                .thenReturn(List.of(event));

        List<TripScanHistoryEntryDto> result = service.getTripScanHistory(annId, "uid-traveler");

        assertThat(result).hasSize(1);
        assertThat(result.get(0).donNumber()).isEqualTo("TRK000001");
        assertThat(result.get(0).recipientName()).isEqualTo("Awa Ndiaye");
        assertThat(result.get(0).eventType()).isEqualTo("DEPART");
    }
```

Add the import, alongside the other `com.dony.api.tracking.dto.*` imports near the top of the file:

```java
import com.dony.api.tracking.dto.TripScanHistoryEntryDto;
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd dony-back && ./mvnw test -Dtest=TrackingServiceTest -q`
Expected: FAIL — compile error, `TrackingService.getTripScanHistory` and `TripScanHistoryEntryDto` don't exist yet, and `TrackingEventRepository.findByBidIdInOrderByScannedAtDesc` doesn't exist yet.

- [ ] **Step 3: Add the repository method**

In `dony-back/src/main/java/com/dony/api/tracking/TrackingEventRepository.java`, add a second method to the interface:

```java
package com.dony.api.tracking;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TrackingEventRepository extends JpaRepository<TrackingEventEntity, UUID> {

    List<TrackingEventEntity> findByBidIdOrderByScannedAtAsc(UUID bidId);

    List<TrackingEventEntity> findByBidIdInOrderByScannedAtDesc(List<UUID> bidIds);
}
```

- [ ] **Step 4: Create the DTO**

Create `dony-back/src/main/java/com/dony/api/tracking/dto/TripScanHistoryEntryDto.java`:

```java
package com.dony.api.tracking.dto;

import java.time.LocalDateTime;

public record TripScanHistoryEntryDto(
        String donNumber,
        String recipientName,
        String eventType,
        LocalDateTime scannedAt
) {}
```

- [ ] **Step 5: Add the service method**

In `dony-back/src/main/java/com/dony/api/tracking/TrackingService.java`:

Add two imports near the top, alongside the existing `com.dony.api.tracking.dto.*` imports and `java.util.*` imports:

```java
import com.dony.api.tracking.dto.TripScanHistoryEntryDto;
```

```java
import java.util.stream.Collectors;
```

Add the method after `getEvents` (after the closing `}` of `getEvents`, before `toEventResponse`):

```java
    @Transactional(readOnly = true)
    public List<TripScanHistoryEntryDto> getTripScanHistory(UUID announcementId, String firebaseUid) {
        AnnouncementEntity announcement = announcementRepository.findById(announcementId)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "announcement-not-found", "Announcement Not Found",
                        "Annonce introuvable"));

        UserEntity currentUser = userRepository.findByFirebaseUid(firebaseUid)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.UNAUTHORIZED, "user-not-found", "User Not Found",
                        "Utilisateur introuvable"));

        if (!announcement.getTravelerId().equals(currentUser.getId())) {
            throw new DonyBusinessException(HttpStatus.FORBIDDEN, "forbidden", "Forbidden",
                    "Accès interdit à l'historique de ce trajet");
        }

        List<BidEntity> bids = bidRepository.findByAnnouncementId(announcementId);
        if (bids.isEmpty()) {
            return List.of();
        }
        Map<UUID, BidEntity> bidsById = bids.stream()
                .collect(Collectors.toMap(BidEntity::getId, bid -> bid));
        List<UUID> bidIds = new java.util.ArrayList<>(bidsById.keySet());

        return trackingEventRepository.findByBidIdInOrderByScannedAtDesc(bidIds).stream()
                .map(event -> {
                    BidEntity bid = bidsById.get(event.getBidId());
                    return new TripScanHistoryEntryDto(
                            bid != null ? bid.getTrackingNumber() : null,
                            bid != null ? bid.getRecipientName() : null,
                            event.getEventType().name(),
                            event.getScannedAt());
                })
                .toList();
    }
```

- [ ] **Step 6: Add the controller endpoint**

In `dony-back/src/main/java/com/dony/api/tracking/TrackingController.java`, add the import:

```java
import com.dony.api.tracking.dto.TripScanHistoryEntryDto;
```

Add the endpoint after `getEvents`:

```java
    @GetMapping("/announcements/{announcementId}/events")
    public ResponseEntity<List<TripScanHistoryEntryDto>> getTripScanHistory(
            @PathVariable UUID announcementId,
            @AuthenticationPrincipal String firebaseUid) {
        return ResponseEntity.ok(trackingService.getTripScanHistory(announcementId, firebaseUid));
    }
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd dony-back && ./mvnw test -Dtest=TrackingServiceTest -q`
Expected: PASS, all tests in the file green (existing ones + the 4 new ones).

- [ ] **Step 8: Run the full backend suite**

Run: `cd dony-back && ./mvnw test`
Expected: BUILD SUCCESS, 0 failures (this is a pure addition — no existing behavior touched).

- [ ] **Step 9: Commit**

```bash
cd dony-back
git add src/main/java/com/dony/api/tracking/TrackingEventRepository.java \
        src/main/java/com/dony/api/tracking/dto/TripScanHistoryEntryDto.java \
        src/main/java/com/dony/api/tracking/TrackingService.java \
        src/main/java/com/dony/api/tracking/TrackingController.java \
        src/test/java/com/dony/api/tracking/TrackingServiceTest.java
git commit -m "feat(tracking): grouped scan-history endpoint for a trip's colis

GET /tracking/announcements/{id}/events returns every tracking event
across all of a trip's bids, most recent first — avoids an N+1
fan-out (one call per colis) from the redesigned Scan & Suivi hub."
```

Push the branch and open a draft PR against `dony-back`'s `main` (matches this session's standing convention): `git push -u origin feature/scan-hub-history-endpoint`, then `gh pr create --draft`.

---

### Task 2: Frontend — multi-trip selection + next-step derivation in `scan_hub_selectors.dart`

**Repo:** `dony_app`, current worktree (`scan-suivi-redesign`).

**Files:**
- Modify: `lib/features/tracking/bloc/scan_hub_selectors.dart`
- Test: `test/features/tracking/bloc/scan_hub_selectors_test.dart`

**Interfaces:**
- Consumes: `AnnouncementModel` (`id`, `status`, `departureDate`), `BidModel` (`status`) — both already exist, unchanged.
- Produces: `List<AnnouncementModel> selectScannableTrips(List<AnnouncementModel> trips)` (replaces `selectScannableTrip`), `String? nextRequiredStep(BidModel bid)` (returns `'DEPART'`/`'TRANSIT'`/`'ARRIVEE'`/`null`), `({bool depart, bool transit, bool arrivee}) colisStepProgress(BidModel bid)`. `ScanHubProgress`/`computeScanProgress` unchanged. Task 4 (cubit) and Task 5 (screen) consume these.

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `test/features/tracking/bloc/scan_hub_selectors_test.dart`:

```dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _trip(String id, String status, DateTime date) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: date,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

BidModel _bid(String status) => BidModel(
      id: 'b-$status',
      announcementId: 'a',
      senderId: 's',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('selectScannableTrips', () {
    test('IN_PROGRESS triés par date, avant les ACTIVE/FULL triés par date', () {
      final trips = [
        _trip('1', 'ACTIVE', DateTime(2026, 7, 1)),
        _trip('2', 'IN_PROGRESS', DateTime(2026, 6, 20)),
        _trip('3', 'IN_PROGRESS', DateTime(2026, 6, 10)),
        _trip('4', 'FULL', DateTime(2026, 6, 28)),
      ];
      final result = selectScannableTrips(trips);
      expect(result.map((t) => t.id), ['3', '2', '4', '1']);
    });

    test('un seul trajet scannable → liste à un élément', () {
      final trips = [_trip('1', 'IN_PROGRESS', DateTime(2026, 6, 20))];
      expect(selectScannableTrips(trips).map((t) => t.id), ['1']);
    });

    test('aucun trajet scannable → liste vide', () {
      expect(
        selectScannableTrips([_trip('1', 'CANCELLED', DateTime(2026, 1, 1))]),
        isEmpty,
      );
      expect(selectScannableTrips(const []), isEmpty);
    });
  });

  group('computeScanProgress', () {
    test('confirmés et scannés départ dérivés du statut', () {
      final bids = [
        _bid('ACCEPTED'),
        _bid('HANDED_OVER'),
        _bid('IN_TRANSIT'),
        _bid('COMPLETED'),
        _bid('REJECTED'),
        _bid('PENDING'),
      ];
      final p = computeScanProgress(bids);
      expect(p.confirmedColis, 4); // ACCEPTED+HANDED_OVER+IN_TRANSIT+COMPLETED
      expect(p.scannedDepart, 3); // HANDED_OVER+IN_TRANSIT+COMPLETED
    });

    test('liste vide → zéros', () {
      final p = computeScanProgress(const []);
      expect(p.confirmedColis, 0);
      expect(p.scannedDepart, 0);
    });
  });

  group('nextRequiredStep', () {
    test('ACCEPTED → DEPART', () {
      expect(nextRequiredStep(_bid('ACCEPTED')), 'DEPART');
    });
    test('HANDED_OVER → TRANSIT', () {
      expect(nextRequiredStep(_bid('HANDED_OVER')), 'TRANSIT');
    });
    test('IN_TRANSIT → ARRIVEE', () {
      expect(nextRequiredStep(_bid('IN_TRANSIT')), 'ARRIVEE');
    });
    test('COMPLETED → null (tout est déjà scanné)', () {
      expect(nextRequiredStep(_bid('COMPLETED')), isNull);
    });
  });

  group('colisStepProgress', () {
    test('ACCEPTED → aucune étape faite', () {
      final p = colisStepProgress(_bid('ACCEPTED'));
      expect(p.depart, isFalse);
      expect(p.transit, isFalse);
      expect(p.arrivee, isFalse);
    });
    test('HANDED_OVER → départ fait seulement', () {
      final p = colisStepProgress(_bid('HANDED_OVER'));
      expect(p.depart, isTrue);
      expect(p.transit, isFalse);
      expect(p.arrivee, isFalse);
    });
    test('IN_TRANSIT → départ + transit faits', () {
      final p = colisStepProgress(_bid('IN_TRANSIT'));
      expect(p.depart, isTrue);
      expect(p.transit, isTrue);
      expect(p.arrivee, isFalse);
    });
    test('COMPLETED → tout fait', () {
      final p = colisStepProgress(_bid('COMPLETED'));
      expect(p.depart, isTrue);
      expect(p.transit, isTrue);
      expect(p.arrivee, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/tracking/bloc/scan_hub_selectors_test.dart`
Expected: FAIL — `selectScannableTrips`, `nextRequiredStep`, `colisStepProgress` don't exist yet (compile error).

- [ ] **Step 3: Rewrite the selectors**

Replace the entire contents of `lib/features/tracking/bloc/scan_hub_selectors.dart`:

```dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

const _confirmedStatuses = {'ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'};
const _departedStatuses = {'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'};
const _transitStatuses = {'IN_TRANSIT', 'COMPLETED'};
const _arrivedStatuses = {'COMPLETED'};

class ScanHubProgress {
  const ScanHubProgress({
    required this.confirmedColis,
    required this.scannedDepart,
  });

  final int confirmedColis;
  final int scannedDepart;
}

/// Tous les trajets scannables du voyageur : `IN_PROGRESS` triés par date de
/// départ en premier, puis `ACTIVE`/`FULL` triés par date de départ. Un
/// voyageur peut avoir plusieurs trajets actifs en même temps — contrairement
/// à l'ancien `selectScannableTrip` (singulier), rien n'est ici filtré à un
/// seul résultat.
List<AnnouncementModel> selectScannableTrips(List<AnnouncementModel> trips) {
  int byDate(AnnouncementModel a, AnnouncementModel b) =>
      a.departureDate.compareTo(b.departureDate);

  final inProgress = trips.where((t) => t.status == 'IN_PROGRESS').toList()
    ..sort(byDate);
  final upcoming = trips
      .where((t) => t.status == 'ACTIVE' || t.status == 'FULL')
      .toList()
    ..sort(byDate);
  return [...inProgress, ...upcoming];
}

ScanHubProgress computeScanProgress(List<BidModel> bids) {
  return ScanHubProgress(
    confirmedColis:
        bids.where((b) => _confirmedStatuses.contains(b.status)).length,
    scannedDepart:
        bids.where((b) => _departedStatuses.contains(b.status)).length,
  );
}

/// Étape à scanner ensuite pour ce colis, dérivée de son statut. `null` si
/// toutes les étapes sont déjà scannées (statut `COMPLETED`).
String? nextRequiredStep(BidModel bid) {
  if (_arrivedStatuses.contains(bid.status)) return null;
  if (_transitStatuses.contains(bid.status)) return 'ARRIVEE';
  if (_departedStatuses.contains(bid.status)) return 'TRANSIT';
  return 'DEPART';
}

/// Progression par étape d'un colis — pilote les 3 points affichés sur sa
/// ligne dans la liste du hub.
({bool depart, bool transit, bool arrivee}) colisStepProgress(BidModel bid) => (
      depart: _departedStatuses.contains(bid.status),
      transit: _transitStatuses.contains(bid.status),
      arrivee: _arrivedStatuses.contains(bid.status),
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tracking/bloc/scan_hub_selectors_test.dart`
Expected: PASS, all tests green.

Note: `scan_hub_cubit.dart` still calls `selectScannableTrip` (singular) at this point — this task will not compile the whole project yet, that's expected and fixed in Task 4. Confirm with `flutter analyze lib/features/tracking/bloc/scan_hub_selectors.dart` (that single file analyzes clean) rather than a full-project analyze here.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tracking/bloc/scan_hub_selectors.dart test/features/tracking/bloc/scan_hub_selectors_test.dart
git commit -m "feat(tracking): multi-trip selection + per-colis next-step in scan hub selectors

selectScannableTrips replaces selectScannableTrip (singular) — a
voyageur can have several IN_PROGRESS/ACTIVE/FULL trips at once, all
now surfaced instead of only the earliest one. nextRequiredStep and
colisStepProgress derive a colis's next scan step and per-step
progress from its bid status, for the redesigned colis-first hub."
```

---

### Task 3: Frontend — trip scan-history model + repository method

**Files:**
- Create: `lib/features/tracking/data/models/trip_scan_history_entry_model.dart`
- Modify: `lib/features/tracking/data/tracking_repository.dart`
- Test: `test/features/tracking/data/trip_scan_history_entry_model_test.dart`
- Test: `test/features/tracking/data/tracking_repository_test.dart` (create if it doesn't exist, otherwise extend)

**Interfaces:**
- Consumes: `ApiClient` (existing, injected into `TrackingRepository`).
- Produces: `TripScanHistoryEntryModel` (`donNumber`, `recipientName`, `eventType`, `scannedAt` — mirrors backend `TripScanHistoryEntryDto` from Task 1), `TrackingRepository.getTripScanHistory(String announcementId) → Future<List<TripScanHistoryEntryModel>>`. Task 4 (cubit) consumes this.

- [ ] **Step 1: Check whether a repository test file already exists**

Run: `ls test/features/tracking/data/tracking_repository_test.dart`

If it exists, read it first and follow its existing mocking pattern (likely `DioAdapter` or a mocked `ApiClient`/`Dio`) for Step 2 below instead of the pattern shown. If it does not exist (expected — `TrackingRepository` currently has no dedicated test file), create it fresh as shown.

- [ ] **Step 2: Write the failing tests**

Create `test/features/tracking/data/trip_scan_history_entry_model_test.dart`:

```dart
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripScanHistoryEntryModel.fromJson', () {
    test('parses a full entry', () {
      final model = TripScanHistoryEntryModel.fromJson({
        'donNumber': 'TRK000001',
        'recipientName': 'Awa Ndiaye',
        'eventType': 'DEPART',
        'scannedAt': '2026-06-20T14:32:00',
      });

      expect(model.donNumber, 'TRK000001');
      expect(model.recipientName, 'Awa Ndiaye');
      expect(model.eventType, 'DEPART');
      expect(model.scannedAt, DateTime(2026, 6, 20, 14, 32));
    });

    test('donNumber/recipientName null when the bid was deleted', () {
      final model = TripScanHistoryEntryModel.fromJson({
        'donNumber': null,
        'recipientName': null,
        'eventType': 'TRANSIT',
        'scannedAt': '2026-06-20T15:00:00',
      });

      expect(model.donNumber, isNull);
      expect(model.recipientName, isNull);
    });
  });
}
```

Create `test/features/tracking/data/tracking_repository_test.dart` (only if Step 1 found none already exists):

```dart
import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockApiClient apiClient;
  late _MockDio dio;
  late TrackingRepository repository;

  setUp(() {
    apiClient = _MockApiClient();
    dio = _MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    repository = TrackingRepository(apiClient);
  });

  group('getTripScanHistory', () {
    test('maps the response list to TripScanHistoryEntryModel', () async {
      when(() => dio.get('/tracking/announcements/trip-1/events')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: [
            {
              'donNumber': 'TRK000001',
              'recipientName': 'Awa Ndiaye',
              'eventType': 'DEPART',
              'scannedAt': '2026-06-20T14:32:00',
            },
          ],
        ),
      );

      final result = await repository.getTripScanHistory('trip-1');

      expect(result, hasLength(1));
      expect(result.first.donNumber, 'TRK000001');
      expect(result.first.eventType, 'DEPART');
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/tracking/data/trip_scan_history_entry_model_test.dart test/features/tracking/data/tracking_repository_test.dart`
Expected: FAIL — `TripScanHistoryEntryModel` doesn't exist yet, `TrackingRepository.getTripScanHistory` doesn't exist yet.

- [ ] **Step 4: Create the model**

Create `lib/features/tracking/data/models/trip_scan_history_entry_model.dart`:

```dart
class TripScanHistoryEntryModel {
  final String? donNumber;
  final String? recipientName;
  final String eventType;
  final DateTime scannedAt;

  const TripScanHistoryEntryModel({
    this.donNumber,
    this.recipientName,
    required this.eventType,
    required this.scannedAt,
  });

  factory TripScanHistoryEntryModel.fromJson(Map<String, dynamic> json) =>
      TripScanHistoryEntryModel(
        donNumber: json['donNumber'] as String?,
        recipientName: json['recipientName'] as String?,
        eventType: json['eventType'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
      );
}
```

- [ ] **Step 5: Add the repository method**

In `lib/features/tracking/data/tracking_repository.dart`, add the import:

```dart
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
```

Add the method after `getEvents`:

```dart
  Future<List<TripScanHistoryEntryModel>> getTripScanHistory(
    String announcementId,
  ) async {
    final response = await _apiClient.dio
        .get('/tracking/announcements/$announcementId/events');
    final list = response.data as List<dynamic>;
    return list
        .map((e) =>
            TripScanHistoryEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/tracking/data/trip_scan_history_entry_model_test.dart test/features/tracking/data/tracking_repository_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/tracking/data/models/trip_scan_history_entry_model.dart \
        lib/features/tracking/data/tracking_repository.dart \
        test/features/tracking/data/trip_scan_history_entry_model_test.dart \
        test/features/tracking/data/tracking_repository_test.dart
git commit -m "feat(tracking): TripScanHistoryEntryModel + TrackingRepository.getTripScanHistory

Frontend data layer for the grouped scan-history endpoint added in
the dony-back companion PR."
```

---

### Task 4: Frontend — multi-trip state in `scan_hub_cubit.dart`

**Files:**
- Modify: `lib/features/tracking/bloc/scan_hub_cubit.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/features/tracking/bloc/scan_hub_cubit_test.dart`

**Interfaces:**
- Consumes: `selectScannableTrips`, `computeScanProgress` (Task 2), `TrackingRepository.getTripScanHistory` (Task 3), existing `AnnouncementRepository.getMyAnnouncements()` (returns `({List<AnnouncementModel> announcements, int totalElements})`), existing `BidRepository.getBidsForAnnouncement(String) → Future<List<BidModel>>`.
- Produces: `ScanHubLoaded` gains `trips` (`List<AnnouncementModel>`), `selectedTripId` (`String`), `bidsByTrip` (`Map<String, List<BidModel>>`), `scanHistory` (`List<TripScanHistoryEntryModel>`), plus computed getters `selectedTrip`, `selectedTripBids`, `progress`. New method `ScanHubCubit.selectTrip(String tripId)`. Task 5 and Task 6 (screen) consume this shape.

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `test/features/tracking/bloc/scan_hub_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockBidRepo extends Mock implements BidRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockTrackingRepo extends Mock implements TrackingRepository {}

AnnouncementModel _trip(String id, String status, [DateTime? date]) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: date ?? DateTime(2026, 6, 10),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

BidModel _bid(String id, String status) => BidModel(
      id: id,
      announcementId: 'a',
      senderId: 's',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockAnnouncementRepo annRepo;
  late _MockBidRepo bidRepo;
  late _MockAnalytics analytics;
  late _MockTrackingRepo trackingRepo;

  setUp(() {
    annRepo = _MockAnnouncementRepo();
    bidRepo = _MockBidRepo();
    analytics = _MockAnalytics();
    trackingRepo = _MockTrackingRepo();
  });

  blocTest<ScanHubCubit, ScanHubState>(
    'aucun trajet → ScanHubEmpty',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
      );
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubEmpty>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'un trajet IN_PROGRESS → ScanHubLoaded avec ce trajet sélectionné',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
      );
      when(() => bidRepo.getBidsForAnnouncement('a'))
          .thenAnswer((_) async => []);
      when(() => trackingRepo.getTripScanHistory('a'))
          .thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>()
          .having((s) => s.trips.map((t) => t.id), 'trips', ['a'])
          .having((s) => s.selectedTripId, 'selectedTripId', 'a'),
    ],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'deux trajets actifs → trips contient les deux, le plus proche sélectionné',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (
          announcements: [
            _trip('later', 'IN_PROGRESS', DateTime(2026, 7, 1)),
            _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6, 1)),
          ],
          totalElements: 2,
        ),
      );
      when(() => bidRepo.getBidsForAnnouncement(any()))
          .thenAnswer((_) async => []);
      when(() => trackingRepo.getTripScanHistory('soonest'))
          .thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>()
          .having((s) => s.trips.map((t) => t.id), 'trips',
              ['soonest', 'later'])
          .having((s) => s.selectedTripId, 'selectedTripId', 'soonest'),
    ],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'erreur réseau → ScanHubError',
    build: () {
      when(() => annRepo.getMyAnnouncements())
          .thenThrow(Exception('Network error'));
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubError>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'trajet ACTIVE sans bids → ScanHubLoaded avec compteurs à zéro',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('b', 'ACTIVE')], totalElements: 1),
      );
      when(() => bidRepo.getBidsForAnnouncement('b'))
          .thenAnswer((_) async => []);
      when(() => trackingRepo.getTripScanHistory('b'))
          .thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>().having(
        (s) => s.progress.confirmedColis,
        'confirmedColis',
        0,
      ),
    ],
  );

  group('selectTrip', () {
    blocTest<ScanHubCubit, ScanHubState>(
      'change selectedTripId immédiatement, puis met à jour scanHistory',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (
            announcements: [
              _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6, 1)),
              _trip('later', 'IN_PROGRESS', DateTime(2026, 7, 1)),
            ],
            totalElements: 2,
          ),
        );
        when(() => bidRepo.getBidsForAnnouncement(any()))
            .thenAnswer((_) async => []);
        when(() => trackingRepo.getTripScanHistory('soonest'))
            .thenAnswer((_) async => []);
        when(() => trackingRepo.getTripScanHistory('later')).thenAnswer(
          (_) async => [
            TripScanHistoryEntryModel(
              donNumber: 'TRK000002',
              recipientName: 'Moussa Diop',
              eventType: 'DEPART',
              scannedAt: DateTime(2026, 6, 20, 14),
            ),
          ],
        );
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('later');
      },
      skip: 2, // ScanHubLoading + the initial ScanHubLoaded from load()
      expect: () => [
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'later')
            .having((s) => s.scanHistory, 'scanHistory', isEmpty),
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'later')
            .having((s) => s.scanHistory, 'scanHistory', hasLength(1)),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'même trajet déjà sélectionné → aucun nouvel état',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async =>
              (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
        );
        when(() => bidRepo.getBidsForAnnouncement('a'))
            .thenAnswer((_) async => []);
        when(() => trackingRepo.getTripScanHistory('a'))
            .thenAnswer((_) async => []);
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('a');
      },
      skip: 2,
      expect: () => [],
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/tracking/bloc/scan_hub_cubit_test.dart`
Expected: FAIL — compile error (`ScanHubCubit` constructor takes 3 args not 4, `ScanHubLoaded` doesn't have `trips`/`selectedTripId`/`scanHistory`, `selectTrip` doesn't exist).

- [ ] **Step 3: Rewrite the cubit**

Replace the entire contents of `lib/features/tracking/bloc/scan_hub_cubit.dart`:

```dart
import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

sealed class ScanHubState {
  const ScanHubState();
}

class ScanHubLoading extends ScanHubState {
  const ScanHubLoading();
}

class ScanHubEmpty extends ScanHubState {
  const ScanHubEmpty();
}

class ScanHubError extends ScanHubState {
  const ScanHubError(this.message);

  final String message;
}

class ScanHubLoaded extends ScanHubState {
  const ScanHubLoaded({
    required this.trips,
    required this.selectedTripId,
    required this.bidsByTrip,
    required this.scanHistory,
  });

  final List<AnnouncementModel> trips;
  final String selectedTripId;
  final Map<String, List<BidModel>> bidsByTrip;
  final List<TripScanHistoryEntryModel> scanHistory;

  AnnouncementModel get selectedTrip =>
      trips.firstWhere((t) => t.id == selectedTripId);

  List<BidModel> get selectedTripBids =>
      bidsByTrip[selectedTripId] ?? const [];

  ScanHubProgress get progress => computeScanProgress(selectedTripBids);
}

class ScanHubCubit extends Cubit<ScanHubState> {
  ScanHubCubit(
    this._announcementRepo,
    this._bidRepo,
    this._analytics,
    this._trackingRepo,
  ) : super(const ScanHubLoading());

  final AnnouncementRepository _announcementRepo;
  final BidRepository _bidRepo;
  // ignore: unused_field
  final AnalyticsService _analytics;
  final TrackingRepository _trackingRepo;

  Future<void> load() async {
    emit(const ScanHubLoading());
    try {
      final result = await _announcementRepo.getMyAnnouncements();
      final trips = selectScannableTrips(result.announcements);
      if (trips.isEmpty) {
        emit(const ScanHubEmpty());
        return;
      }

      final bidsByTrip = <String, List<BidModel>>{};
      for (final trip in trips) {
        bidsByTrip[trip.id] = await _bidRepo.getBidsForAnnouncement(trip.id);
      }

      final selectedTripId = trips.first.id;
      final scanHistory =
          await _trackingRepo.getTripScanHistory(selectedTripId);

      emit(ScanHubLoaded(
        trips: trips,
        selectedTripId: selectedTripId,
        bidsByTrip: bidsByTrip,
        scanHistory: scanHistory,
      ));
    } catch (e) {
      emit(ScanHubError(e.toString()));
    }
  }

  /// Bascule le trajet affiché — pas de rechargement des trajets/colis (déjà
  /// en mémoire depuis [load]), seul l'historique de scans du nouveau trajet
  /// est refetché (potentiellement volumineux, inutile de le précharger pour
  /// des trajets jamais consultés).
  Future<void> selectTrip(String tripId) async {
    final current = state;
    if (current is! ScanHubLoaded || current.selectedTripId == tripId) return;

    emit(ScanHubLoaded(
      trips: current.trips,
      selectedTripId: tripId,
      bidsByTrip: current.bidsByTrip,
      scanHistory: const [],
    ));

    try {
      final scanHistory = await _trackingRepo.getTripScanHistory(tripId);
      final latest = state;
      if (latest is ScanHubLoaded && latest.selectedTripId == tripId) {
        emit(ScanHubLoaded(
          trips: latest.trips,
          selectedTripId: tripId,
          bidsByTrip: latest.bidsByTrip,
          scanHistory: scanHistory,
        ));
      }
    } catch (_) {
      // L'historique reste vide pour ce trajet si le fetch échoue — le
      // reste de l'écran (colis, scan rapide) demeure utilisable.
    }
  }
}
```

- [ ] **Step 4: Update DI registration**

In `lib/core/di/injection.dart`, replace the `ScanHubCubit` registration (around line 578):

```dart
  getIt.registerFactory<ScanHubCubit>(
    () => ScanHubCubit(
      getIt<AnnouncementRepository>(),
      getIt<BidRepository>(),
      getIt<AnalyticsService>(),
    ),
  );
```

with:

```dart
  getIt.registerFactory<ScanHubCubit>(
    () => ScanHubCubit(
      getIt<AnnouncementRepository>(),
      getIt<BidRepository>(),
      getIt<AnalyticsService>(),
      getIt<TrackingRepository>(),
    ),
  );
```

`TrackingRepository` is already registered as a lazy singleton earlier in the same file (confirmed at `injection.dart:565`) — no new registration needed, just the extra constructor argument.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/tracking/bloc/scan_hub_cubit_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/tracking/bloc/scan_hub_cubit.dart lib/core/di/injection.dart`
Expected: no new errors or warnings (info-level pre-existing lints elsewhere in `injection.dart` are fine).

Note: `lib/features/tracking/presentation/screens/scan_hub_screen.dart` still references the old `ScanHubLoaded(trip:, progress:)` shape at this point and will NOT compile — expected, fixed in Task 5. Do not run a whole-project `flutter analyze` or `flutter test` yet.

- [ ] **Step 7: Commit**

```bash
git add lib/features/tracking/bloc/scan_hub_cubit.dart lib/core/di/injection.dart test/features/tracking/bloc/scan_hub_cubit_test.dart
git commit -m "feat(tracking): ScanHubCubit tracks multiple active trips + scan history

ScanHubLoaded gains trips/selectedTripId/bidsByTrip/scanHistory.
selectTrip() switches the active trip without reloading trips/bids
(already in memory) — only that trip's scan history is (re)fetched,
lazily, so trips the voyageur never views never cost a request."
```

---

### Task 5: Frontend — `scan_hub_screen.dart` structural rewrite (switcher, hero, sync banner, quick steps, colis list, history)

**Files:**
- Modify: `lib/features/tracking/presentation/screens/scan_hub_screen.dart`
- Test: `test/features/tracking/presentation/scan_hub_screen_test.dart`

**Interfaces:**
- Consumes: `ScanHubLoaded` (Task 4: `trips`, `selectedTripId`, `selectedTrip`, `selectedTripBids`, `scanHistory`, `progress`), `nextRequiredStep`/`colisStepProgress` (Task 2), `HiveService.offlineQueue` (existing, `getIt<HiveService>()`).
- Produces: the rewritten `ScanHubView`/`ScanHubScreen` widget tree (minus the number-entry field, added in Task 6). `_TripSwitcher`, `_TripHeroCompact`, `_SyncBanner`, `_QuickScanSteps`, `_ColisListSection`, `_ColisRow`, `_ScanHistorySection` are new private widgets in this file.

This task intentionally leaves a placeholder `SizedBox(height: DonySpacing.base)` where Task 6 inserts `_NumberEntryField` — the screen is fully functional and tested without it; Task 6 slots it in.

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `test/features/tracking/presentation/scan_hub_screen_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockScanHubCubit extends MockCubit<ScanHubState>
    implements ScanHubCubit {}

class _FakePathProviderPlatform extends PlatformInterface
    implements PathProviderPlatform {
  _FakePathProviderPlatform() : super(token: _token);
  static final Object _token = Object();

  @override
  Future<String?> getTemporaryPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getApplicationSupportPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getApplicationDocumentsPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getLibraryPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getExternalStoragePath() async => '.dart_tool/test_hive';
  @override
  Future<List<String>?> getExternalCachePaths() async => ['.dart_tool/test_hive'];
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async =>
      ['.dart_tool/test_hive'];
  @override
  Future<String?> getDownloadsPath() async => '.dart_tool/test_hive';
}

AnnouncementModel _trip(String id, {String status = 'IN_PROGRESS'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: DateTime(2026, 6, 22),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

BidModel _bid(String id, String status, {String? recipientName}) => BidModel(
      id: id,
      announcementId: 'trip-1',
      senderId: 's',
      status: status,
      recipientName: recipientName,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

GoRouter _router(ScanHubCubit cubit) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => BlocProvider<ScanHubCubit>.value(
        value: cubit,
        child: const ScanHubView(),
      ),
    ),
    GoRoute(
      path: '/tracking/scan/identify',
      builder: (_, __) => const Scaffold(body: Text('identify')),
    ),
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (_, __) => const Scaffold(body: Text('offline-queue')),
    ),
    GoRoute(
      path: '/announcements/trips',
      builder: (_, __) => const Scaffold(body: Text('mes-trajets')),
    ),
    GoRoute(
      path: '/bids/:id',
      builder: (_, state) =>
          Scaffold(body: Text('bid-${state.pathParameters['id']}')),
    ),
  ],
);

Widget _wrap(ScanHubCubit cubit) =>
    MaterialApp.router(routerConfig: _router(cubit));

void main() {
  late _MockScanHubCubit cubit;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    Hive.init('.dart_tool/test_hive');
    await getIt<HiveService>().init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    cubit = _MockScanHubCubit();
    await getIt<HiveService>().offlineQueue.clear();
  });

  ScanHubLoaded loadedState({
    List<AnnouncementModel>? trips,
    String? selectedTripId,
    Map<String, List<BidModel>>? bidsByTrip,
  }) {
    final resolvedTrips = trips ?? [_trip('trip-1')];
    return ScanHubLoaded(
      trips: resolvedTrips,
      selectedTripId: selectedTripId ?? resolvedTrips.first.id,
      bidsByTrip: bidsByTrip ?? {resolvedTrips.first.id: []},
      scanHistory: const [],
    );
  }

  testWidgets('affiche titre et 3 boutons scan rapide quand ScanHubLoaded', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(loadedState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Scan & Suivi'), findsOneWidget);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
  });

  testWidgets('affiche corridor du trajet réel', (tester) async {
    when(() => cubit.state).thenReturn(loadedState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paris'), findsOneWidget);
    expect(find.textContaining('Dakar'), findsOneWidget);
  });

  testWidgets('affiche état vide quand ScanHubEmpty', (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubEmpty());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Aucun trajet à scanner'), findsOneWidget);
  });

  testWidgets('affiche loading quand ScanHubLoading', (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubLoading());
    await tester.pumpWidget(_wrap(cubit));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tap Départ navigue vers identify', (tester) async {
    when(() => cubit.state).thenReturn(loadedState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.tap(find.text('Départ'));
    await tester.pumpAndSettle();
    expect(find.text('identify'), findsOneWidget);
  });

  testWidgets(
    'état vide — tap Voir mes trajets navigue vers /announcements/trips',
    (tester) async {
      when(() => cubit.state).thenReturn(const ScanHubEmpty());
      await tester.pumpWidget(_wrap(cubit));
      await tester.tap(find.text('Voir mes trajets'));
      await tester.pumpAndSettle();
      expect(find.text('mes-trajets'), findsOneWidget);
    },
  );

  group('switcher multi-trajet', () {
    testWidgets('masqué quand un seul trajet actif', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip_switcher')), findsNothing);
    });

    testWidgets('visible quand plusieurs trajets actifs, filtre au tap', (
      tester,
    ) async {
      final tripA = _trip('trip-a');
      final tripB = _trip('trip-b');
      when(() => cubit.state).thenReturn(loadedState(
        trips: [tripA, tripB],
        selectedTripId: 'trip-a',
        bidsByTrip: {'trip-a': [], 'trip-b': []},
      ));
      whenListen(
        cubit,
        Stream<ScanHubState>.empty(),
        initialState: loadedState(
          trips: [tripA, tripB],
          selectedTripId: 'trip-a',
          bidsByTrip: {'trip-a': [], 'trip-b': []},
        ),
      );
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip_switcher')), findsOneWidget);

      await tester.tap(find.text('Paris → Dakar').last);
      await tester.pumpAndSettle();
      verify(() => cubit.selectTrip('trip-b')).called(1);
    });
  });

  group('liste des colis', () {
    testWidgets('affiche une ligne par colis avec son nom', (tester) async {
      when(() => cubit.state).thenReturn(loadedState(
        bidsByTrip: {
          'trip-1': [_bid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye')],
        },
      ));
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.textContaining('Awa Ndiaye'), findsOneWidget);
    });

    testWidgets('tap sur la ligne (hors bouton Scan) navigue vers la fiche colis', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(loadedState(
        bidsByTrip: {
          'trip-1': [_bid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye')],
        },
      ));
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Awa Ndiaye'));
      await tester.pumpAndSettle();
      expect(find.text('bid-bid-1'), findsOneWidget);
    });

    testWidgets('tap Scan sur une ligne route vers identify avec l\'étape déduite', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(loadedState(
        bidsByTrip: {
          'trip-1': [_bid('bid-1', 'HANDED_OVER', recipientName: 'Awa Ndiaye')],
        },
      ));
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('identify'), findsOneWidget);
    });
  });

  group('historique des scans', () {
    testWidgets('message vide quand aucun scan', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.text('Aucun scan pour l\'instant'), findsOneWidget);
    });
  });

  group('bandeau synchro', () {
    testWidgets('absent quand la queue offline est vide', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync_banner')), findsNothing);
    });

    testWidgets(
      'visible et tap navigue vers /tracking/offline-queue quand un scan du trajet actif est en attente',
      (tester) async {
        when(() => cubit.state).thenReturn(loadedState(
          bidsByTrip: {
            'trip-1': [_bid('bid-1', 'ACCEPTED')],
          },
        ));
        await getIt<HiveService>().offlineQueue.add({
          'bidId': 'bid-1',
          'eventType': 'DEPART',
          'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
        });

        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sync_banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('sync_banner')));
        await tester.pumpAndSettle();
        expect(find.text('offline-queue'), findsOneWidget);
      },
    );

    testWidgets(
      'absent quand la queue offline ne contient que des colis d\'un autre trajet',
      (tester) async {
        when(() => cubit.state).thenReturn(loadedState(
          bidsByTrip: {
            'trip-1': [_bid('bid-1', 'ACCEPTED')],
          },
        ));
        await getIt<HiveService>().offlineQueue.add({
          'bidId': 'bid-from-another-trip',
          'eventType': 'DEPART',
          'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
        });

        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sync_banner')), findsNothing);
      },
    );
  });

  testWidgets('aucun overflow sur petit écran (320 dp)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => cubit.state).thenReturn(loadedState(
      bidsByTrip: {
        'trip-1': [_bid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye')],
      },
    ));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

Note: this test file uses a real `HiveService`/`Hive` box (matching how the offline queue is genuinely read in production, no fake abstraction) rather than mocking `HiveService` — `getIt<HiveService>()` must already be registered as it is in the app's real DI setup; the test only initializes the Hive backend and clears the box between tests. If `HiveService.init()` has a different exact method name than shown, check `lib/core/storage/hive_service.dart` and adjust — it's the method that calls `Hive.openBox<Map>(offlineQueueBox)`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/tracking/presentation/scan_hub_screen_test.dart`
Expected: FAIL — compile error (old `ScanHubLoaded(trip:, progress:)` constructor call in the test no longer exists after Task 4; screen file itself also still uses the old shape).

- [ ] **Step 3: Rewrite the screen**

Replace the entire contents of `lib/features/tracking/presentation/screens/scan_hub_screen.dart`:

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class _EtapeInfo {
  final String code;
  final String label;
  final String? iconAsset;
  final bool photoRequired;

  const _EtapeInfo(
    this.code,
    this.label, {
    this.iconAsset,
    required this.photoRequired,
  });
}

const _etapes = [
  _EtapeInfo(
    'DEPART',
    'Départ',
    iconAsset: 'plane-takeoff',
    photoRequired: true,
  ),
  _EtapeInfo(
    'TRANSIT',
    'Transit',
    iconAsset: 'arrow-left-right',
    photoRequired: false,
  ),
  _EtapeInfo(
    'ARRIVEE',
    'Arrivée',
    iconAsset: 'plane-landing',
    photoRequired: true,
  ),
];

class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key, this.onTrackParcel});

  /// Entrée additive « Suivre un colis » (voyageur pro). Null = non affichée.
  final VoidCallback? onTrackParcel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ScanHubCubit>()..load(),
      child: ScanHubView(onTrackParcel: onTrackParcel),
    );
  }
}

class ScanHubView extends StatelessWidget {
  const ScanHubView({super.key, this.onTrackParcel});

  final VoidCallback? onTrackParcel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Scan & Suivi', style: tt.headlineLarge),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocBuilder<ScanHubCubit, ScanHubState>(
        builder: (context, state) {
          switch (state) {
            case ScanHubLoading():
              return Center(
                child: CircularProgressIndicator(color: cs.primary),
              );
            case ScanHubError(:final message):
              return _ErrorState(
                message: message,
                onRetry: () => context.read<ScanHubCubit>().load(),
              );
            case ScanHubEmpty():
              return const _NoTripState();
            case ScanHubLoaded():
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  100 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onTrackParcel != null) ...[
                      SecondaryActivityEntry(
                        iconAsset: 'package',
                        label: 'Suivre un colis',
                        onTap: onTrackParcel!,
                      ),
                      const SizedBox(height: DonySpacing.lg),
                    ],
                    if (state.trips.length > 1) ...[
                      _TripSwitcher(state: state),
                      const SizedBox(height: DonySpacing.base),
                    ],
                    _TripHeroCompact(trip: state.selectedTrip),
                    const SizedBox(height: DonySpacing.base),
                    _SyncBanner(state: state),
                    const _EtapesSection(),
                    const SizedBox(height: DonySpacing.base),
                    // Task 6 inserts _NumberEntryField here.
                    const SizedBox(height: DonySpacing.xl),
                    _ColisListSection(bids: state.selectedTripBids),
                    const SizedBox(height: DonySpacing.xl),
                    _ScanHistorySection(history: state.scanHistory),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return DateFormat('d MMMM yyyy', 'fr').format(date);
}

// ── Switcher multi-trajet ────────────────────────────────────────────────────

class _TripSwitcher extends StatelessWidget {
  const _TripSwitcher({required this.state});
  final ScanHubLoaded state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('trip_switcher'),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.trips.length,
        separatorBuilder: (_, __) => const SizedBox(width: DonySpacing.sm),
        itemBuilder: (context, i) {
          final trip = state.trips[i];
          final active = trip.id == state.selectedTripId;
          return DonyPressable(
            onTap: () => context.read<ScanHubCubit>().selectTrip(trip.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: active ? cs.primary : cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: active ? cs.primary : cs.outline,
                ),
              ),
              child: Text(
                '${trip.departureCity} → ${trip.arrivalCity} · '
                '${_formatDate(trip.departureDate)}',
                style: tt.labelMedium?.copyWith(
                  color: active ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Hero trajet compact ──────────────────────────────────────────────────────

class _TripHeroCompact extends StatelessWidget {
  const _TripHeroCompact({required this.trip});
  final AnnouncementModel trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.departureCity} → ${trip.arrivalCity}',
            style: tt.headlineMedium?.copyWith(
              color: DonyColors.neutral0,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatDate(trip.departureDate),
            style: tt.bodySmall?.copyWith(
              color: DonyColors.neutral0.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04);
  }
}

// ── Bandeau synchro ──────────────────────────────────────────────────────────

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state});
  final ScanHubLoaded state;

  @override
  Widget build(BuildContext context) {
    final bidIds = state.selectedTripBids.map((b) => b.id).toSet();
    final queue = getIt<HiveService>().offlineQueue;
    final pendingCount = queue.values.where((raw) {
      final entry = Map<String, dynamic>.from(raw as Map);
      return bidIds.contains(entry['bidId']);
    }).length;

    if (pendingCount == 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: DonyPressable(
        key: const Key('sync_banner'),
        onTap: () => context.push('/tracking/offline-queue'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.warningLight,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.warning),
          ),
          child: Row(
            children: [
              DonyIcon('triangle-alert', color: cs.warning, size: 16),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  '$pendingCount scan${pendingCount > 1 ? 's' : ''} en '
                  'attente de synchro',
                  style: tt.bodySmall?.copyWith(
                    color: cs.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DonyIcon('chevron-right', color: cs.warning, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / error states ─────────────────────────────────────────────────────

class _NoTripState extends StatelessWidget {
  const _NoTripState();

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      title: 'Aucun trajet à scanner',
      description:
          'Tu pourras scanner les colis dès qu\'une demande sera acceptée sur l\'un de tes trajets.',
      mascotte: DonyMascotteType.assis,
      actionLabel: 'Voir mes trajets',
      onAction: () => context.push('/announcements/trips'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      mascotte: DonyMascotteType.assis,
      title: 'Impossible de charger les trajets',
      description: message,
      type: DonyEmptyStateType.error,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

// ── Scan rapide (3 boutons étape) ────────────────────────────────────────────

class _EtapesSection extends StatelessWidget {
  const _EtapesSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCAN RAPIDE',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: _etapes
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: e.code == 'ARRIVEE' ? 0 : DonySpacing.sm,
                    ),
                    child: _EtapeChip(etape: e),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _EtapeChip extends StatelessWidget {
  const _EtapeChip({required this.etape});
  final _EtapeInfo etape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DonyPressable(
      onTap: () => context.push(
        '/tracking/scan/identify',
        extra: <String, dynamic>{'etape': etape.code, 'focusNumber': false},
      ),
      child: DonyCard(
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md,
          horizontal: DonySpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (etape.iconAsset) {
              'plane-takeoff' => const DonyEmoji.planeTakeoff(size: 24),
              'plane-landing' => const DonyEmoji.planeLanding(size: 24),
              final String asset => DonyIcon(asset, size: 24, color: cs.onSurface),
              _ => const SizedBox(width: 24, height: 24),
            },
            const SizedBox(height: DonySpacing.sm),
            Text(
              etape.label,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DonySpacing.xs),
            SizedBox(
              height: 20,
              width: double.infinity,
              child: etape.photoRequired
                  ? const FittedBox(fit: BoxFit.scaleDown, child: _PhotoBadge())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.errorLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('camera', size: 11, color: cs.error),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'Photo',
            style: tt.labelSmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liste des colis ──────────────────────────────────────────────────────────

class _ColisListSection extends StatelessWidget {
  const _ColisListSection({required this.bids});
  final List<BidModel> bids;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COLIS (${bids.length})',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (bids.isEmpty)
          Text(
            'Aucun colis confirmé sur ce trajet pour l\'instant.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          ...bids.map(
            (bid) => Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xs),
              child: _ColisRow(bid: bid),
            ),
          ),
      ],
    );
  }
}

class _ColisRow extends StatelessWidget {
  const _ColisRow({required this.bid});
  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = colisStepProgress(bid);
    final nextStep = nextRequiredStep(bid);
    final label = bid.recipientName ?? bid.id;

    return DonyPressable(
      onTap: () => context.push('/bids/${bid.id}'),
      child: DonyCard(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Row(
                    children: [
                      _StepDot(done: progress.depart),
                      const SizedBox(width: DonySpacing.xxs),
                      _StepDot(done: progress.transit),
                      const SizedBox(width: DonySpacing.xxs),
                      _StepDot(done: progress.arrivee),
                    ],
                  ),
                ],
              ),
            ),
            if (nextStep != null)
              DonyPressable(
                onTap: () => context.push(
                  '/tracking/scan/identify',
                  extra: <String, dynamic>{
                    'etape': nextStep,
                    'focusNumber': false,
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    'Scan',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 18,
      height: 4,
      decoration: BoxDecoration(
        color: done ? cs.success : cs.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
    );
  }
}

// ── Historique des scans ─────────────────────────────────────────────────────

class _ScanHistorySection extends StatelessWidget {
  const _ScanHistorySection({required this.history});
  final List<TripScanHistoryEntryModel> history;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORIQUE DES SCANS',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (history.isEmpty)
          Text(
            'Aucun scan pour l\'instant',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          ...history.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xs),
              child: Row(
                children: [
                  Text(
                    DateFormat('HH:mm').format(entry.scannedAt),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      entry.recipientName ?? entry.donNumber ?? '—',
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.successLight,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      switch (entry.eventType) {
                        'DEPART' => 'Départ',
                        'TRANSIT' => 'Transit',
                        'ARRIVEE' => 'Arrivée',
                        _ => entry.eventType,
                      },
                      style: tt.labelSmall?.copyWith(
                        color: cs.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tracking/presentation/scan_hub_screen_test.dart`
Expected: PASS, all tests green.

If `DonyPressable`, `DonyCard`, `cs.warningLight`/`cs.warning`/`cs.successLight`/`cs.success` don't resolve exactly as named, check `lib/core/design/design_system.dart` and the `DonyStatusColors` extension referenced in `lib/core/design/CLAUDE.md` (already read earlier this session) and adjust the token names — the visual intent (warning-tinted banner, success-tinted badge) is what matters, not these exact identifiers if the design system evolved.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/tracking/presentation/screens/scan_hub_screen.dart`
Expected: no new errors. Info-level lints matching the rest of the codebase's existing tolerance are fine.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tracking/presentation/screens/scan_hub_screen.dart test/features/tracking/presentation/scan_hub_screen_test.dart
git commit -m "feat(tracking): colis-first Scan & Suivi hub — switcher, colis list, history

Replaces the single-trip hero + counter with: a trip switcher (only
shown when >1 active trip), a dense per-colis list with 3-step
progress dots and a per-colis Scan shortcut, a conditional offline
sync banner scoped to the active trip, and a chronological scan
history. The 3 quick-scan step buttons are kept unchanged. The
generic Scanner QR / Numéro buttons are dropped — Task 6 adds an
inline number-entry field to replace the Numéro one."
```

---

### Task 6: Frontend — inline colis-number entry field

**Files:**
- Modify: `lib/features/tracking/presentation/screens/scan_hub_screen.dart`
- Test: `test/features/tracking/presentation/scan_hub_screen_test.dart`

**Interfaces:**
- Consumes: `TrackingBloc` (existing — `TrackingSearchRequested`, `TrackingSearchLoaded`, `TrackingSearchError`, `TrackingSearchLoading` states, `TrackingSearchModel.bidId`), `nextRequiredStep` (Task 2), `ScanHubLoaded.selectedTripBids` (Task 4) to resolve the searched bid locally once found.
- Produces: `_NumberEntryField` widget, wired into the slot left by Task 5. On success, navigates to `/tracking/scan/photo` (existing route, `extra: {bidId, etape, packageLabel}`).

- [ ] **Step 1: Write the failing tests**

Add to `test/features/tracking/presentation/scan_hub_screen_test.dart`. First, add these imports near the top (alongside the existing ones):

```dart
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
```

Add a mock class near `_MockScanHubCubit`:

```dart
class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}
```

Update `_router`/`_wrap` to also take and provide a `TrackingBloc`, and add the `/tracking/scan/photo` route:

```dart
GoRouter _router(ScanHubCubit cubit, TrackingBloc trackingBloc) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => MultiBlocProvider(
        providers: [
          BlocProvider<ScanHubCubit>.value(value: cubit),
          BlocProvider<TrackingBloc>.value(value: trackingBloc),
        ],
        child: const ScanHubView(),
      ),
    ),
    GoRoute(
      path: '/tracking/scan/identify',
      builder: (_, __) => const Scaffold(body: Text('identify')),
    ),
    GoRoute(
      path: '/tracking/scan/photo',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return Scaffold(
          body: Text('photo-${extra['bidId']}-${extra['etape']}'),
        );
      },
    ),
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (_, __) => const Scaffold(body: Text('offline-queue')),
    ),
    GoRoute(
      path: '/announcements/trips',
      builder: (_, __) => const Scaffold(body: Text('mes-trajets')),
    ),
    GoRoute(
      path: '/bids/:id',
      builder: (_, state) =>
          Scaffold(body: Text('bid-${state.pathParameters['id']}')),
    ),
  ],
);

Widget _wrap(ScanHubCubit cubit, [TrackingBloc? trackingBloc]) =>
    MaterialApp.router(
      routerConfig: _router(cubit, trackingBloc ?? _MockTrackingBloc()),
    );
```

This changes `_wrap`'s signature (now takes an optional second argument) — every existing call site in the file (`_wrap(cubit)`) keeps compiling unchanged since the second parameter is optional; no other edits needed to prior tests. Also register the fallback value once, in `setUpAll`:

```dart
  setUpAll(() async {
    await initializeDateFormatting('fr');
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    Hive.init('.dart_tool/test_hive');
    await getIt<HiveService>().init();
    registerFallbackValue(TrackingSearchRequested(''));
  });
```

Add a new test group at the end of `main()`, before the closing `}`:

```dart
  group('champ numéro inline', () {
    testWidgets('affiche le champ et le bouton valider', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('number_entry_field')), findsOneWidget);
    });

    testWidgets(
      'soumission valide déclenche TrackingSearchRequested',
      (tester) async {
        final trackingBloc = _MockTrackingBloc();
        when(() => trackingBloc.state).thenReturn(TrackingInitial());
        when(() => cubit.state).thenReturn(loadedState());

        await tester.pumpWidget(_wrap(cubit, trackingBloc));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('number_entry_field')),
          'TRK000001',
        );
        await tester.tap(find.byKey(const Key('number_entry_submit')));
        await tester.pumpAndSettle();

        verify(() => trackingBloc.add(any(
              that: isA<TrackingSearchRequested>()
                  .having((e) => e.number, 'number', 'TRK000001'),
            ))).called(1);
      },
    );

    testWidgets(
      'succès résout l\'étape via le bid connu et navigue vers la photo',
      (tester) async {
        final trackingBloc = _MockTrackingBloc();
        final states = [
          TrackingInitial(),
          TrackingSearchLoading(),
          TrackingSearchLoaded(const TrackingSearchModel(
            trackingNumber: 'TRK000001',
            bidId: 'bid-1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            currentStep: 'ACCEPTED',
            stepLabel: 'Voyage confirmé',
            paymentStatus: 'ESCROW',
          )),
        ];
        whenListen(trackingBloc, Stream.fromIterable(states),
            initialState: TrackingInitial());

        when(() => cubit.state).thenReturn(loadedState(
          bidsByTrip: {
            'trip-1': [_bid('bid-1', 'HANDED_OVER')],
          },
        ));

        await tester.pumpWidget(_wrap(cubit, trackingBloc));
        await tester.pumpAndSettle();

        expect(find.text('photo-bid-1-TRANSIT'), findsOneWidget);
      },
    );

    testWidgets('échec affiche une erreur inline', (tester) async {
      final trackingBloc = _MockTrackingBloc();
      final states = [
        TrackingInitial(),
        TrackingSearchLoading(),
        TrackingSearchError(const NetworkException('Not found')),
      ];
      whenListen(trackingBloc, Stream.fromIterable(states),
          initialState: TrackingInitial());

      when(() => cubit.state).thenReturn(loadedState());

      await tester.pumpWidget(_wrap(cubit, trackingBloc));
      await tester.pumpAndSettle();

      expect(find.textContaining('introuvable'), findsOneWidget);
    });
  });
```

`NetworkException` comes from `dony/core/error/app_exception.dart`, already imported transitively via `tracking_state.dart`. This mirrors the existing convention in `test/features/tracking/presentation/scan_identify_screen_test.dart` (`TrackingSearchError — affiche message introuvable` test) — the exact exception type/message don't matter for the assertion, only that `TrackingSearchError` is emitted, because (per Step 3 below) the widget shows a fixed friendly message rather than the exception's own text.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/tracking/presentation/scan_hub_screen_test.dart`
Expected: FAIL — `_NumberEntryField`/`Key('number_entry_field')` doesn't exist yet, screen isn't wrapped in `BlocProvider<TrackingBloc>` yet.

- [ ] **Step 3: Wrap the screen in `TrackingBloc` and add the field**

In `lib/features/tracking/presentation/screens/scan_hub_screen.dart`, add imports:

```dart
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart' show nextRequiredStep;
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
```

(The `scan_hub_selectors.dart` import already exists from Task 5 for `colisStepProgress`/`nextRequiredStep` — just confirm both names are imported, no `show` clause needed if the existing plain import already covers it; only add the second import line if it isn't already imported unqualified.)

Change `ScanHubScreen.build()` from a single `BlocProvider` to a `MultiBlocProvider`:

```dart
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ScanHubCubit>()..load()),
        BlocProvider(create: (_) => getIt<TrackingBloc>()),
      ],
      child: ScanHubView(onTrackParcel: onTrackParcel),
    );
  }
```

Add the `MultiBlocProvider` import at the top if not already present (it's part of `package:flutter_bloc/flutter_bloc.dart`, already imported).

Replace the placeholder comment left by Task 5:

```dart
                    // Task 6 inserts _NumberEntryField here.
```

with:

```dart
                    const _NumberEntryField(),
```

Add the new widget at the end of the file:

```dart
// ── Champ numéro inline ──────────────────────────────────────────────────────

class _NumberEntryField extends StatefulWidget {
  const _NumberEntryField();

  @override
  State<_NumberEntryField> createState() => _NumberEntryFieldState();
}

class _NumberEntryFieldState extends State<_NumberEntryField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final number = _controller.text.trim();
    if (number.isEmpty) return;
    context.read<TrackingBloc>().add(TrackingSearchRequested(number));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is TrackingSearchLoaded) {
          final scanHubState = context.read<ScanHubCubit>().state;
          if (scanHubState is! ScanHubLoaded) return;
          final bid = scanHubState.selectedTripBids
              .where((b) => b.id == state.result.bidId)
              .firstOrNull;
          final etape = bid != null ? nextRequiredStep(bid) : null;
          if (etape == null) return;
          context.push<void>(
            '/tracking/scan/photo',
            extra: <String, dynamic>{
              'bidId': state.result.bidId,
              'etape': etape,
              'packageLabel': state.result.trackingNumber,
            },
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is TrackingSearchLoading;
        // Message fixe plutôt que le texte brut de l'exception — même
        // convention que ScanIdentifyScreen (scan_identify_screen.dart:303).
        final error = state is TrackingSearchError
            ? 'Numéro introuvable. Vérifiez et réessayez.'
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('number_entry_field'),
                    controller: _controller,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.characters,
                    style: tt.bodyMedium?.copyWith(letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: 'DON-XXXXXX',
                      prefixIcon: const DonyEmoji.parcel(size: 20),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.md,
                        vertical: DonySpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                    onSubmitted: (_) => _submit(context),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                DonyPressable(
                  key: const Key('number_entry_submit'),
                  onTap: isLoading ? null : () => _submit(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(DonySpacing.sm),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Icon(Icons.arrow_forward_rounded, color: cs.onPrimary),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: DonySpacing.xs),
              Text(
                error,
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tracking/presentation/scan_hub_screen_test.dart`
Expected: PASS, all tests green (both this task's new tests and every test carried over from Task 5).

- [ ] **Step 5: Full-file analyze**

Run: `flutter analyze lib/features/tracking/presentation/screens/scan_hub_screen.dart`
Expected: no new errors.

- [ ] **Step 6: Run the full touched-feature suite**

Run:
```bash
flutter test test/features/tracking/
```
Expected: all tests in the `tracking` feature pass — this is the first point where every file touched by Tasks 2–6 is exercised together.

- [ ] **Step 7: Full project analyze + test**

Run: `flutter analyze` then `flutter test --coverage`
Expected: no new analyzer warnings introduced by this plan; full suite green. Coverage stays ≥ 90% per project policy (CLAUDE.md) — if it dips, add missing test cases for the new widgets/branches before proceeding.

- [ ] **Step 8: Commit**

```bash
git add lib/features/tracking/presentation/screens/scan_hub_screen.dart test/features/tracking/presentation/scan_hub_screen_test.dart
git commit -m "feat(tracking): inline colis-number entry on the Scan & Suivi hub

Replaces the old separate 'Numéro' button (which navigated away) —
typing a number here resolves the bid locally against the already-
loaded trip's colis, deduces the next required step automatically,
and jumps straight to the photo step. No ambiguous step-picker sheet
needed since the colis is already identified by its number."
```

- [ ] **Step 9: Push and open a draft PR**

```bash
git push origin worktree-scan-suivi-redesign
```

The branch already has a PR-less history from the spec commits earlier in this session — open the PR now that the implementation is complete:

```bash
gh pr create --repo MONDONY/dony_app --base main --draft \
  --title "feat(tracking): colis-first Scan & Suivi redesign" \
  --body "Implements docs/superpowers/specs/2026-07-07-scan-suivi-redesign-design.md. Depends on the dony-back companion PR (Task 1) for the grouped scan-history endpoint — merge that one first."
```

Note the dependency on the `dony-back` PR from Task 1 explicitly in the PR description, since this frontend PR's number-entry / history features will 404 against a backend that doesn't yet have the new endpoint deployed.

---

## Post-plan checklist (from the spec's "Hors scope" section — confirm still true after implementation, don't act on them)

- `selectScannableTrip` (singular) has no other callers outside the tracking feature — confirmed via repo search before writing this plan (see Global Constraints). No wrapper needed.
- `OfflineScanQueueScreen`/`OfflineSyncService` are unchanged — only read from, not modified.
- No pagination on scan history (spec: a trip rarely has more than ~30 events total).
- Fiche colis (`/bids/{id}`) unchanged — this plan only adds a navigation target to it, no changes to that screen itself.
