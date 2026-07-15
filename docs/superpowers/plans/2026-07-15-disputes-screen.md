# Écran « Mes litiges » — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le placeholder `/disputes` par une vraie feature litiges (liste + détail, lecture seule, deux rôles), avec l'endpoint backend enrichi correspondant.

**Architecture:** Backend : DTO `DisputeResponse` enrichi (contexte colis + résolution + rôle appelant) assemblé en batch dans `DisputeService`, endpoint `GET /disputes/me` ouvert à SENDER et TRAVELER. Flutter : nouvelle feature `lib/features/disputes/` (bloc/data/presentation), liste chargée par `DisputeListBloc`, détail alimenté par `extra` (pas d'endpoint détail).

**Tech Stack:** Spring Boot 3.5 / JPA / Mockito · Flutter / flutter_bloc / GoRouter / Dio / GetIt / mocktail / bloc_test.

**Spec :** `docs/superpowers/specs/2026-07-15-disputes-screen-design.md` (maquette : https://claude.ai/code/artifact/a612432c-c48b-40ac-889c-8d240da896cd)

## Global Constraints

- 2 repos git séparés : Partie A dans `dony-back` (branche `feature/disputes-me-both-roles`), Partie B dans `dony_app` (branche `feature/disputes-screen`, déjà créée avec la spec).
- Jamais de commit sur `main` ; pas de `Co-Authored-By: Claude`.
- Backend : erreurs RFC 7807, pas d'injection de *services* cross-package (repositories OK — précédent `AdminDisputesController`), tests verts avant commit.
- Flutter : BLoC only (pas de setState pour l'état métier), GoRouter only, Dio via `ApiClient`, DI GetIt (`registerLazySingleton` data / `registerFactory` bloc), analytics via `AnalyticsService` + noms dans `AnalyticsEvents`, aucune PII.
- Vérification tests : TOUJOURS `cmd > log 2>&1; echo "EXIT_CODE=$?" >> log` puis lire le log — jamais `cmd | tail`.
- Couverture ≥ 90 % sur le code nouveau.

---

# Partie A — Backend (dony-back)

### Task A1: DTO enrichi + service union deux rôles

**Files:**
- Modify: `src/main/java/com/dony/api/disputes/dto/DisputeResponse.java` (réécriture)
- Modify: `src/main/java/com/dony/api/disputes/DisputeRepository.java` (+1 méthode)
- Modify: `src/main/java/com/dony/api/disputes/DisputeService.java` (remplace `getDisputesForTraveler`)
- Test: `src/test/java/com/dony/api/disputes/DisputeServiceTest.java`

**Interfaces:**
- Consumes: `BidRepository`, `AnnouncementRepository` (package matching), `UserRepository` (auth), `MatchingTextUtil.buildName(UserEntity)`.
- Produces: `DisputeService.getDisputesForUser(UUID userId) → List<DisputeResponse>` avec le DTO ci-dessous — Task A2 et la Partie B en dépendent.

- [ ] **Step 1: Créer la branche**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony-back
git checkout main && git pull origin main --ff-only
git checkout -b feature/disputes-me-both-roles
```

- [ ] **Step 2: Vérifier les usages existants avant de casser**

```bash
grep -rn "getDisputesForTraveler\|findByTravelerIdOrderByCreatedAtDesc\|DisputeResponse" src/main src/test --include="*.java"
```
Attendu : usages limités à `DisputeService`, `DisputeController`, `DisputeServiceTest`, `DisputeControllerTest`. Si un autre fichier apparaît, l'adapter dans les steps suivants.

- [ ] **Step 3: Réécrire le DTO**

Remplacer intégralement `dto/DisputeResponse.java` :

```java
package com.dony.api.disputes.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Vue « Mes litiges » côté utilisateur. Le contexte colis (villes, date, poids,
 * autre partie) est null si le bid ou l'annonce a été soft-deleted.
 */
public record DisputeResponse(
        UUID id,
        UUID bidId,
        String type,
        String status,
        boolean refundFrozen,
        LocalDateTime createdAt,
        String myRole,             // "SENDER" | "TRAVELER"
        String otherPartyName,
        String departureCity,
        String arrivalCity,
        String departureCountryCode,
        String arrivalCountryCode,
        LocalDate tripDate,
        BigDecimal weightKg,
        String resolutionType,
        OffsetDateTime resolvedAt,
        String resolutionNote,
        Long guaranteeAmountCents,
        boolean isBeneficiary
) {}
```

(L'ancienne factory `from(DisputeEntity)` disparaît — le mapping vit dans le service.)

- [ ] **Step 4: Ajouter la méthode repository**

Dans `DisputeRepository.java`, ajouter :

```java
List<DisputeEntity> findBySenderIdOrTravelerIdOrderByCreatedAtDesc(UUID senderId, UUID travelerId);
```

Supprimer `findByTravelerIdOrderByCreatedAtDesc` (plus utilisée après cette task).

- [ ] **Step 5: Écrire les tests service (rouges)**

Remplacer les tests de listing dans `DisputeServiceTest.java` (garder les tests `openSenderNoShowDispute` existants) :

```java
// Nouveaux mocks à déclarer en tête de classe :
// @Mock BidRepository bidRepository;
// @Mock AnnouncementRepository announcementRepository;
// @Mock UserRepository userRepository;
// et les passer au constructeur du service dans le setup.

@Test
void getDisputesForUser_returnsUnion_withMyRolePerDispute() {
    UUID me = UUID.randomUUID();
    DisputeEntity asSender = dispute(me, UUID.randomUUID());      // je suis sender
    DisputeEntity asTraveler = dispute(UUID.randomUUID(), me);    // je suis traveler
    when(disputeRepository.findBySenderIdOrTravelerIdOrderByCreatedAtDesc(me, me))
            .thenReturn(List.of(asSender, asTraveler));
    when(bidRepository.findAllById(any())).thenReturn(List.of());
    when(announcementRepository.findAllById(any())).thenReturn(List.of());
    when(userRepository.findAllById(any())).thenReturn(List.of());

    List<DisputeResponse> result = disputeService.getDisputesForUser(me);

    assertThat(result).hasSize(2);
    assertThat(result.get(0).myRole()).isEqualTo("SENDER");
    assertThat(result.get(1).myRole()).isEqualTo("TRAVELER");
}

@Test
void getDisputesForUser_mapsTripContextAndOtherParty() {
    UUID me = UUID.randomUUID();
    UUID other = UUID.randomUUID();
    UUID bidId = UUID.randomUUID();
    UUID annId = UUID.randomUUID();

    DisputeEntity d = dispute(me, other);
    d.setBidId(bidId);
    when(disputeRepository.findBySenderIdOrTravelerIdOrderByCreatedAtDesc(me, me))
            .thenReturn(List.of(d));

    BidEntity bid = new BidEntity();
    ReflectionTestUtils.setField(bid, "id", bidId);
    bid.setAnnouncementId(annId);
    bid.setWeightKg(new BigDecimal("5.00"));
    when(bidRepository.findAllById(any())).thenReturn(List.of(bid));

    AnnouncementEntity ann = new AnnouncementEntity();
    ReflectionTestUtils.setField(ann, "id", annId);
    ann.setDepartureCity("Lyon");
    ann.setArrivalCity("Abidjan");
    ann.setDepartureCountryCode("FR");
    ann.setArrivalCountryCode("CI");
    ann.setDepartureDate(LocalDate.of(2026, 6, 20));
    when(announcementRepository.findAllById(any())).thenReturn(List.of(ann));

    UserEntity otherUser = new UserEntity();
    ReflectionTestUtils.setField(otherUser, "id", other);
    otherUser.setFirstName("Awa");
    otherUser.setLastName("K.");
    when(userRepository.findAllById(any())).thenReturn(List.of(otherUser));

    DisputeResponse r = disputeService.getDisputesForUser(me).get(0);

    assertThat(r.departureCity()).isEqualTo("Lyon");
    assertThat(r.arrivalCity()).isEqualTo("Abidjan");
    assertThat(r.tripDate()).isEqualTo(LocalDate.of(2026, 6, 20));
    assertThat(r.weightKg()).isEqualByComparingTo("5.00");
    assertThat(r.otherPartyName()).isEqualTo("Awa K.");
}

@Test
void getDisputesForUser_missingBidOrAnnouncement_yieldsNullContext() {
    UUID me = UUID.randomUUID();
    DisputeEntity d = dispute(me, UUID.randomUUID());
    d.setBidId(UUID.randomUUID()); // bid soft-deleted → findAllById vide
    when(disputeRepository.findBySenderIdOrTravelerIdOrderByCreatedAtDesc(me, me))
            .thenReturn(List.of(d));
    when(bidRepository.findAllById(any())).thenReturn(List.of());
    when(announcementRepository.findAllById(any())).thenReturn(List.of());
    when(userRepository.findAllById(any())).thenReturn(List.of());

    DisputeResponse r = disputeService.getDisputesForUser(me).get(0);

    assertThat(r.departureCity()).isNull();
    assertThat(r.weightKg()).isNull();
    assertThat(r.otherPartyName()).isNull();
}

@Test
void getDisputesForUser_beneficiaryFlag() {
    UUID me = UUID.randomUUID();
    DisputeEntity mine = dispute(me, UUID.randomUUID());
    mine.setBeneficiaryUserId(me);
    DisputeEntity notMine = dispute(me, UUID.randomUUID());
    notMine.setBeneficiaryUserId(UUID.randomUUID());
    when(disputeRepository.findBySenderIdOrTravelerIdOrderByCreatedAtDesc(me, me))
            .thenReturn(List.of(mine, notMine));
    when(bidRepository.findAllById(any())).thenReturn(List.of());
    when(announcementRepository.findAllById(any())).thenReturn(List.of());
    when(userRepository.findAllById(any())).thenReturn(List.of());

    List<DisputeResponse> result = disputeService.getDisputesForUser(me);
    assertThat(result.get(0).isBeneficiary()).isTrue();
    assertThat(result.get(1).isBeneficiary()).isFalse();
}

// Helper en bas de classe :
private static DisputeEntity dispute(UUID senderId, UUID travelerId) {
    DisputeEntity d = new DisputeEntity();
    ReflectionTestUtils.setField(d, "id", UUID.randomUUID());
    d.setSenderId(senderId);
    d.setTravelerId(travelerId);
    d.setType("SENDER_NO_SHOW_CONTESTED");
    d.setStatus("OPEN");
    return d;
}
```

Imports à ajouter : `com.dony.api.matching.BidEntity`, `com.dony.api.matching.BidRepository`, `com.dony.api.matching.AnnouncementEntity`, `com.dony.api.matching.AnnouncementRepository`, `com.dony.api.auth.UserEntity`, `com.dony.api.auth.UserRepository`, `org.springframework.test.util.ReflectionTestUtils`, `java.math.BigDecimal`, `java.time.LocalDate`, `static org.assertj.core.api.Assertions.assertThat`, `static org.mockito.ArgumentMatchers.any`.

- [ ] **Step 6: Vérifier que les tests échouent**

```bash
./mvnw test -Dtest=DisputeServiceTest > /tmp/dony-a1-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a1-red.log
tail -20 /tmp/dony-a1-red.log
```
Attendu : compilation error (`getDisputesForUser` n'existe pas) → EXIT_CODE≠0.

- [ ] **Step 7: Implémenter le service**

Dans `DisputeService.java` : supprimer `getDisputesForTraveler`, ajouter les dépendances et la nouvelle méthode :

```java
// Nouveaux imports :
import com.dony.api.auth.UserEntity;
import com.dony.api.auth.UserRepository;
import com.dony.api.common.MatchingTextUtil;
import com.dony.api.matching.AnnouncementEntity;
import com.dony.api.matching.AnnouncementRepository;
import com.dony.api.matching.BidEntity;
import com.dony.api.matching.BidRepository;
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

// Constructeur étendu :
private final BidRepository bidRepository;
private final AnnouncementRepository announcementRepository;
private final UserRepository userRepository;

public DisputeService(DisputeRepository disputeRepository, AuditService auditService,
                      BidRepository bidRepository, AnnouncementRepository announcementRepository,
                      UserRepository userRepository) {
    this.disputeRepository = disputeRepository;
    this.auditService = auditService;
    this.bidRepository = bidRepository;
    this.announcementRepository = announcementRepository;
    this.userRepository = userRepository;
}

/** Litiges où l'utilisateur est sender OU traveler, plus récents d'abord. */
@Transactional(readOnly = true)
public List<DisputeResponse> getDisputesForUser(UUID userId) {
    List<DisputeEntity> disputes = disputeRepository
            .findBySenderIdOrTravelerIdOrderByCreatedAtDesc(userId, userId);

    Set<UUID> bidIds = disputes.stream().map(DisputeEntity::getBidId)
            .filter(Objects::nonNull).collect(Collectors.toSet());
    Map<UUID, BidEntity> bids = bidRepository.findAllById(bidIds).stream()
            .collect(Collectors.toMap(BidEntity::getId, Function.identity(), (a, b) -> a));

    Set<UUID> annIds = bids.values().stream().map(BidEntity::getAnnouncementId)
            .filter(Objects::nonNull).collect(Collectors.toSet());
    Map<UUID, AnnouncementEntity> anns = announcementRepository.findAllById(annIds).stream()
            .collect(Collectors.toMap(AnnouncementEntity::getId, Function.identity(), (a, b) -> a));

    Set<UUID> otherIds = new HashSet<>();
    for (DisputeEntity d : disputes) {
        UUID other = userId.equals(d.getSenderId()) ? d.getTravelerId() : d.getSenderId();
        if (other != null) otherIds.add(other);
    }
    Map<UUID, UserEntity> users = userRepository.findAllById(otherIds).stream()
            .collect(Collectors.toMap(UserEntity::getId, Function.identity(), (a, b) -> a));

    return disputes.stream().map(d -> toResponse(d, userId, bids, anns, users)).toList();
}

private DisputeResponse toResponse(DisputeEntity d, UUID userId,
        Map<UUID, BidEntity> bids, Map<UUID, AnnouncementEntity> anns,
        Map<UUID, UserEntity> users) {
    boolean isSender = userId.equals(d.getSenderId());
    UUID otherId = isSender ? d.getTravelerId() : d.getSenderId();
    UserEntity other = otherId != null ? users.get(otherId) : null;
    BidEntity bid = d.getBidId() != null ? bids.get(d.getBidId()) : null;
    AnnouncementEntity ann = (bid != null && bid.getAnnouncementId() != null)
            ? anns.get(bid.getAnnouncementId()) : null;

    return new DisputeResponse(
            d.getId(), d.getBidId(), d.getType(), d.getStatus(), d.isRefundFrozen(),
            d.getCreatedAt(),
            isSender ? "SENDER" : "TRAVELER",
            other != null ? MatchingTextUtil.buildName(other) : null,
            ann != null ? ann.getDepartureCity() : null,
            ann != null ? ann.getArrivalCity() : null,
            ann != null ? ann.getDepartureCountryCode() : null,
            ann != null ? ann.getArrivalCountryCode() : null,
            ann != null ? ann.getDepartureDate() : null,
            bid != null ? bid.getWeightKg() : null,
            d.getResolutionType(), d.getResolvedAt(), d.getResolutionNote(),
            d.getGuaranteeAmountCents(),
            userId.equals(d.getBeneficiaryUserId()));
}
```

Note : si `MatchingTextUtil` n'est pas dans `common/` (vérifier l'import réel — `grep -rn "class MatchingTextUtil" src/main`), adapter le package d'import.

- [ ] **Step 8: Vérifier que les tests passent**

```bash
./mvnw test -Dtest=DisputeServiceTest > /tmp/dony-a1-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a1-green.log
tail -10 /tmp/dony-a1-green.log
```
Attendu : `BUILD SUCCESS`, EXIT_CODE=0. (`DisputeControllerTest` sera encore rouge — corrigé en A2 ; ne pas lancer la suite complète ici.)

- [ ] **Step 9: Commit**

```bash
git add src/main/java/com/dony/api/disputes/ src/test/java/com/dony/api/disputes/DisputeServiceTest.java
git commit -m "feat(disputes): DTO enrichi et listing union sender/traveler"
```

### Task A2: Endpoint ouvert aux deux rôles + suite complète + PR

**Files:**
- Modify: `src/main/java/com/dony/api/disputes/DisputeController.java:32-37`
- Test: `src/test/java/com/dony/api/disputes/DisputeControllerTest.java`

**Interfaces:**
- Consumes: `DisputeService.getDisputesForUser(UUID)` (Task A1).
- Produces: `GET /disputes/me` (context-path `/api/v1`) accessible `SENDER` et `TRAVELER` → JSON `List<DisputeResponse>` avec les clés `myRole`, `otherPartyName`, `departureCity`, `arrivalCity`, `departureCountryCode`, `arrivalCountryCode`, `tripDate`, `weightKg`, `resolutionType`, `resolvedAt`, `resolutionNote`, `guaranteeAmountCents`, `isBeneficiary` — consommé par la Partie B.

- [ ] **Step 1: Adapter les tests controller (rouges)**

Dans `DisputeControllerTest.java` : remplacer `getMyDisputes_forbiddenForSender` et adapter le stub :

```java
private static DisputeResponse sample() {
    return new DisputeResponse(UUID.randomUUID(), UUID.randomUUID(),
            "SENDER_NO_SHOW_CONTESTED", "OPEN", true, LocalDateTime.now(),
            "SENDER", "Awa K.", "Lyon", "Abidjan", "FR", "CI",
            java.time.LocalDate.of(2026, 6, 20), new java.math.BigDecimal("5.00"),
            null, null, null, null, false);
}

@Test
void getMyDisputes_okForTraveler() throws Exception {
    UserEntity user = new UserEntity();
    ReflectionTestUtils.setField(user, "id", TRAVELER_ID);
    when(userRepository.findByFirebaseUid(TRAVELER_UID)).thenReturn(Optional.of(user));
    when(disputeService.getDisputesForUser(TRAVELER_ID)).thenReturn(List.of(sample()));

    mockMvc.perform(get("/disputes/me").with(authentication(asRole(TRAVELER_UID, "TRAVELER"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].status").value("OPEN"))
            .andExpect(jsonPath("$[0].myRole").value("SENDER"))
            .andExpect(jsonPath("$[0].departureCity").value("Lyon"))
            .andExpect(jsonPath("$[0].isBeneficiary").value(false));
}

@Test
void getMyDisputes_okForSender() throws Exception {
    UserEntity user = new UserEntity();
    ReflectionTestUtils.setField(user, "id", TRAVELER_ID);
    when(userRepository.findByFirebaseUid("uid-sender")).thenReturn(Optional.of(user));
    when(disputeService.getDisputesForUser(TRAVELER_ID)).thenReturn(List.of());

    mockMvc.perform(get("/disputes/me").with(authentication(asRole("uid-sender", "SENDER"))))
            .andExpect(status().isOk());
}
```

(Supprimer l'ancien `getMyDisputes_returnsTravelerDisputes` et `getMyDisputes_forbiddenForSender`.)

- [ ] **Step 2: Vérifier l'échec**

```bash
./mvnw test -Dtest=DisputeControllerTest > /tmp/dony-a2-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-red.log
tail -15 /tmp/dony-a2-red.log
```
Attendu : échec (403 pour le sender, méthode service inexistante dans le stub).

- [ ] **Step 3: Implémenter le controller**

Dans `DisputeController.java`, remplacer la méthode :

```java
// GET /disputes/me — litiges en lecture seule où l'utilisateur courant est partie
@GetMapping("/me")
@PreAuthorize("hasAnyRole('SENDER','TRAVELER')")
public ResponseEntity<List<DisputeResponse>> getMyDisputes() {
    UUID userId = resolveUserId();
    return ResponseEntity.ok(disputeService.getDisputesForUser(userId));
}
```

- [ ] **Step 4: Vérifier que les tests passent puis lancer la suite complète**

```bash
./mvnw test -Dtest=DisputeControllerTest > /tmp/dony-a2-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-green.log
tail -5 /tmp/dony-a2-green.log
./mvnw test > /tmp/dony-a2-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-a2-full.log
grep -E "Tests run|BUILD|EXIT_CODE" /tmp/dony-a2-full.log | tail -5
```
Attendu : suite complète verte, EXIT_CODE=0.

- [ ] **Step 5: Commit + push + PR draft**

```bash
git add -A && git status --short   # vérifier : uniquement les fichiers disputes
git commit -m "fix(disputes): ouvre GET /disputes/me aux deux rôles (sender + traveler)"
git push -u origin feature/disputes-me-both-roles
gh pr create --draft --title "feat(disputes): endpoint /disputes/me enrichi, ouvert aux deux rôles" --body "Backend de l'écran Mes litiges (spec dony_app docs/superpowers/specs/2026-07-15-disputes-screen-design.md). DTO enrichi (contexte colis, myRole, résolution, isBeneficiary) + union sender/traveler. Corrige le bug traveler-only."
```

---

# Partie B — Flutter (dony_app)

Toutes les tasks sur la branche existante `feature/disputes-screen` (contient déjà la spec).

### Task B1: DisputeModel

**Files:**
- Create: `lib/features/disputes/data/models/dispute_model.dart`
- Test: `test/features/disputes/data/models/dispute_model_test.dart`

**Interfaces:**
- Produces: `DisputeModel.fromJson(Map<String, dynamic>)` avec les champs listés ci-dessous + helpers `isOpen`, `isResolved` — utilisés par B2–B5.

- [ ] **Step 1: Test rouge**

```dart
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson mappe tous les champs', () {
    final m = DisputeModel.fromJson({
      'id': 'd1',
      'bidId': 'b1',
      'type': 'SENDER_NO_SHOW_CONTESTED',
      'status': 'RESOLVED',
      'refundFrozen': false,
      'createdAt': '2026-06-02T10:00:00',
      'myRole': 'SENDER',
      'otherPartyName': 'Awa K.',
      'departureCity': 'Lyon',
      'arrivalCity': 'Abidjan',
      'departureCountryCode': 'FR',
      'arrivalCountryCode': 'CI',
      'tripDate': '2026-06-20',
      'weightKg': 5.0,
      'resolutionType': 'GUARANTEE_PAID',
      'resolvedAt': '2026-06-04T09:00:00Z',
      'resolutionNote': 'No-show confirmé.',
      'guaranteeAmountCents': 4000,
      'isBeneficiary': true,
    });
    expect(m.id, 'd1');
    expect(m.isResolved, isTrue);
    expect(m.isOpen, isFalse);
    expect(m.myRole, 'SENDER');
    expect(m.weightKg, 5.0);
    expect(m.guaranteeAmountCents, 4000);
    expect(m.isBeneficiary, isTrue);
    expect(m.tripDate, DateTime(2026, 6, 20));
  });

  test('fromJson tolère le contexte null (envoi supprimé)', () {
    final m = DisputeModel.fromJson({
      'id': 'd2',
      'bidId': null,
      'type': 'SENDER_NO_SHOW_CONTESTED',
      'status': 'OPEN',
      'refundFrozen': true,
      'createdAt': '2026-07-12T08:00:00',
      'myRole': 'TRAVELER',
      'otherPartyName': null,
      'departureCity': null,
      'arrivalCity': null,
      'departureCountryCode': null,
      'arrivalCountryCode': null,
      'tripDate': null,
      'weightKg': null,
      'resolutionType': null,
      'resolvedAt': null,
      'resolutionNote': null,
      'guaranteeAmountCents': null,
      'isBeneficiary': false,
    });
    expect(m.isOpen, isTrue);
    expect(m.departureCity, isNull);
    expect(m.weightKg, isNull);
    expect(m.resolvedAt, isNull);
  });
}
```

- [ ] **Step 2: Vérifier l'échec** — `flutter test test/features/disputes/data/models/dispute_model_test.dart > /tmp/b1-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/b1-red.log; tail -5 /tmp/b1-red.log` → échec de compilation.

- [ ] **Step 3: Implémenter**

```dart
/// Litige vu par l'utilisateur courant (lecture seule).
/// Miroir du DTO backend `DisputeResponse` (GET /disputes/me).
class DisputeModel {
  final String id;
  final String? bidId;
  final String type;
  final String status; // OPEN | RESOLVED
  final bool refundFrozen;
  final DateTime createdAt;
  final String myRole; // SENDER | TRAVELER
  final String? otherPartyName;
  final String? departureCity;
  final String? arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime? tripDate;
  final double? weightKg;
  final String? resolutionType;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final int? guaranteeAmountCents;
  final bool isBeneficiary;

  const DisputeModel({
    required this.id,
    required this.bidId,
    required this.type,
    required this.status,
    required this.refundFrozen,
    required this.createdAt,
    required this.myRole,
    required this.otherPartyName,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureCountryCode,
    required this.arrivalCountryCode,
    required this.tripDate,
    required this.weightKg,
    required this.resolutionType,
    required this.resolvedAt,
    required this.resolutionNote,
    required this.guaranteeAmountCents,
    required this.isBeneficiary,
  });

  bool get isOpen => status == 'OPEN';
  bool get isResolved => status == 'RESOLVED';

  factory DisputeModel.fromJson(Map<String, dynamic> json) => DisputeModel(
        id: json['id'] as String,
        bidId: json['bidId'] as String?,
        type: json['type'] as String,
        status: json['status'] as String,
        refundFrozen: json['refundFrozen'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        myRole: json['myRole'] as String,
        otherPartyName: json['otherPartyName'] as String?,
        departureCity: json['departureCity'] as String?,
        arrivalCity: json['arrivalCity'] as String?,
        departureCountryCode: json['departureCountryCode'] as String?,
        arrivalCountryCode: json['arrivalCountryCode'] as String?,
        tripDate: json['tripDate'] != null
            ? DateTime.parse(json['tripDate'] as String)
            : null,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        resolutionType: json['resolutionType'] as String?,
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
        resolutionNote: json['resolutionNote'] as String?,
        guaranteeAmountCents: (json['guaranteeAmountCents'] as num?)?.toInt(),
        isBeneficiary: json['isBeneficiary'] as bool? ?? false,
      );
}
```

- [ ] **Step 4: Vérifier vert** — même commande que Step 2 (log `/tmp/b1-green.log`), EXIT_CODE=0.
- [ ] **Step 5: Commit** — `git add lib/features/disputes test/features/disputes && git commit -m "feat(disputes): DisputeModel"`

### Task B2: Datasource + Repository + DI

**Files:**
- Create: `lib/features/disputes/data/datasources/dispute_remote_datasource.dart`
- Create: `lib/features/disputes/data/repositories/dispute_repository.dart`
- Modify: `lib/core/di/injection.dart` (bloc `// Disputes` après le bloc `// Favorites`, ~ligne 792)
- Test: `test/features/disputes/data/dispute_remote_datasource_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (`lib/core/network/api_client.dart`, expose `.dio`), `DisputeModel` (B1).
- Produces: `DisputeRepository.getMyDisputes() → Future<List<DisputeModel>>` — utilisé par B3.

- [ ] **Step 1: Test rouge**

```dart
import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/disputes/data/datasources/dispute_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}
class _MockDio extends Mock implements Dio {}

void main() {
  test('getMyDisputes GET /disputes/me et parse la liste', () async {
    final api = _MockApiClient();
    final dio = _MockDio();
    when(() => api.dio).thenReturn(dio);
    when(() => dio.get<dynamic>('/disputes/me')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/disputes/me'),
          data: [
            {
              'id': 'd1',
              'bidId': null,
              'type': 'SENDER_NO_SHOW_CONTESTED',
              'status': 'OPEN',
              'refundFrozen': true,
              'createdAt': '2026-07-12T08:00:00',
              'myRole': 'SENDER',
              'otherPartyName': null,
              'departureCity': null,
              'arrivalCity': null,
              'departureCountryCode': null,
              'arrivalCountryCode': null,
              'tripDate': null,
              'weightKg': null,
              'resolutionType': null,
              'resolvedAt': null,
              'resolutionNote': null,
              'guaranteeAmountCents': null,
              'isBeneficiary': false,
            }
          ],
        ));

    final result = await DisputeRemoteDatasource(api).getMyDisputes();
    expect(result, hasLength(1));
    expect(result.first.id, 'd1');
  });
}
```

- [ ] **Step 2: Vérifier l'échec** — `flutter test test/features/disputes/data/dispute_remote_datasource_test.dart > /tmp/b2-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/b2-red.log; tail -5 /tmp/b2-red.log`

- [ ] **Step 3: Implémenter datasource + repository**

`dispute_remote_datasource.dart` :
```dart
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';

class DisputeRemoteDatasource {
  final ApiClient _apiClient;
  DisputeRemoteDatasource(this._apiClient);

  Future<List<DisputeModel>> getMyDisputes() async {
    final res = await _apiClient.dio.get<dynamic>('/disputes/me');
    return (res.data as List)
        .map((e) => DisputeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

`dispute_repository.dart` :
```dart
import 'package:dony/features/disputes/data/datasources/dispute_remote_datasource.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';

class DisputeRepository {
  final DisputeRemoteDatasource _remote;
  DisputeRepository(this._remote);

  Future<List<DisputeModel>> getMyDisputes() => _remote.getMyDisputes();
}
```

DI dans `injection.dart` (après le bloc Favorites, avec les imports en tête de fichier) :
```dart
// Disputes
getIt.registerLazySingleton<DisputeRemoteDatasource>(
  () => DisputeRemoteDatasource(getIt<ApiClient>()),
);
getIt.registerLazySingleton<DisputeRepository>(
  () => DisputeRepository(getIt<DisputeRemoteDatasource>()),
);
```

- [ ] **Step 4: Vérifier vert** (log `/tmp/b2-green.log`) puis `flutter analyze lib/features/disputes lib/core/di/injection.dart`.
- [ ] **Step 5: Commit** — `git add -A lib/features/disputes lib/core/di test/features/disputes && git commit -m "feat(disputes): datasource, repository et DI"`

### Task B3: DisputeListBloc + analytics

**Files:**
- Create: `lib/features/disputes/bloc/dispute_list_event.dart`
- Create: `lib/features/disputes/bloc/dispute_list_state.dart`
- Create: `lib/features/disputes/bloc/dispute_list_bloc.dart`
- Modify: `lib/core/services/analytics_events.dart` (fin de classe)
- Modify: `lib/core/di/injection.dart` (bloc Disputes)
- Test: `test/features/disputes/bloc/dispute_list_bloc_test.dart`

**Interfaces:**
- Consumes: `DisputeRepository.getMyDisputes()` (B2), `AnalyticsService.logEvent`, `unwrapDioError` (`lib/core/error/app_exception.dart`).
- Produces: `DisputeListBloc` — event `DisputesLoadRequested`, states `DisputeListInitial | DisputeListLoading | DisputeListLoaded(disputes) | DisputeListError(error)` ; events analytics `AnalyticsEvents.disputesOpened = 'disputes_opened'`, `AnalyticsEvents.disputeDetailOpened = 'dispute_detail_opened'` — utilisés par B4/B5.

- [ ] **Step 1: Ajouter les constantes analytics**

Dans `analytics_events.dart`, avant la fermeture de classe :
```dart
  // Litiges
  static const disputesOpened      = 'disputes_opened';
  static const disputeDetailOpened = 'dispute_detail_opened';
```

- [ ] **Step 2: Test rouge (blocTest)**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/data/repositories/dispute_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements DisputeRepository {}
class _MockAnalytics extends Mock implements AnalyticsService {}

DisputeModel _dispute({String status = 'OPEN'}) => DisputeModel(
      id: 'd1', bidId: null, type: 'SENDER_NO_SHOW_CONTESTED', status: status,
      refundFrozen: status == 'OPEN', createdAt: DateTime(2026, 7, 12),
      myRole: 'SENDER', otherPartyName: 'Awa K.',
      departureCity: 'Lyon', arrivalCity: 'Abidjan',
      departureCountryCode: 'FR', arrivalCountryCode: 'CI',
      tripDate: DateTime(2026, 6, 20), weightKg: 5,
      resolutionType: null, resolvedAt: null, resolutionNote: null,
      guaranteeAmountCents: null, isBeneficiary: false,
    );

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  blocTest<DisputeListBloc, DisputeListState>(
    'load → loading puis loaded, analytics disputes_opened tiré une fois',
    build: () {
      when(() => repo.getMyDisputes()).thenAnswer((_) async => [_dispute()]);
      return DisputeListBloc(repo, analytics);
    },
    act: (b) => b
      ..add(const DisputesLoadRequested())
      ..add(const DisputesLoadRequested()),
    expect: () => [
      const DisputeListLoading(),
      isA<DisputeListLoaded>(),
      const DisputeListLoading(),
      isA<DisputeListLoaded>(),
    ],
    verify: (_) {
      verify(() => analytics.logEvent(AnalyticsEvents.disputesOpened,
          properties: {'count': 1})).called(1);
    },
  );

  blocTest<DisputeListBloc, DisputeListState>(
    'erreur réseau → DisputeListError',
    build: () {
      when(() => repo.getMyDisputes()).thenThrow(
          DioException(requestOptions: RequestOptions(path: '/disputes/me')));
      return DisputeListBloc(repo, analytics);
    },
    act: (b) => b.add(const DisputesLoadRequested()),
    expect: () => [const DisputeListLoading(), isA<DisputeListError>()],
  );
}
```

- [ ] **Step 3: Vérifier l'échec** (log `/tmp/b3-red.log`).

- [ ] **Step 4: Implémenter**

`dispute_list_event.dart` :
```dart
sealed class DisputeListEvent {
  const DisputeListEvent();
}

class DisputesLoadRequested extends DisputeListEvent {
  const DisputesLoadRequested();
}
```

`dispute_list_state.dart` :
```dart
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';

sealed class DisputeListState {
  const DisputeListState();
}

class DisputeListInitial extends DisputeListState {
  const DisputeListInitial();
}

class DisputeListLoading extends DisputeListState {
  const DisputeListLoading();
}

class DisputeListLoaded extends DisputeListState {
  final List<DisputeModel> disputes;
  const DisputeListLoaded(this.disputes);
}

class DisputeListError extends DisputeListState {
  final AppException error;
  const DisputeListError(this.error);
}
```

`dispute_list_bloc.dart` :
```dart
import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/repositories/dispute_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DisputeListBloc extends Bloc<DisputeListEvent, DisputeListState> {
  final DisputeRepository _repository;
  final AnalyticsService _analytics;
  bool _openedLogged = false;

  DisputeListBloc(this._repository, this._analytics)
      : super(const DisputeListInitial()) {
    on<DisputesLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    DisputesLoadRequested event,
    Emitter<DisputeListState> emit,
  ) async {
    emit(const DisputeListLoading());
    try {
      final disputes = await _repository.getMyDisputes();
      if (!_openedLogged) {
        _openedLogged = true;
        unawaited(_analytics.logEvent(
          AnalyticsEvents.disputesOpened,
          properties: {'count': disputes.length},
        ));
      }
      emit(DisputeListLoaded(disputes));
    } catch (e) {
      emit(DisputeListError(unwrapDioError(e)));
    }
  }
}
```

DI (dans le bloc `// Disputes` de `injection.dart`) :
```dart
getIt.registerFactory<DisputeListBloc>(
  () => DisputeListBloc(getIt<DisputeRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Step 5: Vérifier vert** (log `/tmp/b3-green.log`) + `flutter analyze lib/features/disputes`.
- [ ] **Step 6: Commit** — `git add -A lib test/features/disputes && git commit -m "feat(disputes): DisputeListBloc + events analytics"`

### Task B4: Écran liste + widgets + route

**Files:**
- Create: `lib/features/disputes/presentation/utils/dispute_labels.dart`
- Create: `lib/features/disputes/presentation/widgets/dispute_status_chip.dart`
- Create: `lib/features/disputes/presentation/widgets/dispute_card.dart`
- Create: `lib/features/disputes/presentation/dispute_list_screen.dart`
- Modify: `lib/app/router.dart:638-641` (remplacer le placeholder `/disputes`)
- Test: `test/features/disputes/presentation/dispute_list_screen_test.dart`

**Interfaces:**
- Consumes: `DisputeListBloc` (B3), `DisputeModel` (B1), `DonyEmptyState`, `cityFlag(String)` (`lib/features/matching/presentation/utils/city_flags.dart`).
- Produces: route `/disputes` fonctionnelle ; `disputeTypeLabel(String)`, `DisputeStatusChip(status)`, `DisputeCard(dispute, onTap)` — réutilisés par B5 (head-card du détail réutilise chip + labels). Navigation détail : `context.push('/disputes/detail', extra: dispute)`.

- [ ] **Step 1: Utils labels**

`dispute_labels.dart` :
```dart
/// Traductions d'affichage des valeurs backend (spec, section Traductions).
String disputeTypeLabel(String type) => switch (type) {
      'SENDER_NO_SHOW_CONTESTED' => 'Contestation no-show',
      _ => type,
    };

String disputeStatusLabel(String status) => switch (status) {
      'OPEN' => 'En instruction',
      'RESOLVED' => 'Résolu',
      _ => status,
    };
```

- [ ] **Step 2: Widget tests rouges (liste)**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/dispute_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<DisputeListEvent, DisputeListState>
    implements DisputeListBloc {}

DisputeModel _dispute({
  String status = 'OPEN',
  bool refundFrozen = true,
  bool isBeneficiary = false,
}) =>
    DisputeModel(
      id: 'd-$status', bidId: 'b1', type: 'SENDER_NO_SHOW_CONTESTED',
      status: status, refundFrozen: refundFrozen,
      createdAt: DateTime(2026, 7, 12), myRole: 'SENDER',
      otherPartyName: 'Awa K.', departureCity: 'Lyon', arrivalCity: 'Abidjan',
      departureCountryCode: 'FR', arrivalCountryCode: 'CI',
      tripDate: DateTime(2026, 6, 20), weightKg: 5,
      resolutionType: status == 'RESOLVED' ? 'GUARANTEE_PAID' : null,
      resolvedAt: status == 'RESOLVED' ? DateTime(2026, 6, 4) : null,
      resolutionNote: status == 'RESOLVED' ? 'No-show confirmé.' : null,
      guaranteeAmountCents: status == 'RESOLVED' ? 4000 : null,
      isBeneficiary: isBeneficiary,
    );

late _MockBloc bloc;

Widget _harness({DisputeListState? state}) {
  bloc = _MockBloc();
  whenListen(bloc, const Stream<DisputeListState>.empty(),
      initialState: state ?? const DisputeListLoading());
  final router = GoRouter(initialLocation: '/disputes', routes: [
    GoRoute(
      path: '/disputes',
      builder: (_, __) => BlocProvider<DisputeListBloc>.value(
        value: bloc,
        child: const DisputeListScreen(),
      ),
    ),
    GoRoute(
        path: '/disputes/detail',
        builder: (_, __) => const Scaffold(body: Text('DetailStub'))),
    GoRoute(
        path: '/profile/help/contact',
        builder: (_, __) => const Scaffold(body: Text('SupportStub'))),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('liste : card avec type, statut, corridor, autre partie',
      (tester) async {
    await tester.pumpWidget(_harness(
        state: DisputeListLoaded([_dispute(), _dispute(status: 'RESOLVED')])));
    await tester.pump();

    expect(find.text('Contestation no-show'), findsNWidgets(2));
    expect(find.text('En instruction'), findsOneWidget);
    expect(find.text('Résolu'), findsOneWidget);
    expect(find.textContaining('Lyon'), findsNWidgets(2));
    expect(find.textContaining('Voyageur : Awa K.'), findsNWidgets(2));
  });

  testWidgets('bandeau gel visible seulement si refundFrozen && OPEN',
      (tester) async {
    await tester.pumpWidget(_harness(
        state: DisputeListLoaded(
            [_dispute(), _dispute(status: 'RESOLVED', refundFrozen: false)])));
    await tester.pump();
    expect(find.textContaining('Remboursement gelé'), findsOneWidget);
  });

  testWidgets('tap card → push détail', (tester) async {
    await tester.pumpWidget(_harness(state: DisputeListLoaded([_dispute()])));
    await tester.pump();
    await tester.tap(find.text('Contestation no-show'));
    await tester.pumpAndSettle();
    expect(find.text('DetailStub'), findsOneWidget);
  });

  testWidgets('état vide pédagogique + CTA support', (tester) async {
    await tester.pumpWidget(_harness(state: const DisputeListLoaded([])));
    await tester.pump();
    expect(find.text('Aucun litige'), findsOneWidget);
    await tester.tap(find.text('Un problème avec un envoi ?'));
    await tester.pumpAndSettle();
    expect(find.text('SupportStub'), findsOneWidget);
  });

  testWidgets('erreur → Réessayer redispatch', (tester) async {
    await tester.pumpWidget(_harness(
        state: DisputeListError(
            NetworkException('Erreur', code: 'network-error'))));
    await tester.pump();
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(const DisputesLoadRequested())).called(1);
  });
}
```
(Import `NetworkException` depuis `package:dony/core/error/app_exception.dart` — vérifier le constructeur exact avant usage : `grep -n "class NetworkException" lib/core/error/app_exception.dart`.)

- [ ] **Step 3: Vérifier l'échec** (log `/tmp/b4-red.log`).

- [ ] **Step 4: Implémenter les widgets**

`dispute_status_chip.dart` :
```dart
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:flutter/material.dart';

class DisputeStatusChip extends StatelessWidget {
  const DisputeStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = status == 'RESOLVED';
    final fg = resolved ? cs.tertiary : const Color(0xFFB07725);
    final bg = resolved
        ? cs.tertiaryContainer.withValues(alpha: 0.5)
        : const Color(0xFFFCF3DF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(disputeStatusLabel(status),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}
```
Note exécution : avant d'écrire ce widget, vérifier les couleurs sémantiques réelles du thème (`grep -n "success\|warning" lib/core/design/theme/app_theme.dart | head`) et utiliser les tokens du design system s'ils existent (ex. `DonyColors.success500`, `DonyColors.warning*`) plutôt que les hex en dur ci-dessus.

`dispute_card.dart` :
```dart
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_status_chip.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisputeCard extends StatelessWidget {
  const DisputeCard({super.key, required this.dispute, required this.onTap});
  final DisputeModel dispute;
  final VoidCallback onTap;

  String get _otherPartyLine {
    final name = dispute.otherPartyName;
    if (name == null) return 'Envoi supprimé';
    final prefix = dispute.myRole == 'SENDER' ? 'Voyageur' : 'Expéditeur';
    return '$prefix : $name';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final df = DateFormat('d MMM yyyy', 'fr');
    final dep = dispute.departureCity;
    final arr = dispute.arrivalCity;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(disputeTypeLabel(dispute.type),
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  DisputeStatusChip(status: dispute.status),
                ],
              ),
              if (dep != null && arr != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${cityFlag(dep) ?? ''} $dep → $arr ${cityFlag(arr) ?? ''}'
                      .trim(),
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                [
                  _otherPartyLine,
                  if (dispute.weightKg != null)
                    'Envoi ${dispute.weightKg!.toStringAsFixed(dispute.weightKg! % 1 == 0 ? 0 : 1)} kg',
                ].join(' · '),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                dispute.isResolved && dispute.resolvedAt != null
                    ? 'Ouvert le ${df.format(dispute.createdAt)} · Résolu le ${df.format(dispute.resolvedAt!)}'
                    : 'Ouvert le ${df.format(dispute.createdAt)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (dispute.refundFrozen && dispute.isOpen) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Remboursement gelé le temps de l\'instruction — réponse sous 72 h.',
                        style: tt.bodySmall?.copyWith(
                            color: cs.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implémenter l'écran liste**

`dispute_list_screen.dart` :
```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DisputeListScreen extends StatelessWidget {
  const DisputeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Mes litiges')),
      body: BlocBuilder<DisputeListBloc, DisputeListState>(
        builder: (context, state) => switch (state) {
          DisputeListInitial() ||
          DisputeListLoading() =>
            Center(child: CircularProgressIndicator(color: cs.primary)),
          DisputeListError(:final error) => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: 'Impossible de charger vos litiges',
              description: error.message,
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<DisputeListBloc>()
                  .add(const DisputesLoadRequested()),
            ),
          DisputeListLoaded(:final disputes) when disputes.isEmpty =>
            DonyEmptyState(
              iconAsset: 'scale',
              title: 'Aucun litige',
              description:
                  'Tant mieux ! Un litige s\'ouvre automatiquement si vous contestez l\'absence d\'un voyageur lors d\'une remise.',
              actionLabel: 'Un problème avec un envoi ?',
              onAction: () => context.push('/profile/help/contact'),
            ),
          DisputeListLoaded(:final disputes) => RefreshIndicator(
              color: cs.primary,
              onRefresh: () async => context
                  .read<DisputeListBloc>()
                  .add(const DisputesLoadRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: disputes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => DisputeCard(
                  dispute: disputes[i],
                  onTap: () =>
                      context.push('/disputes/detail', extra: disputes[i]),
                )
                    .animate()
                    .fadeIn(delay: (60 * i).ms)
                    .slideY(begin: 0.04, curve: Curves.easeOutCubic),
              ),
            ),
        },
      ),
    );
  }
}
```
Note exécution : vérifier l'API exacte de `DonyEmptyState` (`type`, `iconAsset`, `actionLabel`, `onAction` — lire `lib/core/design/widgets/dony_empty_state.dart`) et l'existence de l'asset d'icône `scale` (déjà utilisé par la tuile profil « Mes litiges »). Adapter si nécessaire.

- [ ] **Step 6: Remplacer la route placeholder**

Dans `router.dart` (lignes ~638-641), remplacer :
```dart
    GoRoute(
      path: '/disputes',
      builder: (context, state) => const _PlaceholderScreen(title: 'Litiges'),
    ),
```
par :
```dart
    GoRoute(
      path: '/disputes',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            getIt<DisputeListBloc>()..add(const DisputesLoadRequested()),
        child: const DisputeListScreen(),
      ),
    ),
    GoRoute(
      path: '/disputes/detail',
      builder: (context, state) =>
          DisputeDetailScreen(dispute: state.extra! as DisputeModel),
    ),
```
avec les imports en tête de `router.dart`. **Attention :** `DisputeDetailScreen` n'existe qu'en B5 — pour garder B4 compilable, créer dès maintenant un fichier `dispute_detail_screen.dart` minimal (Scaffold + AppBar « Litige » + SizedBox) qui sera complété en B5.

- [ ] **Step 7: Vérifier vert** (log `/tmp/b4-green.log`) + `flutter analyze lib/features/disputes lib/app/router.dart`.
- [ ] **Step 8: Commit** — `git commit -am "feat(disputes): écran liste des litiges + route"`

### Task B5: Écran détail (timeline + décision)

**Files:**
- Create: `lib/features/disputes/presentation/widgets/dispute_timeline.dart`
- Modify: `lib/features/disputes/presentation/dispute_detail_screen.dart` (remplace le stub B4)
- Test: `test/features/disputes/presentation/dispute_detail_screen_test.dart`

**Interfaces:**
- Consumes: `DisputeModel` (via `extra`), `DisputeStatusChip`, `disputeTypeLabel`, `cityFlag`, `AnalyticsEvents.disputeDetailOpened`, `getIt<AnalyticsService>()`.
- Produces: écran final `/disputes/detail`.

- [ ] **Step 1: Widget tests rouges**

```dart
// Même _dispute() helper que B4 (le recopier dans ce fichier).
// Harness : MaterialApp + GoRouter avec /detail (écran testé, extra injecté
// via builder direct) + /profile/help/contact stub.
// getIt : enregistrer un MockAnalyticsService avant les tests
// (getIt.registerLazySingleton<AnalyticsService>(() => mockAnalytics))
// et getIt.reset() en tearDown.

testWidgets('détail résolu : décision, note admin, indemnisation si bénéficiaire',
    (tester) async {
  await tester.pumpWidget(_harness(
      _dispute(status: 'RESOLVED', isBeneficiary: true)));
  await tester.pump();
  expect(find.text('Résolu en votre faveur'), findsOneWidget);
  expect(find.text('No-show confirmé.'), findsOneWidget);
  expect(find.textContaining('40,00 €'), findsOneWidget);
  expect(find.text('Décision rendue'), findsOneWidget);
});

testWidgets('détail résolu non bénéficiaire : pas de montant, verdict neutre',
    (tester) async {
  await tester.pumpWidget(_harness(
      _dispute(status: 'RESOLVED', isBeneficiary: false)));
  await tester.pump();
  expect(find.text('Litige résolu'), findsOneWidget);
  expect(find.textContaining('€'), findsNothing);
});

testWidgets('détail en cours : étape décision grisée « sous 72 h », bandeau gel',
    (tester) async {
  await tester.pumpWidget(_harness(_dispute()));
  await tester.pump();
  expect(find.textContaining('sous 72 h'), findsWidgets);
  expect(find.textContaining('Remboursement gelé'), findsOneWidget);
  expect(find.text('Décision rendue'), findsNothing);
});

testWidgets('CTA Contacter le support → route contact', (tester) async {
  await tester.pumpWidget(_harness(_dispute()));
  await tester.pump();
  await tester.ensureVisible(find.text('Contacter le support'));
  await tester.tap(find.text('Contacter le support'));
  await tester.pumpAndSettle();
  expect(find.text('SupportStub'), findsOneWidget);
});
```

- [ ] **Step 2: Vérifier l'échec** (log `/tmp/b5-red.log`).

- [ ] **Step 3: Implémenter la timeline**

`dispute_timeline.dart` :
```dart
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisputeTimeline extends StatelessWidget {
  const DisputeTimeline({super.key, required this.dispute});
  final DisputeModel dispute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final df = DateFormat('d MMM yyyy', 'fr');
    final resolved = dispute.isResolved;

    Widget step({
      required Color dotColor,
      bool hollow = false,
      bool last = false,
      required String title,
      required String subtitle,
      Color? titleColor,
    }) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: hollow ? Colors.transparent : dotColor,
                  border: hollow ? Border.all(color: cs.outlineVariant, width: 2) : null,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: cs.outlineVariant),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700, color: titleColor)),
                    Text(subtitle,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        step(
          dotColor: cs.primary,
          title: 'Litige ouvert',
          subtitle:
              '${df.format(dispute.createdAt)} · vous avez contesté le no-show',
        ),
        step(
          dotColor: resolved ? cs.primary : const Color(0xFFE8A23B),
          title: 'En instruction',
          subtitle: resolved
              ? 'examiné par l\'équipe dony'
              : 'en cours d\'examen par l\'équipe dony',
        ),
        step(
          dotColor: const Color(0xFF0E8A5F),
          hollow: !resolved,
          last: true,
          title: resolved ? 'Décision rendue' : 'Décision',
          titleColor: resolved ? null : cs.onSurfaceVariant,
          subtitle: resolved && dispute.resolvedAt != null
              ? df.format(dispute.resolvedAt!)
              : 'sous 72 h',
        ),
      ]),
    );
  }
}
```
(Même note tokens que B4 : remplacer les hex par les constantes du design system si elles existent.)

- [ ] **Step 4: Implémenter l'écran détail**

`dispute_detail_screen.dart` (remplace le stub) :
```dart
import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_status_chip.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_timeline.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({super.key, required this.dispute});
  final DisputeModel dispute;

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(getIt<AnalyticsService>().logEvent(
      AnalyticsEvents.disputeDetailOpened,
      properties: {'status': widget.dispute.status},
    ));
  }

  String _euro(int cents) =>
      '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dep = d.departureCity;
    final arr = d.arrivalCity;
    final showAmount = d.resolutionType == 'GUARANTEE_PAID' &&
        d.isBeneficiary &&
        d.guaranteeAmountCents != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Litige')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Head-card contexte ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(disputeTypeLabel(d.type),
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      DisputeStatusChip(status: d.status),
                    ],
                  ),
                  if (dep != null && arr != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${cityFlag(dep) ?? ''} $dep → $arr ${cityFlag(arr) ?? ''}'
                          .trim(),
                      style:
                          tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (d.otherPartyName != null)
                        '${d.myRole == 'SENDER' ? 'Voyageur' : 'Expéditeur'} : ${d.otherPartyName}'
                      else
                        'Envoi supprimé',
                      if (d.weightKg != null)
                        'Envoi ${d.weightKg!.toStringAsFixed(d.weightKg! % 1 == 0 ? 0 : 1)} kg',
                    ].join(' · '),
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // ── Bandeau gel (en cours seulement) ───────────────────
            if (d.refundFrozen && d.isOpen) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Votre remboursement est gelé le temps de l\'instruction. L\'équipe dony tranche sous 72 h ouvrées.',
                      style: tt.bodySmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],

            // ── Timeline ───────────────────────────────────────────
            const SizedBox(height: 20),
            Text('SUIVI',
                style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1)),
            const SizedBox(height: 8),
            DisputeTimeline(dispute: d),

            // ── Décision (résolu seulement) ────────────────────────
            if (d.isResolved) ...[
              const SizedBox(height: 20),
              Text('DÉCISION',
                  style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 4, color: const Color(0xFF0E8A5F)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.isBeneficiary
                                ? 'Résolu en votre faveur'
                                : 'Litige résolu',
                            style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0E8A5F)),
                          ),
                          if (d.resolutionNote != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(d.resolutionNote!,
                                  style: tt.bodySmall?.copyWith(height: 1.5)),
                            ),
                          ],
                          if (showAmount) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Indemnisation versée',
                                    style: tt.bodyMedium),
                                Text(_euro(d.guaranteeAmountCents!),
                                    style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0E8A5F))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── CTA support ────────────────────────────────────────
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/profile/help/contact'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Contacter le support'),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }
}
```

- [ ] **Step 5: Vérifier vert** (log `/tmp/b5-green.log`) + `flutter analyze lib/features/disputes`.
- [ ] **Step 6: Commit** — `git commit -am "feat(disputes): écran détail litige (timeline + décision)"`

### Task B6: Finalisation — CLAUDE.md, suites complètes, PRs

**Files:**
- Modify: `CLAUDE.md` (table des events analytics)
- Modify: `docs/superpowers/specs/2026-07-15-disputes-screen-design.md` (aucun changement attendu — vérifier cohérence)

- [ ] **Step 1: Mettre à jour la table analytics de `dony_app/CLAUDE.md`**

Ajouter dans la table « Events actuellement implémentés » :
```markdown
| `disputes_opened` | DisputeListBloc._onLoad — premier chargement de « Mes litiges » (propriété `count`) |
| `dispute_detail_opened` | DisputeDetailScreen.initState — ouverture du détail d'un litige (propriété `status`) |
```

- [ ] **Step 2: Suite complète Flutter**

```bash
flutter test > /tmp/b6-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/b6-full.log
tail -5 /tmp/b6-full.log
```
Attendu : 0 échec (baseline actuelle : 0 échec sur main). Si échecs : diff avec baseline main avant de conclure.

- [ ] **Step 3: Couverture feature**

```bash
flutter test --coverage test/features/disputes > /tmp/b6-cov.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/b6-cov.log
grep -A2 "features/disputes" coverage/lcov.info | head -20   # ou genhtml si besoin
```
Attendu : ≥ 90 % sur `lib/features/disputes/`.

- [ ] **Step 4: Commit + push + PR draft**

```bash
git add -A && git status --short   # vérifier le contenu stagé
git commit -m "docs: events analytics litiges dans CLAUDE.md"
git push -u origin feature/disputes-screen
gh pr create --draft --title "feat(disputes): écran Mes litiges (liste + détail)" --body "Remplace le placeholder /disputes. Liste + détail lecture seule, deux rôles, timeline + décision admin. Spec : docs/superpowers/specs/2026-07-15-disputes-screen-design.md. Dépend de dony-back#<PR-A2> (DTO enrichi)."
```

- [ ] **Step 5: Rappeler la dépendance de déploiement**

La PR front dépend de la PR back (nouveau shape JSON + accès sender). Merger le back d'abord ; l'app tolère l'ancien backend uniquement en erreur réseau propre (403 sender → écran erreur), pas en crash.
