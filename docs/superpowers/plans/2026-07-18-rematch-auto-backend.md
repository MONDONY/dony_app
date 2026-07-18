# Rematch automatique — Plan d'implémentation BACKEND (dony-back)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Génération de suggestions de trajets alternatifs pertinentes PAR expéditeur affecté lors d'une annulation de trajet, notification enrichie avec deep link, DTO enrichi (note voyageur), exposition de la cancellation sur BidResponse.

**Architecture:** Extraction d'un `RematchService` dédié dans `cancellation/` (documenté dans l'archi). Requête via les Specifications JPA existantes de `matching/` (pas de full scan). `TripCancelledEvent` enrichi d'une map additive `rematchBySender`. Notification conditionnelle dans `NotificationDispatcher`. Aucune migration (tables V8 existantes).

**Tech Stack:** Spring Boot 3.4, Java 21, JPA Specifications, records, MockMvc, @DataJpaTest.

## Global Constraints

- Fenêtre : départ alternative ∈ `[LocalDate.now(ZoneOffset.UTC), departureDate_annulé + 3 jours]`, bornes incluses.
- Capacité : `availableKg` ≥ `weightKg` du bid annulé.
- Exclusions : annonce annulée, TOUTES les annonces du voyageur annulant, non-`ACTIVE`, non publiques (`publicOrOpenSurplus`), voyageurs bloqués (`notBlockedBy(senderId)`).
- Tri : `departureDate` croissante puis note voyageur décroissante. Limite **5** par expéditeur.
- Suggestions générées pour CHAQUE cancellation (une par bid affecté) — fix du bug « première seulement ».
- Textes notification exacts (§2 de la spec) : avec alternatives → « Trajet annulé — remboursement en cours. N voyageur(s) alternatif(s) disponible(s) » + `cancellationId` dans data ; sans → « Trajet annulé — Aucun voyageur disponible dans les 72h, votre remboursement est traité » sans `cancellationId`.
- `CancellationEntity.rematchStatus` : `"NONE"` → `"SUGGESTED"` si ≥ 1 suggestion.
- Aucune migration Flyway. Repo : `/Users/aboubakardiakite/Desktop/dony/dony-back`. Branche : `feature/rematch-auto`.
- `./mvnw test` vert. Jamais commit sur `main`. Jamais de ligne Co-Authored-By.

---

### Task B1: RematchService — génération par cancellation via Specifications

**Files:**
- Create: `src/main/java/com/dony/api/cancellation/RematchService.java`
- Modify: `src/main/java/com/dony/api/cancellation/CancellationService.java` (méthode `generateRematchSuggestions` ~lignes 216-255 supprimée, appel remplacé ~ligne 166)
- Create: `src/test/java/com/dony/api/cancellation/RematchServiceTest.java`
- Create: `src/test/java/com/dony/api/cancellation/RematchSpecificationDbTest.java`

**Interfaces:**
- Consumes: `AnnouncementSpecification.{hasStatus, hasDepartureCity, hasArrivalCity, departureDateFrom, departureDateTo, minAvailableKg, publicOrOpenSurplus, notBlockedBy}` (matching/), `AnnouncementRepository extends JpaSpecificationExecutor`, `RematchSuggestionRepository`, `UserRepository`.
- Produces: `RematchService.generateForCancellations(AnnouncementEntity cancelled, List<BidEntity> affectedBids, List<CancellationEntity> cancellations)` → `Map<UUID, RematchInfo>` (clé = senderId) ; `record RematchInfo(UUID cancellationId, int suggestionCount)` (public, imbriqué dans RematchService).

- [ ] **Step 1: Écrire le test unitaire (échoue)**

`RematchServiceTest` (Mockito, calquer le style de `CancellationServiceTest` existant — même mocks) :

```java
package com.dony.api.cancellation;

// imports : Mockito, JUnit5, AnnouncementEntity, BidEntity, UserEntity, etc.

@ExtendWith(MockitoExtension.class)
class RematchServiceTest {

    @Mock AnnouncementRepository announcementRepository;
    @Mock RematchSuggestionRepository rematchSuggestionRepository;
    @Mock CancellationRepository cancellationRepository;
    @Mock UserRepository userRepository;
    @InjectMocks RematchService rematchService;

    // Cas à couvrir (un @Test chacun) :
    // 1. multiSenders_eachCancellationGetsOwnSuggestions :
    //    2 bids affectés (kg différents : 5kg et 20kg), 1 alternative avec availableKg=10
    //    → suggestions créées pour la cancellation du bid 5kg SEULEMENT ;
    //    la map retournée contient les 2 senderIds (counts 1 et 0).
    // 2. sortsByDateThenRating : 3 alternatives (dates J+1/J+1/J+2, notes 3.0/4.8/5.0)
    //    → ordre persisté : J+1 note 4.8... attention : J+1&4.8 avant J+1&3.0, puis J+2&5.0.
    // 3. limitsToFive : 7 alternatives valides → 5 suggestions persistées.
    // 4. setsRematchStatusSuggested : cancellation.rematchStatus == "SUGGESTED" après
    //    génération avec ≥1 alternative ; reste "NONE" si 0 alternative.
    // 5. emptyBids_returnsEmptyMap : affectedBids vide → map vide, aucun save.
    // Le mock announcementRepository.findAll(any(Specification.class)) retourne la liste
    // d'alternatives du cas ; userRepository.findAllById(...) retourne les voyageurs avec notes.
}
```

Note implémenteur : le tri et la limite se font en mémoire APRÈS la requête Specification (le filtrage dur — statut/corridor/date/kg/public/blocked — se fait en SQL). La note voyageur vient de `UserEntity.getAverageRating()` (vérifier le getter réel ; `null` = trié en dernier).

- [ ] **Step 2: Lancer — doit échouer**

Run: `./mvnw test -Dtest=RematchServiceTest`
Expected: FAIL (classe RematchService absente → erreur de compilation).

- [ ] **Step 3: Implémenter RematchService**

```java
package com.dony.api.cancellation;

import com.dony.api.matching.AnnouncementEntity;
import com.dony.api.matching.AnnouncementRepository;
import com.dony.api.matching.AnnouncementSpecification;
import com.dony.api.matching.AnnouncementStatus;
import com.dony.api.matching.BidEntity;
import com.dony.api.auth.UserRepository;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Story 5.6 — suggestions de trajets alternatifs après annulation d'un trajet.
 * Une liste de suggestions par cancellation (donc par expéditeur affecté),
 * filtrée sur la capacité du bid annulé de CET expéditeur.
 */
@Service
public class RematchService {

    static final int MAX_SUGGESTIONS = 5;
    static final int WINDOW_DAYS = 3;

    private final AnnouncementRepository announcementRepository;
    private final RematchSuggestionRepository rematchSuggestionRepository;
    private final CancellationRepository cancellationRepository;
    private final UserRepository userRepository;

    public record RematchInfo(UUID cancellationId, int suggestionCount) {}

    public RematchService(AnnouncementRepository announcementRepository,
                          RematchSuggestionRepository rematchSuggestionRepository,
                          CancellationRepository cancellationRepository,
                          UserRepository userRepository) {
        this.announcementRepository = announcementRepository;
        this.rematchSuggestionRepository = rematchSuggestionRepository;
        this.cancellationRepository = cancellationRepository;
        this.userRepository = userRepository;
    }

    public Map<UUID, RematchInfo> generateForCancellations(AnnouncementEntity cancelled,
                                                           List<BidEntity> affectedBids,
                                                           List<CancellationEntity> cancellations) {
        Map<UUID, RematchInfo> result = new HashMap<>();
        if (affectedBids.isEmpty()) return result;

        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        LocalDate to = cancelled.getDepartureDate().plusDays(WINDOW_DAYS);

        for (int i = 0; i < affectedBids.size(); i++) {
            BidEntity bid = affectedBids.get(i);
            CancellationEntity cancellation = cancellations.get(i);

            List<AnnouncementEntity> alternatives = findAlternatives(
                    cancelled, bid.getSenderId(), bid.getWeightKg(), today, to);

            for (AnnouncementEntity alt : alternatives) {
                RematchSuggestionEntity suggestion = new RematchSuggestionEntity();
                suggestion.setCancellationId(cancellation.getId());
                suggestion.setAnnouncementId(alt.getId());
                rematchSuggestionRepository.save(suggestion);
            }
            if (!alternatives.isEmpty()) {
                cancellation.setRematchStatus("SUGGESTED");
                cancellationRepository.save(cancellation);
            }
            result.put(bid.getSenderId(),
                    new RematchInfo(cancellation.getId(), alternatives.size()));
        }
        return result;
    }

    private List<AnnouncementEntity> findAlternatives(AnnouncementEntity cancelled,
                                                      UUID senderId, BigDecimal weightKg,
                                                      LocalDate from, LocalDate to) {
        Specification<AnnouncementEntity> spec = Specification
                .where(AnnouncementSpecification.hasStatus(AnnouncementStatus.ACTIVE))
                .and(AnnouncementSpecification.hasDepartureCity(cancelled.getDepartureCity()))
                .and(AnnouncementSpecification.hasArrivalCity(cancelled.getArrivalCity()))
                .and(AnnouncementSpecification.departureDateFrom(from))
                .and(AnnouncementSpecification.departureDateTo(to))
                .and(AnnouncementSpecification.minAvailableKg(weightKg))
                .and(AnnouncementSpecification.publicOrOpenSurplus())
                .and(AnnouncementSpecification.notBlockedBy(senderId))
                .and((root, query, cb) -> cb.notEqual(root.get("id"), cancelled.getId()))
                .and((root, query, cb) -> cb.notEqual(root.get("travelerId"), cancelled.getTravelerId()));

        List<AnnouncementEntity> candidates = announcementRepository.findAll(spec);

        Map<UUID, BigDecimal> ratings = userRepository
                .findAllById(candidates.stream().map(AnnouncementEntity::getTravelerId).collect(Collectors.toSet()))
                .stream()
                .filter(u -> u.getAverageRating() != null)
                .collect(Collectors.toMap(u -> u.getId(), u -> u.getAverageRating()));

        return candidates.stream()
                .sorted(Comparator
                        .comparing(AnnouncementEntity::getDepartureDate)
                        .thenComparing(a -> ratings.getOrDefault(a.getTravelerId(), BigDecimal.valueOf(-1)),
                                Comparator.reverseOrder()))
                .limit(MAX_SUGGESTIONS)
                .toList();
    }
}
```

Note implémenteur : adapter les signatures réelles — `AnnouncementSpecification.publicOrOpenSurplus()` et `notBlockedBy(...)` peuvent avoir des paramètres différents (vérifier dans `matching/AnnouncementSpecification.java`) ; `BidEntity.getWeightKg()` (vérifier le nom réel) ; `UserEntity.getAverageRating()` (vérifier). Si `minAvailableKg` attend un autre type, adapter. Les specs privées inline (notEqual) restent locales.

- [ ] **Step 4: Brancher dans CancellationService**

Dans `CancellationService.cancelTrip` : injecter `RematchService` (constructeur), supprimer la méthode privée `generateRematchSuggestions` et remplacer l'appel (~ligne 166) :

```java
// Generate rematch suggestions for each affected sender's cancellation
Map<UUID, RematchService.RematchInfo> rematchBySender =
        rematchService.generateForCancellations(announcement, affectedBids, cancellations);
```

La `CancellationResponse` continue de renvoyer des `List<RematchSuggestionDto>` (celles du 1er expéditeur ou vide — utilisée par l'écran voyageur post-annulation ; conserver le comportement : construire les DTO à partir des suggestions du PREMIER sender via `getRematchSuggestions`-like ou renvoyer liste vide + laisser l'app fetcher ; SIMPLE : renvoyer les suggestions du premier bid comme avant, en réutilisant les entités déjà créées). ATTENTION : ne pas casser le contrat JSON — le champ `rematchSuggestions` doit rester présent.

Le publish de `TripCancelledEvent` (~ligne 160) doit désormais avoir lieu APRÈS la génération (l'événement transportera la map en Task B2 — dans cette task, garder l'appel event inchangé, juste déplacé après la génération).

- [ ] **Step 5: Lancer les tests unitaires — doivent passer**

Run: `./mvnw test -Dtest=RematchServiceTest,CancellationServiceTest`
Expected: PASS (adapter les tests existants de CancellationServiceTest qui mockaient l'ancien flux inline — mocker `RematchService` désormais injecté).

- [ ] **Step 6: Test DB réel de la Specification composée (échoue puis passe)**

`RematchSpecificationDbTest` (`@DataJpaTest`, pattern de `PackageRequestUrgentSpecificationDbTest`) : seeder des annonces réelles et exécuter la Specification composée (extraire la construction de la spec dans une méthode package-private `buildAlternativesSpec(...)` de RematchService pour la tester, ou instancier RematchService avec les vrais repositories @Autowired) :
- alternative valide même corridor J+1 → retournée ;
- date = departureDate_annulé + 3 (borne) → retournée ; +4 → exclue ; hier → exclue ;
- availableKg insuffisant → exclue ;
- annonce du voyageur annulant → exclue ;
- annonce CANCELLED/DRAFT → exclue.

Run: `./mvnw test -Dtest=RematchSpecificationDbTest`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/main/java/com/dony/api/cancellation/ src/test/java/com/dony/api/cancellation/
git commit -m "feat(cancellation): RematchService — suggestions par expéditeur via Specifications"
```

---

### Task B2: Événement enrichi + notification conditionnelle

**Files:**
- Modify: `src/main/java/com/dony/api/cancellation/events/TripCancelledEvent.java`
- Modify: `src/main/java/com/dony/api/cancellation/CancellationService.java` (publish ~ligne 160)
- Modify: `src/main/java/com/dony/api/notifications/NotificationDispatcher.java:117-125` (`onTripCancelled`)
- Modify: `src/test/java/com/dony/api/notifications/NotificationDispatcherTest.java`

**Interfaces:**
- Consumes: `RematchService.RematchInfo` (B1).
- Produces: `TripCancelledEvent.getRematchBySender()` → `Map<UUID, RematchBySenderInfo>` où `record RematchBySenderInfo(UUID cancellationId, int suggestionCount)` (imbriqué dans l'event pour éviter la dépendance notifications→cancellation service).

- [ ] **Step 1: Enrichir TripCancelledEvent (additif)**

Ajouter au pattern des constructeurs existants (3 constructeurs rétro-compatibles déjà en place) :

```java
/** Suggestions rematch par expéditeur (Story 5.6). Clé = senderId. */
public record RematchBySenderInfo(UUID cancellationId, int suggestionCount) {}

private final Map<UUID, RematchBySenderInfo> rematchBySender;
```

Nouveau constructeur complet avec le param `Map<UUID, RematchBySenderInfo> rematchBySender` en dernier ; les constructeurs existants délèguent avec `Map.of()` (aucun call site existant ne casse — `cancelAfterHandover` et les tests continuent de compiler). Getter `getRematchBySender()` (jamais null, défaut `Map.of()`).

- [ ] **Step 2: Publier la map depuis cancelTrip**

```java
Map<UUID, TripCancelledEvent.RematchBySenderInfo> rematchInfo = new HashMap<>();
rematchBySender.forEach((senderId, info) -> rematchInfo.put(senderId,
        new TripCancelledEvent.RematchBySenderInfo(info.cancellationId(), info.suggestionCount())));

eventPublisher.publishEvent(new TripCancelledEvent(
        request.announcementId(), traveler.getId(), affectedSenderIds, request.reason(),
        affectedBidIds, bidPaymentMethods, bidCommissionChargedVia, rematchInfo));
```

- [ ] **Step 3: Test NotificationDispatcher (échoue d'abord)**

Dans `NotificationDispatcherTest` (pattern MockitoExtension existant) :

```java
@Test
void onTripCancelled_withSuggestions_notifiesWithDeepLink() {
    // event avec rematchBySender = {senderId: (cancellationId, 3)}
    // verify notifyUser(senderId, "Trajet annulé",
    //   "Le voyageur a annulé son trajet — remboursement en cours. 3 voyageurs alternatifs disponibles",
    //   data contenant type=TRIP_CANCELLED ET cancellationId=<uuid>)
}

@Test
void onTripCancelled_withoutSuggestions_notifiesRefundOnly() {
    // event avec rematchBySender = {senderId: (cancellationId, 0)}
    // verify body == "Trajet annulé — Aucun voyageur disponible dans les 72h, votre remboursement est traité"
    // et data SANS clé cancellationId
}

@Test
void onTripCancelled_missingRematchInfo_keepsLegacyBody() {
    // event via constructeur legacy (map vide) → body actuel
    // "Le voyageur a annulé son trajet. Remboursement en cours." sans cancellationId
    // (chemin cancelAfterHandover inchangé)
}
```

Run: `./mvnw test -Dtest=NotificationDispatcherTest` → FAIL sur les 2 premiers.

- [ ] **Step 4: Implémenter onTripCancelled**

```java
@EventListener @Async
public void onTripCancelled(TripCancelledEvent event) {
    if (event.getAffectedSenderIds() == null) return;
    for (UUID senderId : event.getAffectedSenderIds()) {
        TripCancelledEvent.RematchBySenderInfo info = event.getRematchBySender().get(senderId);
        if (info == null) {
            notifyUser(senderId, "Trajet annulé",
                    "Le voyageur a annulé son trajet. Remboursement en cours.",
                    Map.of("type", "TRIP_CANCELLED"));
        } else if (info.suggestionCount() > 0) {
            int n = info.suggestionCount();
            notifyUser(senderId, "Trajet annulé",
                    "Le voyageur a annulé son trajet — remboursement en cours. "
                            + n + " voyageur" + (n > 1 ? "s" : "") + " alternatif"
                            + (n > 1 ? "s" : "") + " disponible" + (n > 1 ? "s" : ""),
                    Map.of("type", "TRIP_CANCELLED",
                           "cancellationId", info.cancellationId().toString()));
        } else {
            notifyUser(senderId, "Trajet annulé",
                    "Trajet annulé — Aucun voyageur disponible dans les 72h, votre remboursement est traité",
                    Map.of("type", "TRIP_CANCELLED"));
        }
    }
}
```

- [ ] **Step 5: Vérifier + commit**

Run: `./mvnw test -Dtest=NotificationDispatcherTest,CancellationServiceTest,RematchServiceTest`
Expected: PASS.

```bash
git add src/main/java/com/dony/api/cancellation/ src/main/java/com/dony/api/notifications/ src/test/java/com/dony/api/notifications/
git commit -m "feat(notifications): notification d'annulation enrichie avec deep link rematch"
```

---

### Task B3: DTO enrichi (note voyageur) + BidResponse (cancellationId côté sender)

**Files:**
- Modify: `src/main/java/com/dony/api/cancellation/dto/RematchSuggestionDto.java`
- Modify: `src/main/java/com/dony/api/cancellation/CancellationService.java` (`getRematchSuggestions` ~lignes 178-214 + construction DTO dans cancelTrip)
- Modify: `src/main/java/com/dony/api/matching/dto/BidResponse.java` (+2 champs en fin de record)
- Modify: `src/main/java/com/dony/api/matching/BidService.java` (~lignes 913-925 et construction ~977)
- Modify: `src/test/java/com/dony/api/cancellation/CancellationControllerIT.java` (ou le fichier IT réel du controller)
- Modify: `src/test/java/com/dony/api/matching/BidServiceTest.java` (ou le test réel de toBidResponse)

**Interfaces:**
- Produces: `RematchSuggestionDto` + `String travelerFirstName`, `BigDecimal travelerRating` (nullable), `Integer travelerRatingCount` (adapter au champ réel de UserEntity ; si pas de count, omettre ce champ — vérifier `ratingCount`/`totalRatings`). `BidResponse` + `UUID tripCancellationId` (nullable), `String tripCancellationRematchStatus` (nullable) en DERNIERS champs.

- [ ] **Step 1: Test IT des suggestions enrichies (échoue)**

Dans le test IT du controller cancellation existant, cas `GET /cancellations/{id}/rematch-suggestions` : seeder un voyageur alternatif avec prénom + note, asserter `$[0].travelerFirstName`, `$[0].travelerRating`.

- [ ] **Step 2: Enrichir le DTO + les 2 sites de construction**

`RematchSuggestionDto` : ajouter `String travelerFirstName, BigDecimal travelerRating, Integer travelerRatingCount` en fin de record. Dans `getRematchSuggestions` : batch-loader les voyageurs (`userRepository.findAllById(...)` sur les `travelerId` des annonces — PAS un findById par suggestion) puis construire. Même chose pour la liste renvoyée par `cancelTrip` (suggestions du 1er sender).

- [ ] **Step 3: BidResponse — exposer la cancellation trajet-annulé**

Dans `BidService` (~ligne 913, `bidCancellations` déjà chargé via `cancellationRepository.findAllByBidId`) :

```java
CancellationEntity tripCancellation = bidCancellations.stream()
        .filter(c -> "TRIP_CANCELLED".equals(c.getReason()))
        .findFirst().orElse(null);
UUID tripCancellationId = tripCancellation != null ? tripCancellation.getId() : null;
String tripCancellationRematchStatus = tripCancellation != null ? tripCancellation.getRematchStatus() : null;
```

(NB : `reason` est un String côté entité — vérifier la valeur réellement stockée par `cancelTrip` : c'est `request.reason()` libre, PAS forcément "TRIP_CANCELLED". VÉRIFIER : si le reason stocké est le motif utilisateur (vol annulé…), identifier la cancellation trajet par `scope == HANDOVER && cancelledBy == announcement.travelerId && noShowStatus == null` OU ajouter la constante. Trancher en lisant `cancelTrip` : le filtre correct est celui qui distingue cette ligne des cancellations no-show/après-remise du même bid. Documenter le choix dans le rapport.)

Ajouter les 2 champs en fin de `BidResponse` et au site de construction unique (~ligne 977/1025+). Test : `BidServiceTest` — bid annulé via trajet → champs remplis ; bid actif → null.

- [ ] **Step 4: Vérifier + commit**

Run: `./mvnw test -Dtest=CancellationControllerIT,BidServiceTest,CancellationServiceTest`
Expected: PASS.

```bash
git add src/main/java/com/dony/api/ src/test/java/com/dony/api/
git commit -m "feat(cancellation): DTO rematch enrichi (note voyageur) + cancellation exposée sur BidResponse"
```

---

### Task B4: Vérification globale + push + PR

- [ ] **Step 1: Suite complète**

Run: `./mvnw test`
Expected: BUILD SUCCESS (0 échec).

- [ ] **Step 2: Push + PR draft**

```bash
git push -u origin feature/rematch-auto
gh pr create --draft --title "feat: rematch automatique après annulation de trajet" --body "Story 5.6. RematchService dédié (Specifications, par expéditeur, fenêtre [today, départ+3j], capacité, tri date+note, limite 5). Notification TRIP_CANCELLED enrichie avec deep link cancellationId. DTO suggestions + note voyageur. BidResponse expose tripCancellationId/rematchStatus. Aucune migration."
```

## Self-review effectué

- Spec §3.1–3.4 couverts : B1 (service+statut), B2 (event+notif), B3 (DTO+BidResponse). ✓
- Bornes fenêtre identiques service/test DB. ✓ Textes notification = spec §2. ✓
- Types cohérents entre tasks : `RematchService.RematchInfo` (B1) mappé vers `TripCancelledEvent.RematchBySenderInfo` (B2) — conversion explicite dans cancelTrip. ✓
- Point de vigilance signalé (pas un placeholder : décision à prendre sur pièce) : l'identification de la cancellation « trajet annulé » dans B3 dépend de la valeur réelle stockée dans `reason` — les deux options valides sont données, l'implémenteur tranche en lisant le code et documente. ✓
