# Redesign « Activités » (Mes trajets + hub Envoyer) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigner les écrans « Mes trajets » et « Envoyer » selon la spec `docs/superpowers/specs/2026-06-10-redesign-activites-envoyer-design.md`, renommer l'onglet « Annonces » → « Activités », et exposer un endpoint backend `GET /travelers/me/trips-summary`.

**Architecture:** Backend d'abord (DTO + queries + service + controller, pattern copié de `TravelerStatsController` mais sans gate Pro). Côté Flutter : nouveaux widgets partagés (`TripCard`, `ShipmentCard`, `TripsStatsStrip`, chips statut, pills header), un `TripsSummaryCubit` (fetch stats) et un `TripFilterCubit` (chips + recherche locale), puis réécriture des deux écrans. Le filtrage Envois réutilise `ShipmentFilterCubit` existant (mapping de groupes seulement).

**Tech Stack:** Spring Boot 3.4 / JPA / Caffeine — Flutter / flutter_bloc / GetIt / flutter_animate / bloc_test / mocktail.

**Branches :** backend dans `dony-back/` (créer `feature/trips-summary-endpoint`), Flutter dans `dony_app/` (branche courante `feature/redesign-activites-envoyer`).

---

## Backend — dony-back

> Tous les chemins backend sont relatifs à `/Users/aboubakardiakite/Desktop/dony/dony-back/`.
> Avant Task 1 : `cd /Users/aboubakardiakite/Desktop/dony/dony-back && git checkout -b feature/trips-summary-endpoint`

### Task 1: Queries repository (kg vendus + trajets actifs multi-statuts)

**Files:**
- Modify: `src/main/java/com/dony/api/matching/AnnouncementRepository.java` (après `countByTravelerIdAndStatus`, ~ligne 116)
- Modify: `src/main/java/com/dony/api/matching/BidRepository.java` (après `countDeliveredBidsForTraveler`, ~ligne 43)
- Test: `src/test/java/com/dony/api/matching/TripsSummaryRepositoryIT.java` (create)

- [ ] **Step 1: Écrire le test d'intégration qui échoue**

```java
package com.dony.api.matching;

import static org.assertj.core.api.Assertions.assertThat;

import com.dony.api.auth.UserEntity;
import com.dony.api.auth.UserRepository;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class TripsSummaryRepositoryIT {

    @Autowired AnnouncementRepository announcementRepository;
    @Autowired BidRepository bidRepository;
    @Autowired UserRepository userRepository;

    @Test
    void countByTravelerIdAndStatusIn_counts_active_full_and_in_progress() {
        UUID travelerId = persistTraveler().getId();
        persistAnnouncement(travelerId, AnnouncementStatus.ACTIVE);
        persistAnnouncement(travelerId, AnnouncementStatus.FULL);
        persistAnnouncement(travelerId, AnnouncementStatus.IN_PROGRESS);
        persistAnnouncement(travelerId, AnnouncementStatus.COMPLETED);

        long count = announcementRepository.countByTravelerIdAndStatusIn(
                travelerId,
                List.of(AnnouncementStatus.ACTIVE, AnnouncementStatus.FULL,
                        AnnouncementStatus.IN_PROGRESS));

        assertThat(count).isEqualTo(3);
    }

    @Test
    void sumDeliveredKgForTraveler_sums_completed_bids_weight_in_period() {
        UUID travelerId = persistTraveler().getId();
        AnnouncementEntity ann =
                persistAnnouncement(travelerId, AnnouncementStatus.COMPLETED);
        persistBid(ann.getId(), BidStatus.COMPLETED, new BigDecimal("4.50"));
        persistBid(ann.getId(), BidStatus.COMPLETED, new BigDecimal("2.50"));
        persistBid(ann.getId(), BidStatus.CANCELLED, new BigDecimal("9.00"));

        BigDecimal sum = bidRepository.sumDeliveredKgForTraveler(
                travelerId, BidStatus.COMPLETED,
                LocalDateTime.now().minusDays(1), LocalDateTime.now().plusDays(1));

        assertThat(sum).isEqualByComparingTo("7.00");
    }

    @Test
    void sumDeliveredKgForTraveler_returns_zero_when_no_bids() {
        UUID travelerId = persistTraveler().getId();

        BigDecimal sum = bidRepository.sumDeliveredKgForTraveler(
                travelerId, BidStatus.COMPLETED,
                LocalDateTime.now().minusDays(1), LocalDateTime.now().plusDays(1));

        assertThat(sum).isEqualByComparingTo("0");
    }

    // Helpers : copier les builders de persistance depuis
    // src/test/java/com/dony/api/auth/TravelerStatsListenerIT.java
    // (persistTraveler / persistAnnouncement / persistCompletedBid) en les
    // adaptant : persistAnnouncement prend le statut en paramètre,
    // persistBid prend statut + weightKg.
    private UserEntity persistTraveler() { /* copier depuis TravelerStatsListenerIT */ }
    private AnnouncementEntity persistAnnouncement(UUID travelerId, AnnouncementStatus status) { /* idem */ }
    private BidEntity persistBid(UUID announcementId, BidStatus status, BigDecimal weightKg) { /* idem */ }
}
```

Remarque : les corps des helpers sont à recopier depuis `TravelerStatsListenerIT` (même package de test, mêmes champs obligatoires d'entité) — ne pas réinventer les valeurs obligatoires.

- [ ] **Step 2: Vérifier l'échec de compilation**

Run: `./mvnw test -Dtest=TripsSummaryRepositoryIT`
Expected: ÉCHEC compilation — `countByTravelerIdAndStatusIn` et `sumDeliveredKgForTraveler` n'existent pas.

- [ ] **Step 3: Ajouter les deux méthodes**

Dans `AnnouncementRepository.java`, après `countByTravelerIdAndStatus` :

```java
    long countByTravelerIdAndStatusIn(
            UUID travelerId, java.util.Collection<AnnouncementStatus> statuses);
```

Dans `BidRepository.java`, après `countDeliveredBidsForTraveler` :

```java
    @Query("""
        SELECT COALESCE(SUM(b.weightKg), 0)
        FROM BidEntity b
        JOIN AnnouncementEntity a ON b.announcementId = a.id
        WHERE a.travelerId = :travelerId AND b.status = :status
          AND b.createdAt BETWEEN :from AND :to
    """)
    java.math.BigDecimal sumDeliveredKgForTraveler(
            @Param("travelerId") UUID travelerId,
            @Param("status") BidStatus status,
            @Param("from") java.time.LocalDateTime from,
            @Param("to") java.time.LocalDateTime to);
```

(`b.createdAt` : même base temporelle que `countDeliveredBidsForTraveler` existant — cohérence.)

- [ ] **Step 4: Vérifier que les tests passent**

Run: `./mvnw test -Dtest=TripsSummaryRepositoryIT`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/matching/AnnouncementRepository.java \
        src/main/java/com/dony/api/matching/BidRepository.java \
        src/test/java/com/dony/api/matching/TripsSummaryRepositoryIT.java
git commit -m "feat(matching): queries trips-summary (kg vendus, trajets actifs multi-statuts)"
```

### Task 2: TripsSummaryDto + TripsSummaryService

**Files:**
- Create: `src/main/java/com/dony/api/matching/dto/TripsSummaryDto.java`
- Create: `src/main/java/com/dony/api/matching/TripsSummaryService.java`
- Modify: `src/main/java/com/dony/api/config/CacheConfig.java` (ajouter cache name)
- Test: `src/test/java/com/dony/api/matching/TripsSummaryServiceTest.java` (create)

- [ ] **Step 1: Écrire le test unitaire qui échoue**

```java
package com.dony.api.matching;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.dony.api.auth.UserEntity;
import com.dony.api.matching.dto.TripsSummaryDto;
import com.dony.api.payments.PaymentRepository;
import com.dony.api.payments.PaymentStatus;
import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class TripsSummaryServiceTest {

    @Mock private AnnouncementRepository announcementRepository;
    @Mock private BidRepository bidRepository;
    @Mock private PaymentRepository paymentRepository;

    private TripsSummaryService service;
    private UserEntity traveler;

    @BeforeEach
    void setUp() {
        service = new TripsSummaryService(
                announcementRepository, bidRepository, paymentRepository);
        traveler = new UserEntity();
        traveler.setId(UUID.randomUUID());
    }

    @Test
    void computeSummary_aggregates_active_trips_kg_and_revenue() {
        when(announcementRepository.countByTravelerIdAndStatusIn(
                eq(traveler.getId()), any())).thenReturn(3L);
        when(bidRepository.sumDeliveredKgForTraveler(
                eq(traveler.getId()), eq(BidStatus.COMPLETED), any(), any()))
                .thenReturn(new BigDecimal("19.0"));
        when(paymentRepository.sumCapturedRevenueForTraveler(
                eq(traveler.getId()), eq(PaymentStatus.RELEASED), any(), any()))
                .thenReturn(new BigDecimal("152.4567"));

        TripsSummaryDto dto = service.computeSummary(traveler);

        assertThat(dto.activeTrips()).isEqualTo(3);
        assertThat(dto.kgSoldThisMonth()).isEqualByComparingTo("19.0");
        assertThat(dto.revenueThisMonth()).isEqualByComparingTo("152.46");
    }

    @Test
    void computeSummary_returns_zeros_when_repositories_return_null() {
        when(announcementRepository.countByTravelerIdAndStatusIn(
                eq(traveler.getId()), any())).thenReturn(0L);
        when(bidRepository.sumDeliveredKgForTraveler(any(), any(), any(), any()))
                .thenReturn(null);
        when(paymentRepository.sumCapturedRevenueForTraveler(any(), any(), any(), any()))
                .thenReturn(null);

        TripsSummaryDto dto = service.computeSummary(traveler);

        assertThat(dto.activeTrips()).isZero();
        assertThat(dto.kgSoldThisMonth()).isEqualByComparingTo("0");
        assertThat(dto.revenueThisMonth()).isEqualByComparingTo("0");
    }
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./mvnw test -Dtest=TripsSummaryServiceTest`
Expected: ÉCHEC compilation — `TripsSummaryService` et `TripsSummaryDto` n'existent pas.

- [ ] **Step 3: Créer DTO + service**

`src/main/java/com/dony/api/matching/dto/TripsSummaryDto.java` :

```java
package com.dony.api.matching.dto;

import java.math.BigDecimal;

public record TripsSummaryDto(
        long activeTrips,
        BigDecimal kgSoldThisMonth,
        BigDecimal revenueThisMonth
) {}
```

`src/main/java/com/dony/api/matching/TripsSummaryService.java` :

```java
package com.dony.api.matching;

import com.dony.api.auth.UserEntity;
import com.dony.api.matching.dto.TripsSummaryDto;
import com.dony.api.payments.PaymentRepository;
import com.dony.api.payments.PaymentStatus;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TripsSummaryService {

    private static final List<AnnouncementStatus> ACTIVE_STATUSES = List.of(
            AnnouncementStatus.ACTIVE,
            AnnouncementStatus.FULL,
            AnnouncementStatus.IN_PROGRESS);

    private final AnnouncementRepository announcementRepository;
    private final BidRepository bidRepository;
    private final PaymentRepository paymentRepository;

    public TripsSummaryService(
            AnnouncementRepository announcementRepository,
            BidRepository bidRepository,
            PaymentRepository paymentRepository) {
        this.announcementRepository = announcementRepository;
        this.bidRepository = bidRepository;
        this.paymentRepository = paymentRepository;
    }

    @Cacheable(cacheNames = "trips-summary", key = "#traveler.id")
    @Transactional(readOnly = true)
    public TripsSummaryDto computeSummary(UserEntity traveler) {
        UUID userId = traveler.getId();
        YearMonth current = YearMonth.now();
        LocalDateTime monthStart = current.atDay(1).atStartOfDay();
        LocalDateTime monthEnd = current.atEndOfMonth().atTime(23, 59, 59);

        long activeTrips = announcementRepository
                .countByTravelerIdAndStatusIn(userId, ACTIVE_STATUSES);

        BigDecimal kgSold = bidRepository.sumDeliveredKgForTraveler(
                userId, BidStatus.COMPLETED, monthStart, monthEnd);

        BigDecimal revenue = paymentRepository.sumCapturedRevenueForTraveler(
                userId, PaymentStatus.RELEASED, monthStart, monthEnd);

        return new TripsSummaryDto(
                activeTrips,
                kgSold != null ? kgSold : BigDecimal.ZERO,
                revenue != null
                        ? revenue.setScale(2, RoundingMode.HALF_UP)
                        : BigDecimal.ZERO);
    }
}
```

Dans `CacheConfig.java`, ajouter le cache name :

```java
CaffeineCacheManager manager = new CaffeineCacheManager(
        "announcements-search", "estimation-corridor", "trips-summary");
```

- [ ] **Step 4: Vérifier que les tests passent**

Run: `./mvnw test -Dtest=TripsSummaryServiceTest`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/matching/dto/TripsSummaryDto.java \
        src/main/java/com/dony/api/matching/TripsSummaryService.java \
        src/main/java/com/dony/api/config/CacheConfig.java \
        src/test/java/com/dony/api/matching/TripsSummaryServiceTest.java
git commit -m "feat(matching): TripsSummaryService — trajets actifs, kg vendus, revenus du mois"
```

### Task 3: TripsSummaryController (GET /travelers/me/trips-summary)

**Files:**
- Create: `src/main/java/com/dony/api/matching/TripsSummaryController.java`
- Test: `src/test/java/com/dony/api/matching/TripsSummaryControllerTest.java` (create)

- [ ] **Step 1: Écrire le test qui échoue**

Suivre le pattern de test controller du projet (chercher un test existant de `TravelerStatsController` ; si MockMvc standalone n'est pas utilisé, utiliser le même style que les autres tests controller matching) :

```java
package com.dony.api.matching;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.dony.api.auth.Role;
import com.dony.api.auth.UserEntity;
import com.dony.api.auth.UserRepository;
import com.dony.api.common.DonyBusinessException;
import com.dony.api.matching.dto.TripsSummaryDto;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

@ExtendWith(MockitoExtension.class)
class TripsSummaryControllerTest {

    @Mock private TripsSummaryService service;
    @Mock private UserRepository userRepository;

    private TripsSummaryController controller;

    @BeforeEach
    void setUp() {
        controller = new TripsSummaryController(service, userRepository);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("firebase-uid-1", null, java.util.List.of()));
    }

    @Test
    void returns_summary_for_traveler() {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setRoles(Set.of(Role.TRAVELER));
        when(userRepository.findByFirebaseUid("firebase-uid-1"))
                .thenReturn(Optional.of(user));
        when(service.computeSummary(user)).thenReturn(
                new TripsSummaryDto(3, new BigDecimal("19.0"), new BigDecimal("152.46")));

        ResponseEntity<TripsSummaryDto> response = controller.getMyTripsSummary();

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody().activeTrips()).isEqualTo(3);
    }

    @Test
    void rejects_sender_only_user_with_403() {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setRoles(Set.of(Role.SENDER));
        when(userRepository.findByFirebaseUid("firebase-uid-1"))
                .thenReturn(Optional.of(user));

        assertThatThrownBy(() -> controller.getMyTripsSummary())
                .isInstanceOf(DonyBusinessException.class)
                .hasMessageContaining("voyageur");
    }
}
```

Adapter si `UserEntity.setRoles` attend une autre collection (vérifier la signature réelle dans `UserEntity`) et si l'auth principal du projet expose le uid via `getName()` ou `getPrincipal()` — copier le style des tests controller existants.

- [ ] **Step 2: Vérifier l'échec**

Run: `./mvnw test -Dtest=TripsSummaryControllerTest`
Expected: ÉCHEC compilation — `TripsSummaryController` n'existe pas.

- [ ] **Step 3: Créer le controller**

```java
package com.dony.api.matching;

import com.dony.api.auth.Role;
import com.dony.api.auth.UserEntity;
import com.dony.api.auth.UserRepository;
import com.dony.api.common.DonyBusinessException;
import com.dony.api.matching.dto.TripsSummaryDto;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/travelers")
public class TripsSummaryController {

    private final TripsSummaryService tripsSummaryService;
    private final UserRepository userRepository;

    public TripsSummaryController(
            TripsSummaryService tripsSummaryService,
            UserRepository userRepository) {
        this.tripsSummaryService = tripsSummaryService;
        this.userRepository = userRepository;
    }

    /**
     * Résumé d'activité voyageur (bandeau stats « Mes trajets »).
     * Contrairement à /me/stats, accessible à tout voyageur (pas de gate Pro).
     */
    @GetMapping("/me/trips-summary")
    public ResponseEntity<TripsSummaryDto> getMyTripsSummary() {
        String firebaseUid = requireFirebaseUid();

        UserEntity user = userRepository.findByFirebaseUid(firebaseUid)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.NOT_FOUND, "user-not-found",
                        "User Not Found", "Utilisateur introuvable"));

        if (!user.getRoles().contains(Role.TRAVELER)) {
            throw new DonyBusinessException(
                    HttpStatus.FORBIDDEN, "traveler-required",
                    "Traveler role required",
                    "Réservé aux voyageurs.");
        }

        return ResponseEntity.ok(tripsSummaryService.computeSummary(user));
    }

    private String requireFirebaseUid() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) {
            throw new DonyBusinessException(
                    HttpStatus.UNAUTHORIZED, "unauthenticated",
                    "Unauthenticated", "Authentification requise");
        }
        return auth.getName();
    }
}
```

(Copier exactement la résolution d'uid utilisée par `TravelerStatsController` du projet si elle diffère.)

- [ ] **Step 4: Tests + suite complète + couverture**

Run: `./mvnw test -Dtest=TripsSummaryControllerTest` puis `./mvnw test jacoco:report`
Expected: tous les tests PASS ; ouvrir `target/site/jacoco/index.html`, package `matching` ≥ 90 %.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/matching/TripsSummaryController.java \
        src/test/java/com/dony/api/matching/TripsSummaryControllerTest.java
git commit -m "feat(matching): GET /travelers/me/trips-summary (tout voyageur, cache 5 min)"
```

---

## Flutter — dony_app

> Chemins relatifs à `/Users/aboubakardiakite/Desktop/dony/dony_app/`. Branche : `feature/redesign-activites-envoyer` (courante).

### Task 4: TripsSummaryModel + datasource + repository

**Files:**
- Create: `lib/features/matching/data/models/trips_summary_model.dart`
- Modify: `lib/features/matching/data/datasources/announcement_remote_datasource.dart`
- Modify: `lib/features/matching/data/repositories/announcement_repository.dart`
- Test: `test/features/matching/trips_summary_model_test.dart` (create)

- [ ] **Step 1: Test du modèle qui échoue**

```dart
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripsSummaryModel', () {
    test('fromJson parse les trois champs', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 3,
        'kgSoldThisMonth': 19.0,
        'revenueThisMonth': 152.46,
      });

      expect(model.activeTrips, 3);
      expect(model.kgSoldThisMonth, 19.0);
      expect(model.revenueThisMonth, 152.46);
    });

    test('fromJson tolère les nombres entiers et les nulls', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 0,
        'kgSoldThisMonth': 0,
        'revenueThisMonth': null,
      });

      expect(model.activeTrips, 0);
      expect(model.kgSoldThisMonth, 0);
      expect(model.revenueThisMonth, 0);
    });
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/trips_summary_model_test.dart`
Expected: FAIL — fichier `trips_summary_model.dart` inexistant.

- [ ] **Step 3: Créer modèle + méthodes datasource/repository**

`lib/features/matching/data/models/trips_summary_model.dart` :

```dart
class TripsSummaryModel {
  final int activeTrips;
  final double kgSoldThisMonth;
  final double revenueThisMonth;

  const TripsSummaryModel({
    required this.activeTrips,
    required this.kgSoldThisMonth,
    required this.revenueThisMonth,
  });

  factory TripsSummaryModel.fromJson(Map<String, dynamic> json) =>
      TripsSummaryModel(
        activeTrips: (json['activeTrips'] as num?)?.toInt() ?? 0,
        kgSoldThisMonth: (json['kgSoldThisMonth'] as num?)?.toDouble() ?? 0,
        revenueThisMonth: (json['revenueThisMonth'] as num?)?.toDouble() ?? 0,
      );
}
```

Dans `announcement_remote_datasource.dart` (après `getMyAnnouncements`) :

```dart
  Future<TripsSummaryModel> getTripsSummary() async {
    final response = await _apiClient.dio.get('/travelers/me/trips-summary');
    return TripsSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }
```

(+ import du modèle en tête de fichier.)

Dans `announcement_repository.dart` (après `getMyAnnouncements`) :

```dart
  Future<TripsSummaryModel> getTripsSummary() async {
    return _remoteDatasource.getTripsSummary();
  }
```

(+ import.)

- [ ] **Step 4: Vérifier**

Run: `flutter test test/features/matching/trips_summary_model_test.dart && flutter analyze lib/features/matching/data`
Expected: PASS, 0 issue.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data/models/trips_summary_model.dart \
        lib/features/matching/data/datasources/announcement_remote_datasource.dart \
        lib/features/matching/data/repositories/announcement_repository.dart \
        test/features/matching/trips_summary_model_test.dart
git commit -m "feat(matching): TripsSummaryModel + repository.getTripsSummary()"
```

### Task 5: TripsSummaryCubit + TripFilterCubit + analytics + DI

**Files:**
- Create: `lib/features/matching/bloc/trips_summary_cubit.dart`
- Create: `lib/features/matching/bloc/trip_filter_cubit.dart`
- Modify: `lib/core/services/analytics_events.dart` (ajouter `tripFilterApplied`)
- Modify: `lib/core/di/injection.dart` (~ligne 233, après le bloc AnnouncementBloc)
- Test: `test/features/matching/trips_summary_cubit_test.dart` (create)
- Test: `test/features/matching/trip_filter_cubit_test.dart` (create)

- [ ] **Step 1: Tests qui échouent**

`test/features/matching/trips_summary_cubit_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

void main() {
  late _MockAnnouncementRepository repository;

  setUp(() => repository = _MockAnnouncementRepository());

  const summary = TripsSummaryModel(
    activeTrips: 3,
    kgSoldThisMonth: 19,
    revenueThisMonth: 152.46,
  );

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load → loading puis loaded avec le résumé',
    build: () {
      when(() => repository.getTripsSummary())
          .thenAnswer((_) async => summary);
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(),
    expect: () => [
      const TripsSummaryState.loading(),
      const TripsSummaryState.loaded(summary),
    ],
  );

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load → hidden en cas d\'erreur (bandeau masqué, pas de message)',
    build: () {
      when(() => repository.getTripsSummary()).thenThrow(Exception('network'));
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(),
    expect: () => [
      const TripsSummaryState.loading(),
      const TripsSummaryState.hidden(),
    ],
  );
}
```

`test/features/matching/trip_filter_cubit_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalyticsService analytics;

  setUp(() {
    analytics = _MockAnalyticsService();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  blocTest<TripFilterCubit, TripFilterState>(
    'setFilter émet le filtre et log trip_filter_applied',
    build: () => TripFilterCubit(analytics),
    act: (c) => c.setFilter(TripStatusFilter.completed),
    expect: () => [
      const TripFilterState(filter: TripStatusFilter.completed),
    ],
    verify: (_) {
      verify(() => analytics.logEvent(
            'trip_filter_applied',
            properties: {'status': 'completed'},
          )).called(1);
    },
  );

  blocTest<TripFilterCubit, TripFilterState>(
    'setQuery filtre sans log analytics',
    build: () => TripFilterCubit(analytics),
    act: (c) => c.setQuery('dakar'),
    expect: () => [const TripFilterState(query: 'dakar')],
    verify: (_) => verifyNever(() =>
        analytics.logEvent(any(), properties: any(named: 'properties'))),
  );

  test('matches applique filtre statut et recherche ville', () {
    const state = TripFilterState(
        filter: TripStatusFilter.active, query: 'dak');
    expect(state.matchesStatus('ACTIVE'), isTrue);
    expect(state.matchesStatus('IN_PROGRESS'), isTrue);
    expect(state.matchesStatus('COMPLETED'), isFalse);
    expect(state.matchesQuery('Paris', 'Dakar'), isTrue);
    expect(state.matchesQuery('Paris', 'Bamako'), isFalse);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/trips_summary_cubit_test.dart test/features/matching/trip_filter_cubit_test.dart`
Expected: FAIL — fichiers inexistants.

- [ ] **Step 3: Implémenter les deux cubits + event analytics**

`lib/features/matching/bloc/trips_summary_cubit.dart` :

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/trips_summary_model.dart';
import '../data/repositories/announcement_repository.dart';

enum TripsSummaryStatus { initial, loading, loaded, hidden }

class TripsSummaryState extends Equatable {
  final TripsSummaryStatus status;
  final TripsSummaryModel? summary;

  const TripsSummaryState._(this.status, [this.summary]);

  const TripsSummaryState.initial() : this._(TripsSummaryStatus.initial);
  const TripsSummaryState.loading() : this._(TripsSummaryStatus.loading);
  const TripsSummaryState.loaded(TripsSummaryModel summary)
      : this._(TripsSummaryStatus.loaded, summary);

  /// Erreur réseau/serveur : le bandeau est simplement masqué (spec).
  const TripsSummaryState.hidden() : this._(TripsSummaryStatus.hidden);

  @override
  List<Object?> get props => [status, summary?.activeTrips,
      summary?.kgSoldThisMonth, summary?.revenueThisMonth];
}

class TripsSummaryCubit extends Cubit<TripsSummaryState> {
  TripsSummaryCubit(this._repository) : super(const TripsSummaryState.initial());

  final AnnouncementRepository _repository;

  Future<void> load() async {
    emit(const TripsSummaryState.loading());
    try {
      final summary = await _repository.getTripsSummary();
      emit(TripsSummaryState.loaded(summary));
    } catch (_) {
      emit(const TripsSummaryState.hidden());
    }
  }
}
```

`lib/features/matching/bloc/trip_filter_cubit.dart` :

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';

/// Filtre statut de la liste « Mes trajets » (chips type Airbnb).
enum TripStatusFilter { all, active, completed, cancelled }

const _activeStatuses = {'ACTIVE', 'FULL', 'IN_PROGRESS'};

class TripFilterState extends Equatable {
  final TripStatusFilter filter;
  final String query;

  const TripFilterState({this.filter = TripStatusFilter.all, this.query = ''});

  bool matchesStatus(String status) => switch (filter) {
        TripStatusFilter.all => true,
        TripStatusFilter.active => _activeStatuses.contains(status),
        TripStatusFilter.completed => status == 'COMPLETED',
        TripStatusFilter.cancelled => status == 'CANCELLED',
      };

  bool matchesQuery(String departureCity, String arrivalCity) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return departureCity.toLowerCase().contains(q) ||
        arrivalCity.toLowerCase().contains(q);
  }

  TripFilterState copyWith({TripStatusFilter? filter, String? query}) =>
      TripFilterState(filter: filter ?? this.filter, query: query ?? this.query);

  @override
  List<Object?> get props => [filter, query];
}

class TripFilterCubit extends Cubit<TripFilterState> {
  TripFilterCubit(this._analytics) : super(const TripFilterState());

  final AnalyticsService _analytics;

  void setFilter(TripStatusFilter filter) {
    emit(state.copyWith(filter: filter));
    unawaited(_analytics.logEvent(
      AnalyticsEvents.tripFilterApplied,
      properties: {'status': filter.name},
    ));
  }

  void setQuery(String query) => emit(state.copyWith(query: query));
}
```

Dans `lib/core/services/analytics_events.dart`, section Announcements :

```dart
  static const tripFilterApplied = 'trip_filter_applied';
```

Dans `lib/core/di/injection.dart`, après l'enregistrement d'`AnnouncementBloc` :

```dart
getIt.registerFactory<TripsSummaryCubit>(
  () => TripsSummaryCubit(getIt<AnnouncementRepository>()),
);
getIt.registerFactory<TripFilterCubit>(
  () => TripFilterCubit(getIt<AnalyticsService>()),
);
```

(+ imports en tête d'`injection.dart`.)

- [ ] **Step 4: Vérifier**

Run: `flutter test test/features/matching/trips_summary_cubit_test.dart test/features/matching/trip_filter_cubit_test.dart && flutter analyze lib/features/matching/bloc lib/core`
Expected: PASS, 0 issue.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/bloc/trips_summary_cubit.dart \
        lib/features/matching/bloc/trip_filter_cubit.dart \
        lib/core/services/analytics_events.dart \
        lib/core/di/injection.dart \
        test/features/matching/trips_summary_cubit_test.dart \
        test/features/matching/trip_filter_cubit_test.dart
git commit -m "feat(matching): TripsSummaryCubit + TripFilterCubit (chips statut, analytics)"
```

### Task 6: Utilitaire drapeaux ville→pays

**Files:**
- Create: `lib/features/matching/presentation/utils/city_flags.dart`
- Test: `test/features/matching/city_flags_test.dart` (create)

- [ ] **Step 1: Test qui échoue**

```dart
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('villes des corridors dony', () {
    expect(cityFlag('Paris'), '🇫🇷');
    expect(cityFlag('lyon'), '🇫🇷');
    expect(cityFlag('MARSEILLE'), '🇫🇷');
    expect(cityFlag('Dakar'), '🇸🇳');
    expect(cityFlag('Abidjan'), '🇨🇮');
    expect(cityFlag('Bamako'), '🇲🇱');
    expect(cityFlag('Douala'), '🇨🇲');
    expect(cityFlag('Yaoundé'), '🇨🇲');
  });

  test('ville inconnue → null (fallback point bleu)', () {
    expect(cityFlag('Tombouctou-les-Bains'), isNull);
    expect(cityFlag(''), isNull);
  });

  test('tolère accents et espaces', () {
    expect(cityFlag(' yaounde '), '🇨🇲');
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/city_flags_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter**

```dart
/// Drapeaux emoji par ville des corridors dony.
/// Retourne null pour une ville inconnue — l'appelant affiche un point bleu.
String? cityFlag(String city) {
  final key = _normalize(city);
  return _cityToFlag[key];
}

String _normalize(String city) {
  const accents = 'àâäéèêëîïôöùûüç';
  const plain = 'aaaeeeeiioouuuc';
  var s = city.trim().toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    s = s.replaceAll(accents[i], plain[i]);
  }
  return s;
}

const _cityToFlag = <String, String>{
  // France
  'paris': '🇫🇷', 'lyon': '🇫🇷', 'marseille': '🇫🇷', 'toulouse': '🇫🇷',
  'bordeaux': '🇫🇷', 'lille': '🇫🇷', 'nantes': '🇫🇷', 'nice': '🇫🇷',
  // Sénégal
  'dakar': '🇸🇳', 'thies': '🇸🇳', 'saint-louis': '🇸🇳',
  // Côte d'Ivoire
  'abidjan': '🇨🇮', 'bouake': '🇨🇮', 'yamoussoukro': '🇨🇮',
  // Mali
  'bamako': '🇲🇱',
  // Cameroun
  'douala': '🇨🇲', 'yaounde': '🇨🇲',
  // Diaspora élargie
  'bruxelles': '🇧🇪', 'conakry': '🇬🇳', 'lome': '🇹🇬', 'cotonou': '🇧🇯',
  'kinshasa': '🇨🇩', 'casablanca': '🇲🇦', 'tunis': '🇹🇳', 'alger': '🇩🇿',
};
```

- [ ] **Step 4: Vérifier**

Run: `flutter test test/features/matching/city_flags_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/utils/city_flags.dart \
        test/features/matching/city_flags_test.dart
git commit -m "feat(matching): mapping ville→drapeau pour la timeline de vol"
```

### Task 7: TripCard (nouvelle carte trajet)

**Files:**
- Create: `lib/features/matching/presentation/widgets/trip_card.dart`
- Test: `test/features/matching/trip_card_test.dart` (create)

- [ ] **Step 1: Test widget qui échoue**

```dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  String status = 'ACTIVE',
  double totalKg = 20,
  double availableKg = 13,
}) {
  return AnnouncementModel.fromJson({
    'id': 'a1',
    'travelerId': 't1',
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'departureDate':
        DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    'totalKg': totalKg,
    'availableKg': availableKg,
    'pricePerKg': 8.0,
    'status': status,
  });
}

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche route, drapeaux, progression et prix', (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('🇫🇷'), findsOneWidget);
    expect(find.text('🇸🇳'), findsOneWidget);
    expect(find.textContaining('7 kg vendus sur 20 kg'), findsOneWidget);
    expect(find.textContaining('13 kg'), findsWidgets);
    expect(find.textContaining('8 €'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('carte terminée : footer condensé, pas de progression',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(status: 'COMPLETED', availableKg: 0),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Terminé'), findsOneWidget);
    expect(find.textContaining('vendus sur'), findsNothing);
    expect(find.textContaining('20 kg vendus'), findsOneWidget);
  });

  testWidgets('onTap déclenché', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(),
      onTap: () => tapped = true,
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(TripCard));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/trip_card_test.dart`
Expected: FAIL — `trip_card.dart` inexistant.

- [ ] **Step 3: Implémenter TripCard**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/design_system.dart';
import '../../data/models/announcement_model.dart';
import '../utils/city_flags.dart';

/// Carte trajet redesign « Éditorial calme » : route, timeline de vol avec
/// drapeaux, progression des kg vendus, prix. Spec :
/// docs/superpowers/specs/2026-06-10-redesign-activites-envoyer-design.md
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.announcement,
    required this.onTap,
    required this.index,
  });

  final AnnouncementModel announcement;
  final VoidCallback onTap;
  final int index;

  bool get _isPast =>
      announcement.status == 'COMPLETED' || announcement.status == 'CANCELLED';

  (Color bg, Color fg, String label, bool pulse) _badge(ColorScheme cs) =>
      switch (announcement.status) {
        'ACTIVE' => (cs.successLight, cs.success, 'Actif', true),
        'IN_PROGRESS' => (cs.infoLight, cs.info, 'En cours', true),
        'FULL' => (cs.warningLight, cs.warning, 'Complet', false),
        'COMPLETED' => (DonyColors.neutral100, cs.onSurfaceVariant, 'Terminé', false),
        'CANCELLED' => (cs.errorLight, cs.error, 'Annulé', false),
        _ => (DonyColors.neutral100, cs.onSurfaceVariant, announcement.status, false),
      };

  String _dateLabel() {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(announcement.departureDate);
    final diff = d.difference(today).inDays;
    final dateStr = DateFormat('d MMM', 'fr').format(announcement.departureDate);
    if (diff == 0) return "Aujourd'hui · $dateStr";
    if (diff == 1) return 'Demain · $dateStr';
    if (diff > 1 && diff <= 6) return 'Départ dans $diff jours · $dateStr';
    return DateFormat('EEE d MMM yyyy', 'fr').format(announcement.departureDate);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (badgeBg, badgeFg, badgeLabel, badgePulse) = _badge(cs);
    final total = announcement.totalKg;
    final sold = (total - announcement.availableKg).clamp(0.0, total);
    final progress = total > 0 ? (sold / total).clamp(0.0, 1.0) : 0.0;

    final card = GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: _isPast ? 0.65 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
            boxShadow: const [
              BoxShadow(
                color: DonyColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RouteTitle(
                          departure: announcement.departureCity,
                          arrival: announcement.arrivalCity,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateLabel(),
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    background: badgeBg,
                    foreground: badgeFg,
                    label: badgeLabel,
                    pulse: badgePulse,
                  ),
                ],
              ),
              if (!_isPast) ...[
                const SizedBox(height: DonySpacing.md),
                _FlightTimeline(
                  departureCity: announcement.departureCity,
                  arrivalCity: announcement.arrivalCity,
                ),
                const SizedBox(height: DonySpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: DonyColors.neutral100,
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  '${_kg(sold)} vendus sur ${_kg(total)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.md),
                Divider(height: 1, color: DonyColors.neutral100),
                const SizedBox(height: DonySpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: _kg(announcement.availableKg),
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' disponibles',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ]),
                      ),
                    ),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text:
                              '${announcement.pricePerKg.toStringAsFixed(announcement.pricePerKg.truncateToDouble() == announcement.pricePerKg ? 0 : 2)} € ',
                          style: tt.headlineMedium,
                        ),
                        TextSpan(
                          text: '/ kg',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ]),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: DonySpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_kg(sold)} vendus',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (announcement.status == 'COMPLETED')
                      Text(
                        '${(sold * announcement.pricePerKg).toStringAsFixed(0)} € gagnés',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return card
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  String _kg(double v) =>
      '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)} kg';
}

class _RouteTitle extends StatelessWidget {
  const _RouteTitle({required this.departure, required this.arrival});

  final String departure;
  final String arrival;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.headlineMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(departure, style: style, maxLines: 1,
            overflow: TextOverflow.ellipsis)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: cs.primary),
        ),
        Flexible(child: Text(arrival, style: style, maxLines: 1,
            overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.background,
    required this.foreground,
    required this.label,
    required this.pulse,
  });

  final Color background;
  final Color foreground;
  final String label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
    );
    if (pulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 1, end: 0.3, duration: 600.ms);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _FlightTimeline extends StatelessWidget {
  const _FlightTimeline({
    required this.departureCity,
    required this.arrivalCity,
  });

  final String departureCity;
  final String arrivalCity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final depFlag = cityFlag(departureCity);
    final arrFlag = cityFlag(arrivalCity);

    Widget endpoint(String? flag) => flag != null
        ? Text(flag, style: const TextStyle(fontSize: 16, height: 1))
        : Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          );

    return Row(
      children: [
        endpoint(depFlag),
        const SizedBox(width: 6),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _DashedLinePainter(color: DonyColors.blue200),
              ),
              Icon(Icons.flight_rounded, size: 16, color: cs.primary),
            ],
          ),
        ),
        const SizedBox(width: 6),
        endpoint(arrFlag),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
```

Note : l'avion en icône Material (`Icons.flight_rounded` pivoté naturellement à 0° car le glyphe pointe vers le haut — utiliser `RotatedBox(quarterTurns: 1, child: Icon(...))` si le rendu pointe vers le haut ; vérifier visuellement à l'exécution). Si `cs.successLight`/`cs.success` n'existent pas via l'extension importée par `design_system.dart`, ajouter l'import `package:dony/core/design/tokens/color_tokens.dart` (extension `DonyStatusColors`).

- [ ] **Step 4: Vérifier**

Run: `flutter test test/features/matching/trip_card_test.dart && flutter analyze lib/features/matching/presentation/widgets/trip_card.dart`
Expected: PASS, 0 issue.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/trip_card.dart \
        test/features/matching/trip_card_test.dart
git commit -m "feat(matching): TripCard — timeline drapeaux, progression kg, badge pulsant"
```

### Task 8: Widgets header partagés (pills, stats strip, chips, recherche)

**Files:**
- Create: `lib/features/matching/presentation/widgets/activity_header_widgets.dart`
- Test: `test/features/matching/activity_header_widgets_test.dart` (create)

Un seul fichier pour les 4 petits widgets réutilisés par les deux écrans : `HeaderPill`, `TripsStatsStrip`, `StatusChipsRow`, `ActivitySearchField`.

- [ ] **Step 1: Test qui échoue**

```dart
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('HeaderPill affiche label + icône et répond au tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(HeaderPill(
      label: 'Envoyer',
      icon: Icons.inventory_2_rounded,
      style: HeaderPillStyle.warm,
      onTap: () => tapped = true,
    )));
    await tester.tap(find.text('Envoyer'));
    expect(tapped, isTrue);
  });

  testWidgets('TripsStatsStrip affiche les 3 tuiles', (tester) async {
    await tester.pumpWidget(_wrap(const TripsStatsStrip(
      summary: TripsSummaryModel(
        activeTrips: 3,
        kgSoldThisMonth: 19,
        revenueThisMonth: 152.46,
      ),
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('19 kg'), findsOneWidget);
    expect(find.text('152 €'), findsOneWidget);
    expect(find.text('Trajets actifs'), findsOneWidget);
  });

  testWidgets('StatusChipsRow : chip active mise en avant, tap change',
      (tester) async {
    TripStatusFilter? selected;
    await tester.pumpWidget(_wrap(StatusChipsRow(
      chips: [
        StatusChipData(label: 'Tous', value: TripStatusFilter.all, count: 34),
        StatusChipData(
            label: 'Actifs',
            value: TripStatusFilter.active,
            count: 3,
            dotColor: Colors.green),
      ],
      selected: TripStatusFilter.all,
      onSelected: (v) => selected = v as TripStatusFilter,
    )));

    expect(find.text('Tous · 34'), findsOneWidget);
    await tester.tap(find.text('Actifs · 3'));
    expect(selected, TripStatusFilter.active);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/matching/activity_header_widgets_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design/design_system.dart';
import '../../data/models/trips_summary_model.dart';

/// Pill d'action de header (« 📦 Envoyer », « ✈️ Mes trajets », « + Nouveau »).
enum HeaderPillStyle {
  /// Fond bleu plein — action principale (« + Nouveau »).
  primary,

  /// Fond sand/terra — bascule vers le côté expéditeur.
  warm,

  /// Fond bleu clair — bascule vers le côté voyageur.
  soft,
}

class HeaderPill extends StatelessWidget {
  const HeaderPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.style = HeaderPillStyle.primary,
  });

  final String label;
  final IconData? icon;
  final HeaderPillStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, border) = switch (style) {
      HeaderPillStyle.primary => (cs.primary, cs.onPrimary, null),
      HeaderPillStyle.warm => (
          cs.surfaceWarm,
          DonyColors.terra600,
          DonyColors.sand200,
        ),
      HeaderPillStyle.soft => (
          DonyColors.primarySoft,
          DonyColors.primaryHover,
          DonyColors.blue100,
        ),
    };
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: border != null ? BorderSide(color: border) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: fg, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau de 3 mini-stats voyageur (trajets actifs, kg vendus, revenus).
class TripsStatsStrip extends StatelessWidget {
  const TripsStatsStrip({super.key, required this.summary});

  final TripsSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '${summary.activeTrips}',
            label: 'Trajets actifs',
            valueColor: cs.primary,
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _StatTile(
            value: '${_compact(summary.kgSoldThisMonth)} kg',
            label: 'Vendus ce mois',
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _StatTile(
            value: '${_compact(summary.revenueThisMonth)} €',
            label: 'Revenus',
            valueColor: cs.secondary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOutCubic);
  }

  String _compact(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md, horizontal: DonySpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Donnée d'une chip de filtre statut (point coloré + compteur optionnels).
class StatusChipData<T> {
  const StatusChipData({
    required this.label,
    required this.value,
    this.count,
    this.dotColor,
  });

  final String label;
  final T value;
  final int? count;
  final Color? dotColor;
}

/// Rangée horizontale scrollable de chips statut (pattern Airbnb).
class StatusChipsRow<T> extends StatelessWidget {
  const StatusChipsRow({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final List<StatusChipData<T>> chips;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Widget optionnel en fin de rangée (ex. bouton filtre période).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[
            Padding(
              padding: const EdgeInsets.only(right: DonySpacing.xs + 3),
              child: _chip(context, chip, cs, tt),
            ),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, StatusChipData<T> chip, ColorScheme cs,
      TextTheme tt) {
    final active = chip.value == selected;
    final label =
        chip.count != null ? '${chip.label} · ${chip.count}' : chip.label;
    return AnimatedContainer(
      duration: 150.ms,
      decoration: BoxDecoration(
        color: active ? DonyColors.ink800 : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: active ? DonyColors.ink800 : cs.outline),
      ),
      child: InkWell(
        onTap: () => onSelected(chip.value),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chip.dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: chip.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: tt.titleSmall?.copyWith(
                  fontSize: 12,
                  color: active ? DonyColors.neutral0 : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche pill compact (filtre local).
class ActivitySearchField extends StatelessWidget {
  const ActivitySearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded,
            size: 18, color: cs.onSurfaceVariant),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          borderSide: BorderSide(color: cs.primary),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Vérifier**

Run: `flutter test test/features/matching/activity_header_widgets_test.dart && flutter analyze lib/features/matching/presentation/widgets/activity_header_widgets.dart`
Expected: PASS, 0 issue.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/activity_header_widgets.dart \
        test/features/matching/activity_header_widgets_test.dart
git commit -m "feat(matching): widgets header Activités — pills, stats strip, chips statut, recherche"
```

### Task 9: Réécriture AnnouncementListScreen (« Mes trajets »)

**Files:**
- Modify: `lib/features/matching/presentation/screens/announcement_list_screen.dart` (réécriture de la structure : header custom, stats, recherche, chips ; suppression `_TabBar`/`_TripsTab` et `_AnnouncementCard` → `TripCard`)
- Modify: l'endroit où l'écran est construit avec ses providers (vérifier `matching_management_screen.dart` / `router.dart` — ajouter `TripsSummaryCubit` + `TripFilterCubit` au `MultiBlocProvider`)
- Test: `test/features/matching/announcement_list_screen_test.dart` (create ou modifier l'existant)

- [ ] **Step 1: Repérer l'intégration existante**

Lire `announcement_list_screen.dart` en entier + l'endroit où il est instancié (`matching_management_screen.dart`). Noter : providers existants, paramètres (`onSendParcel`), pull-to-refresh, navigation détail, gestion `IN_PROGRESS`.

- [ ] **Step 2: Test widget qui échoue (nouvelle structure)**

```dart
// test/features/matching/announcement_list_screen_test.dart
// Pattern : pumper AnnouncementListScreen avec MultiBlocProvider de mocks
// (MockAnnouncementBloc via bloc_test MockBloc, TripsSummaryCubit/TripFilterCubit réels
//  avec repository mocké), état AnnouncementListLoaded avec 2 annonces
//  (une ACTIVE, une COMPLETED) + TripsSummaryState.loaded.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockRepository extends Mock implements AnnouncementRepository {}

AnnouncementModel _ann(String id, String status) => AnnouncementModel.fromJson({
      'id': id,
      'travelerId': 't1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate':
          DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'totalKg': 20.0,
      'availableKg': 13.0,
      'pricePerKg': 8.0,
      'status': status,
    });

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  late _MockAnnouncementBloc bloc;
  late _MockRepository repository;

  setUp(() {
    bloc = _MockAnnouncementBloc();
    repository = _MockRepository();
    when(() => bloc.state).thenReturn(
      AnnouncementListLoaded([_ann('a1', 'ACTIVE'), _ann('a2', 'COMPLETED')], 2),
    );
    when(() => repository.getTripsSummary()).thenAnswer(
      (_) async => const TripsSummaryModel(
          activeTrips: 1, kgSoldThisMonth: 7, revenueThisMonth: 56),
    );
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? onSendParcel}) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementBloc>.value(value: bloc),
          BlocProvider(create: (_) => TripsSummaryCubit(repository)..load()),
          BlocProvider(create: (_) => TripFilterCubit(_FakeAnalytics())),
        ],
        child: AnnouncementListScreen(onSendParcel: onSendParcel),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('affiche stats, chips et cartes TripCard', (tester) async {
    await pump(tester);

    expect(find.byType(TripsStatsStrip), findsOneWidget);
    expect(find.byType(TripCard), findsNWidgets(2));
    expect(find.text('Tous · 2'), findsOneWidget);
  });

  testWidgets('chip Terminés filtre la liste', (tester) async {
    await pump(tester);

    await tester.tap(find.textContaining('Terminés'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(TripCard), findsOneWidget);
  });

  testWidgets('pill Envoyer visible seulement si onSendParcel fourni',
      (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('send-parcel-btn')), findsNothing);

    await pump(tester, onSendParcel: () {});
    expect(find.byKey(const Key('send-parcel-btn')), findsOneWidget);
  });
}

// _FakeAnalytics : Mock AnalyticsService avec logEvent no-op (copier le
// pattern du test trip_filter_cubit_test.dart).
```

Adapter le constructeur d'`AnnouncementListScreen` aux paramètres réels relevés au Step 1 (garder `onSendParcel`, `onBidsTap`, etc.).

- [ ] **Step 3: Vérifier l'échec**

Run: `flutter test test/features/matching/announcement_list_screen_test.dart`
Expected: FAIL — la structure actuelle (onglets `_TripsTab`) ne contient ni `TripsStatsStrip` ni `TripCard`.

- [ ] **Step 4: Réécrire le corps de l'écran**

Principes de la réécriture (en gardant le `AnnouncementBloc` flow existant — `AnnouncementListRequested` au init, pull-to-refresh, navigation détail inchangée) :

```dart
// Remplacement de l'AppBar + tabs par un body unique :
Scaffold(
  body: SafeArea(
    child: RefreshIndicator(
      onRefresh: () async {
        context.read<AnnouncementBloc>().add(const AnnouncementListRequested());
        context.read<TripsSummaryCubit>().load();
      },
      child: CustomScrollView(
        slivers: [
          // 1. Header custom
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg, DonySpacing.base, DonySpacing.lg, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mes trajets',
                        style: Theme.of(context).textTheme.displaySmall),
                  ),
                  if (widget.onSendParcel != null) ...[
                    HeaderPill(
                      key: const Key('send-parcel-btn'),
                      label: 'Envoyer',
                      icon: Icons.inventory_2_rounded,
                      style: HeaderPillStyle.warm,
                      onTap: widget.onSendParcel!,
                    ),
                    const SizedBox(width: DonySpacing.xs + 3),
                  ],
                  HeaderPill(
                    label: '+ Nouveau',
                    onTap: _onCreateTrip, // conserver le callback existant
                  ),
                ],
              ),
            ),
          ),
          // 2. Stats strip (masquée si hidden/initial/loading)
          SliverToBoxAdapter(
            child: BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
              builder: (context, state) =>
                  state.status == TripsSummaryStatus.loaded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(DonySpacing.lg,
                              DonySpacing.md, DonySpacing.lg, 0),
                          child: TripsStatsStrip(summary: state.summary!),
                        )
                      : const SizedBox.shrink(),
            ),
          ),
          // 3. Recherche + chips — masquées si la liste brute est vide
          // 4. Liste filtrée par TripFilterCubit → TripCard(index: i)
        ],
      ),
    ),
  ),
)
```

Construction des chips (dans le build, à partir de la liste brute `announcements`) :

```dart
List<StatusChipData<TripStatusFilter>> _chips(
    List<AnnouncementModel> all, ColorScheme cs) {
  int count(bool Function(String) test) =>
      all.where((a) => test(a.status)).length;
  final active = count((s) =>
      s == 'ACTIVE' || s == 'FULL' || s == 'IN_PROGRESS');
  final completed = count((s) => s == 'COMPLETED');
  final cancelled = count((s) => s == 'CANCELLED');
  return [
    StatusChipData(
        label: 'Tous', value: TripStatusFilter.all, count: all.length),
    StatusChipData(
        label: 'Actifs',
        value: TripStatusFilter.active,
        count: active,
        dotColor: cs.success),
    StatusChipData(
        label: 'Terminés',
        value: TripStatusFilter.completed,
        count: completed,
        dotColor: DonyColors.neutral400),
    if (cancelled > 0)
      StatusChipData(
          label: 'Annulés',
          value: TripStatusFilter.cancelled,
          dotColor: cs.error),
  ];
}
```

Filtrage + tri de la liste :

```dart
List<AnnouncementModel> _visible(
    List<AnnouncementModel> all, TripFilterState filter) {
  const priority = {
    'IN_PROGRESS': 0, 'ACTIVE': 1, 'FULL': 2, 'COMPLETED': 3, 'CANCELLED': 4,
  };
  final list = all
      .where((a) => filter.matchesStatus(a.status))
      .where((a) => filter.matchesQuery(a.departureCity, a.arrivalCity))
      .toList()
    ..sort((a, b) {
      final p = (priority[a.status] ?? 9).compareTo(priority[b.status] ?? 9);
      if (p != 0) return p;
      return a.departureDate.compareTo(b.departureDate);
    });
  return list;
}
```

Charger le résumé au init (en plus de la liste) :

```dart
@override
void initState() {
  super.initState();
  context.read<AnnouncementBloc>().add(const AnnouncementListRequested());
  context.read<TripsSummaryCubit>().load();
}
```

Supprimer : `_TripsTab`, `_TabBar`, `_AnnouncementCard` (remplacé par `TripCard`), la section séparée `IN_PROGRESS` (désormais dans le flux trié en tête). Conserver : états loading/erreur/vide existants (`DonyEmptyState`), navigation vers le détail, toute logique `onBidsTap`.

Dans `matching_management_screen.dart` (ou là où l'écran est provisionné), ajouter les deux cubits :

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => getIt<AnnouncementBloc>()),
    BlocProvider(create: (_) => getIt<TripsSummaryCubit>()),
    BlocProvider(create: (_) => getIt<TripFilterCubit>()),
  ],
  child: AnnouncementListScreen(onSendParcel: ...),
)
```

- [ ] **Step 5: Vérifier**

Run: `flutter test test/features/matching/ && flutter analyze lib/features/matching`
Expected: tous PASS (corriger les tests existants de l'écran qui référencent les onglets supprimés), 0 issue.

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching test/features/matching
git commit -m "feat(matching): redesign Mes trajets — stats, recherche, chips statut, TripCard"
```

### Task 10: ShipmentCard (carte envoi avec stepper)

**Files:**
- Create: `lib/features/matching/presentation/widgets/shipment_card.dart`
- Test: `test/features/matching/shipment_card_test.dart` (create)

- [ ] **Step 1: Lire la carte envoi actuelle**

Lire dans `shipment_list_screen.dart` le widget de carte actuel (item de liste) pour relever : champs affichés, callbacks (tap détail, QR, tracking), et le widget exact à remplacer.

- [ ] **Step 2: Test qui échoue**

```dart
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(String status) => BidModel.fromJson({
      'id': 'b1',
      'announcementId': 'a1',
      'senderId': 's1',
      'status': status,
      'weightKg': 4.5,
      'recipientName': 'Mariama D.',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'travelerName': 'Ibrahima Diallo',
      'departureDate':
          DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    });

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('IN_TRANSIT : stepper étape 3, badge transit', (tester) async {
    await tester.pumpWidget(_wrap(ShipmentCard(
      bid: _bid('IN_TRANSIT'),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('EN TRANSIT'), findsOneWidget);
    expect(find.byType(ShipmentStepper), findsOneWidget);
    expect(find.textContaining('4,5 kg'), findsOneWidget);
    expect(find.textContaining('Mariama'), findsOneWidget);
    expect(find.textContaining('Ibrahima'), findsOneWidget);
  });

  testWidgets('PENDING : pas de stepper (pré-acceptation)', (tester) async {
    await tester.pumpWidget(_wrap(ShipmentCard(
      bid: _bid('PENDING'),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShipmentStepper), findsNothing);
    expect(find.textContaining('EN ATTENTE'), findsOneWidget);
  });

  test('shipmentStepFor mappe les statuts vers les étapes', () {
    expect(shipmentStepFor('ACCEPTED'), 1);
    expect(shipmentStepFor('HANDED_OVER'), 2);
    expect(shipmentStepFor('IN_TRANSIT'), 3);
    expect(shipmentStepFor('COMPLETED'), 4);
    expect(shipmentStepFor('PENDING'), isNull);
    expect(shipmentStepFor('AWAITING_PAYMENT'), isNull);
  });
}
```

- [ ] **Step 3: Vérifier l'échec**

Run: `flutter test test/features/matching/shipment_card_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implémenter**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design/design_system.dart';
import '../../data/models/bid_model.dart';

/// Étape du colis (1=Remis…4=Livraison) ou null si pré-acceptation.
int? shipmentStepFor(String status) => switch (status) {
      'ACCEPTED' => 1,
      'HANDED_OVER' => 2,
      'IN_TRANSIT' => 3,
      'COMPLETED' => 4,
      _ => null,
    };

/// Carte envoi redesign : route, badge statut, stepper d'étapes du colis,
/// voyageur + action de suivi.
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({
    super.key,
    required this.bid,
    required this.onTap,
    required this.index,
  });

  final BidModel bid;
  final VoidCallback onTap;
  final int index;

  (Color bg, Color fg, String label) _badge(ColorScheme cs) =>
      switch (bid.status) {
        'IN_TRANSIT' => (cs.infoLight, cs.info, 'EN TRANSIT'),
        'HANDED_OVER' => (cs.infoLight, cs.info, 'REMIS'),
        'ACCEPTED' => (cs.warningLight, cs.warning, 'À REMETTRE'),
        'PENDING' ||
        'AWAITING_PAYMENT' ||
        'PAYMENT_ESCROWED' =>
          (cs.warningLight, cs.warning, 'EN ATTENTE'),
        'COMPLETED' => (cs.successLight, cs.success, 'LIVRÉ'),
        'CANCELLED' || 'REJECTED' || 'NO_SHOW' || 'EXPIRED' ||
        'PARCEL_REFUSED' =>
          (DonyColors.neutral100, cs.onSurfaceVariant, 'TERMINÉ'),
        _ => (DonyColors.neutral100, cs.onSurfaceVariant, bid.status),
      };

  String _stepLabel() => switch (bid.status) {
        'ACCEPTED' => 'Remise au voyageur à venir',
        'HANDED_OVER' => 'Colis remis au voyageur',
        'IN_TRANSIT' => 'En vol vers ${bid.arrivalCity ?? 'destination'}',
        'COMPLETED' => 'Livré',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (badgeBg, badgeFg, badgeLabel) = _badge(cs);
    final step = shipmentStepFor(bid.status);
    final weight = bid.weightKg;

    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
          boxShadow: const [
            BoxShadow(
                color: DonyColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(bid.departureCity ?? '—',
                              style: tt.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 14, color: cs.primary),
                        ),
                        Flexible(
                          child: Text(bid.arrivalCity ?? '—',
                              style: tt.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (weight != null)
                            'Colis ${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1).replaceAll('.', ',')} kg',
                          if (bid.recipientName != null)
                            'pour ${bid.recipientName}',
                        ].join(' · '),
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    badgeLabel,
                    style: tt.labelSmall?.copyWith(color: badgeFg),
                  ),
                ),
              ],
            ),
            if (step != null) ...[
              const SizedBox(height: DonySpacing.md),
              ShipmentStepper(currentStep: step),
              const SizedBox(height: DonySpacing.xs + 2),
              Text(
                _stepLabel(),
                style: tt.bodySmall?.copyWith(
                  color: badgeFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: DonySpacing.md),
            Divider(height: 1, color: DonyColors.neutral100),
            const SizedBox(height: DonySpacing.sm + 2),
            Row(
              children: [
                if (bid.travelerName != null)
                  Expanded(
                    child: Row(children: [
                      DonyAvatar(
                          name: bid.travelerName!, size: DonyAvatarSize.sm),
                      const SizedBox(width: DonySpacing.sm),
                      Flexible(
                        child: Text(bid.travelerName!,
                            style: tt.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  )
                else
                  const Spacer(),
                Text(
                  switch (bid.status) {
                    'IN_TRANSIT' || 'HANDED_OVER' => 'Suivre le colis →',
                    'ACCEPTED' => 'Voir le QR →',
                    _ => 'Détails →',
                  },
                  style: tt.titleSmall?.copyWith(color: cs.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return card
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

/// Stepper 4 étapes du colis : remis → embarqué → en vol → livraison.
class ShipmentStepper extends StatelessWidget {
  const ShipmentStepper({super.key, required this.currentStep});

  /// Étape courante (1..4).
  final int currentStep;

  static const _icons = [
    Icons.check_rounded,
    Icons.inventory_2_rounded,
    Icons.flight_rounded,
    Icons.home_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 1; i <= 4; i++) {
      final done = i < currentStep;
      final current = i == currentStep;
      children.add(Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: done || current ? cs.primary : DonyColors.neutral100,
          shape: BoxShape.circle,
          border: current
              ? Border.all(color: DonyColors.blue200, width: 3)
              : null,
        ),
        child: Icon(
          done ? Icons.check_rounded : _icons[i - 1],
          size: 12,
          color: done || current
              ? cs.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ));
      if (i < 4) {
        children.add(Expanded(
          child: Container(
            height: 2.5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i < currentStep ? cs.primary : DonyColors.neutral100,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ));
      }
    }
    return Row(children: children);
  }
}
```

(Si `BidModel.fromJson` exige des champs supplémentaires, compléter le helper `_bid` du test — se référer au modèle réel.)

- [ ] **Step 5: Vérifier**

Run: `flutter test test/features/matching/shipment_card_test.dart && flutter analyze lib/features/matching/presentation/widgets/shipment_card.dart`
Expected: PASS, 0 issue.

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/widgets/shipment_card.dart \
        test/features/matching/shipment_card_test.dart
git commit -m "feat(matching): ShipmentCard — stepper colis 4 étapes, badge statut, voyageur"
```

### Task 11: Redesign hub Envoyer (header, segmented, chips, empty state)

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart` (`_EnvoyerHeader` lignes ~376-457, `_EnvoyerSegmented` lignes ~462-522)
- Modify: `lib/features/matching/presentation/screens/shipment_list_screen.dart` (chips statut + intégration `ShipmentCard` + empty state)
- Test: modifier les tests existants du hub + `test/features/matching/shipment_list_screen_test.dart`

- [ ] **Step 1: Lire les deux fichiers en entier**

Relever : structure exacte de `_Seg`, les presets chips actuels (`kEnvoisEnCours` & co), le widget de carte remplacé par `ShipmentCard`, l'empty state actuel, le bouton filtre période.

- [ ] **Step 2: Tests qui échouent**

Compléter les tests widget existants du hub (ou en créer) :

```dart
// Assertions clés à ajouter :
// 1. Header : HeaderPill '✈️ Mes trajets' présent si onShowTrips != null,
//    absent sinon (rôle senderOnly).
expect(find.byKey(const Key('show-trips-pill')), findsOneWidget); // ou findsNothing
// 2. Segmented : capsule animée — les deux labels présents + AnimatedAlign.
expect(find.text('Envois'), findsOneWidget);
expect(find.text('Demandes'), findsOneWidget);
// 3. Onglet Envois : chips statut présents.
expect(find.text('Tous'), findsOneWidget);
expect(find.textContaining('En transit'), findsOneWidget);
// 4. Tap 'Livrés' → ShipmentFilterCubit.state.statuses == {'COMPLETED'}.
// 5. Empty state : mascotte + CTA 'Rechercher un trajet' + lien demandes.
```

- [ ] **Step 3: Implémenter — header**

Dans `_EnvoyerHeader`, remplacer le bloc `SecondaryActivityEntry` et le bouton « Nouveau » par les `HeaderPill` :

```dart
Row(
  children: [
    Expanded(
      child: Text('Envoyer',
          style: Theme.of(context).textTheme.displaySmall),
    ),
    if (onShowTrips != null) ...[
      HeaderPill(
        key: const Key('show-trips-pill'),
        label: 'Mes trajets',
        icon: Icons.flight_takeoff_rounded,
        style: HeaderPillStyle.soft,
        onTap: onShowTrips!,
      ),
      const SizedBox(width: DonySpacing.xs + 3),
    ],
    HeaderPill(label: '+ Nouveau', onTap: onNew),
  ],
)
```

(+ import `package:dony/features/matching/presentation/widgets/activity_header_widgets.dart`. Supprimer l'import `SecondaryActivityEntry` s'il n'est plus utilisé dans ce fichier.)

- [ ] **Step 4: Implémenter — segmented glissant**

Remplacer le corps de `_EnvoyerSegmented` (garder ses BlocBuilders badges) par une capsule animée :

```dart
// Dans le builder existant, remplacer le Row de _Seg par :
Container(
  padding: const EdgeInsets.all(3),
  decoration: BoxDecoration(
    color: DonyColors.neutral100,
    borderRadius: BorderRadius.circular(DonyRadius.md),
  ),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final segWidth = constraints.maxWidth / 2;
      return Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: controller.index == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: segWidth,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(DonyRadius.md - 3),
                boxShadow: const [
                  BoxShadow(
                      color: DonyColors.shadow,
                      blurRadius: 4,
                      offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _SegLabel(
                label: 'Envois',
                badge: badgeForIndex(0, envoisRaw),
                active: controller.index == 0,
                onTap: () => controller.animateTo(0),
              ),
              _SegLabel(
                label: 'Demandes',
                badge: negoBadge,
                active: controller.index == 1,
                onTap: () => controller.animateTo(1),
              ),
            ],
          ),
        ],
      );
    },
  ),
)
```

avec `_SegLabel` (remplace `_Seg`) :

```dart
class _SegLabel extends StatelessWidget {
  const _SegLabel({
    required this.label,
    required this.badge,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md - 3),
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: tt.titleSmall?.copyWith(
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: DonyColors.primarySoft,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text('$badge',
                      style: tt.labelSmall?.copyWith(color: cs.primary)),
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

- [ ] **Step 5: Implémenter — chips statut Envois + ShipmentCard + empty state**

Dans `shipment_list_screen.dart` :

1. Remplacer les chips presets actuels (`Tous / En cours / À venir / Passés`) par `StatusChipsRow<Set<String>>` mappée sur `ShipmentFilterCubit` :

```dart
StatusChipsRow<Set<String>>(
  chips: [
    const StatusChipData(label: 'Tous', value: <String>{}),
    StatusChipData(
        label: 'En transit', value: kEnvoisEnCours, dotColor: cs.info),
    StatusChipData(
        label: 'En attente', value: kEnvoisAVenir, dotColor: cs.warning),
    StatusChipData(
        label: 'Livrés', value: const {'COMPLETED'}, dotColor: cs.success),
  ],
  selected: context.watch<ShipmentFilterCubit>().state.statuses,
  onSelected: (statuses) =>
      context.read<ShipmentFilterCubit>().applyQuickPreset(statuses),
  trailing: IconButton(
    icon: const Icon(Icons.tune_rounded, size: 18),
    tooltip: 'Filtrer par période',
    onPressed: _openPeriodSheet, // bottom sheet période existant
  ),
),
```

Attention égalité de Set : `StatusChipsRow` compare `chip.value == selected` — pour des Sets utiliser `setEquals` ; modifier `_chip` dans `activity_header_widgets.dart` pour accepter un comparateur optionnel :

```dart
// Dans StatusChipsRow, ajouter :
final bool Function(T a, T b)? equals;
// et dans _chip :
final active = equals != null ? equals!(chip.value, selected) : chip.value == selected;
// À l'usage : equals: (a, b) => setEquals(a, b) (import package:flutter/foundation.dart)
```

2. Remplacer la carte item actuelle par `ShipmentCard(bid: bid, onTap: ..., index: i)` en conservant la navigation existante (détail / QR).

3. Remplacer l'empty state Envois par :

```dart
DonyEmptyState(
  title: "Aucun envoi pour l'instant",
  description:
      'Trouve un voyageur qui part vers ta destination et envoie ton premier colis.',
  type: DonyEmptyStateType.empty,
  mascotte: DonyMascotteType.assis,
  // Si DonyEmptyState n'accepte pas d'actions, composer :
  // Column(children: [DonyEmptyState(...), DonyButton('Rechercher un trajet'),
  //   TextButton('ou publie une demande de transport →')])
),
```

CTA « Rechercher un trajet » → navigation recherche existante ; lien secondaire → `controller.animateTo(1)` (onglet Demandes). Masquer recherche + chips quand la liste brute (non filtrée) est vide.

- [ ] **Step 6: Vérifier**

Run: `flutter test test/features/matching test/features/package_request && flutter analyze lib/features`
Expected: tous PASS (mettre à jour les tests existants cassés par la nouvelle structure), 0 issue.

- [ ] **Step 7: Commit**

```bash
git add lib/features/package_request lib/features/matching test/
git commit -m "feat(envoyer): redesign hub — pills header, segmented glissant, chips statut, ShipmentCard"
```

### Task 12: Onglet bottom nav « Annonces » → « Activités »

**Files:**
- Modify: `lib/app/main_shell.dart:169-172`
- Test: test existant du shell (chercher `find.text('Annonces')` dans `test/`)

- [ ] **Step 1: Modifier le label**

```dart
// Tab 1 — Activités (libellé+icône figés ; le contenu s'adapte au profil
// dans MatchingManagementScreen — Phase 2)
const tab1Label = 'Activités';
const tab1Icon = Icons.article_rounded;
const tab1IconOutlined = Icons.article_outlined;
```

- [ ] **Step 2: Mettre à jour les tests**

Run: `grep -rn "Annonces" test/ lib/app/` — remplacer les assertions `find.text('Annonces')` par `find.text('Activités')`. Vérifier aussi tooltips/Semantics éventuels dans `main_shell.dart`.

- [ ] **Step 3: Vérifier**

Run: `flutter test test/app/ 2>/dev/null || flutter test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/app/main_shell.dart test/
git commit -m "feat(nav): renomme l'onglet Annonces en Activités"
```

### Task 13: Vérification finale + documentation

**Files:**
- Modify: `CLAUDE.md` (table des events analytics)
- Create: `docs/stories-done/story-redesign-activites-envoyer.md`

- [ ] **Step 1: Suite complète + couverture Flutter**

Run: `flutter analyze && flutter test --coverage`
Expected: 0 issue, tous les tests PASS. Vérifier couverture ≥ 90 % (`genhtml coverage/lcov.info -o coverage/html` si lcov dispo, sinon inspecter lcov.info sur les nouveaux fichiers).

- [ ] **Step 2: Suite complète backend**

Run: `cd /Users/aboubakardiakite/Desktop/dony/dony-back && ./mvnw test jacoco:report`
Expected: tous PASS, couverture ≥ 90 % sur les nouvelles classes.

- [ ] **Step 3: Mettre à jour CLAUDE.md (analytics)**

Dans la table « Events actuellement implémentés » de `dony_app/CLAUDE.md`, ajouter :

```markdown
| `trip_filter_applied` | TripFilterCubit.setFilter() — chips statut Mes trajets |
```

- [ ] **Step 4: Vérification visuelle sur émulateur/simulateur**

Run: `flutter run --dart-define-from-file=env.dev.json` (backend dev démarré). Vérifier : rendu des deux écrans, sens de l'icône avion (RotatedBox si besoin), pulse badge, glissement segmented, drapeaux, dark mode (`ThemeMode.system`).

- [ ] **Step 5: Story doc + commit final**

Créer `docs/stories-done/story-redesign-activites-envoyer.md` selon le template du CLAUDE.md (résumé, fichiers, flux, BLoC, API, pièges).

```bash
git add CLAUDE.md docs/stories-done/story-redesign-activites-envoyer.md
git commit -m "docs: story redesign Activités + table analytics"
```

---

## Self-review (fait à l'écriture)

- **Couverture spec :** direction A ✓ (T7/T10), drapeaux timeline ✓ (T6/T7), stats V2 ✓ (T2/T3/T4/T5/T8/T9), chips Airbnb ✓ (T8/T9/T11), pill header Envoyer ✓ (T9), pill Mes trajets ✓ (T11), segmented glissant ✓ (T11), stepper colis ✓ (T10), empty state mascotte ✓ (T11), « Activités » ✓ (T12), rôle senderOnly ✓ (pills conditionnés par `onSendParcel`/`onShowTrips`, alimentés par `annoncesLayoutFor` inchangé), endpoint backend ✓ (T1-T3), analytics ✓ (T5, T13), tests ≥ 90 % ✓ (T13).
- **Types :** `TripStatusFilter`/`TripFilterState.matchesStatus`/`matchesQuery` cohérents T5↔T8↔T9 ; `StatusChipData`/`StatusChipsRow` T8↔T9↔T11 (avec ajout `equals` pour les Sets en T11) ; `shipmentStepFor` T10 ; `TripsSummaryDto` T2↔T3, `TripsSummaryModel` T4↔T5↔T8.
- **Placeholders :** les helpers de persistance des tests IT backend (T1) renvoient au pattern existant `TravelerStatsListenerIT` (copie explicite) ; les steps « lire le fichier d'abord » (T9/T10/T11) sont volontaires — l'exécutant ajuste les signatures réelles avant d'appliquer le code fourni.
