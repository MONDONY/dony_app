# Annonces urgentes — Plan d'implémentation BACKEND (dony-back)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un filtre serveur `urgent` (date clé proche) aux recherches de trajets et demandes, un seuil configurable, et exposer `urgent` dans les DTO de réponse.

**Architecture:** Aucun nouveau champ en base — l'urgence est dérivée de `departureDate` (trajet) / `desiredDate` (demande). Filtre appliqué via les Specifications JPA de date existantes. Seuil dans `DonyConfigProperties` (record imbriqué), surchargeable par env. Champ `urgent` calculé dans les mappers `@Component` (seuil injecté).

**Tech Stack:** Spring Boot 3.4, Java 21, JPA Specifications, records, MockMvc.

## Global Constraints

- Seuil urgent : `dony.urgency.threshold-days`, défaut **3**, surchargeable via `${DONY_URGENCY_THRESHOLD_DAYS:3}`.
- Définition urgent : `today ≤ date ≤ today + thresholdDays` (bornes incluses). Date passée (`< today`) = non urgent.
- **Aucune migration Flyway** (dérivé des colonnes existantes).
- Repo dony-back : `/Users/aboubakardiakite/Desktop/dony/dony-back`. Branche : `feature/urgent-announcements`.
- Tests : `./mvnw test` doit rester vert. Controllers = `@SpringBootTest` + MockMvc ; services = Mockito.
- Ne jamais commit sur `main`.

---

### Task 1: Config du seuil + endpoint public

**Files:**
- Modify: `src/main/java/com/dony/api/config/DonyConfigProperties.java:13-35`
- Create: `src/main/java/com/dony/api/config/dto/UrgencyThresholdResponse.java`
- Modify: `src/main/java/com/dony/api/config/ConfigController.java:12-31`
- Modify: `src/main/resources/application.yml` (bloc `dony:` après `commission`)
- Modify: `src/test/java/com/dony/api/config/ConfigControllerIT.java`

**Interfaces:**
- Produces: `config.urgency().thresholdDays()` → `int` (défaut 3) ; `GET /config/urgency-threshold` → `{ "thresholdDays": 3 }`.

- [ ] **Step 1: Ajouter le record Urgency à DonyConfigProperties**

Dans `DonyConfigProperties.java`, ajouter le param `Urgency urgency` au record principal + le sous-record avec défaut :

```java
record DonyConfigProperties(
    Commission commission,
    Limits limits,
    Urgency urgency
) {
    record Commission(BigDecimal rate) {}

    record Urgency(Integer thresholdDays) {
        public int thresholdDays() {
            return thresholdDays == null ? 3 : thresholdDays;
        }
    }

    // ... Limits inchangé ...
}
```

- [ ] **Step 2: Ajouter la config YAML**

Dans `src/main/resources/application.yml`, après le bloc `commission:` (vers ligne 111) :

```yaml
  urgency:
    threshold-days: ${DONY_URGENCY_THRESHOLD_DAYS:3}
```

Vérifier que `src/test/resources/application-test.yml` n'a pas besoin de l'override (le défaut 3 s'applique). Si le binding échoue au boot test, ajouter le même bloc `dony.urgency.threshold-days: 3` dans application-test.yml.

- [ ] **Step 3: Créer le DTO de réponse**

`src/main/java/com/dony/api/config/dto/UrgencyThresholdResponse.java` :

```java
package com.dony.api.config.dto;

public record UrgencyThresholdResponse(Integer thresholdDays) {}
```

- [ ] **Step 4: Écrire le test d'intégration (échoue d'abord)**

Dans `ConfigControllerIT.java`, ajouter :

```java
@Test
void getUrgencyThreshold_returnsConfiguredValue() throws Exception {
    mockMvc.perform(get("/config/urgency-threshold"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.thresholdDays").value(3));
}
```

- [ ] **Step 5: Lancer le test — doit échouer**

Run: `./mvnw test -Dtest=ConfigControllerIT#getUrgencyThreshold_returnsConfiguredValue`
Expected: FAIL (404, endpoint absent).

- [ ] **Step 6: Ajouter l'endpoint**

Dans `ConfigController.java`, importer `UrgencyThresholdResponse` et ajouter :

```java
@GetMapping("/urgency-threshold")
public ResponseEntity<UrgencyThresholdResponse> getUrgencyThreshold() {
    return ResponseEntity.ok(new UrgencyThresholdResponse(config.urgency().thresholdDays()));
}
```

Vérifier que `/config/urgency-threshold` est bien public dans `SecurityConfig` (le préfixe `/config/**` doit déjà être permitAll comme `/config/commission-rate` ; sinon l'ajouter).

- [ ] **Step 7: Lancer le test — doit passer**

Run: `./mvnw test -Dtest=ConfigControllerIT`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/main/java/com/dony/api/config/ src/main/resources/application.yml src/test/java/com/dony/api/config/ConfigControllerIT.java
git commit -m "feat(config): seuil d'urgence configurable + GET /config/urgency-threshold"
```

---

### Task 2: Filtre `urgent` + champ DTO — recherche trajets

**Files:**
- Modify: `src/main/java/com/dony/api/matching/AnnouncementController.java:43-72`
- Modify: `src/main/java/com/dony/api/matching/AnnouncementService.java:131-242`
- Modify: `src/main/java/com/dony/api/matching/dto/AnnouncementSearchResponse.java:11-41`
- Modify: `src/main/java/com/dony/api/matching/AnnouncementSearchMapper.java`
- Modify: `src/test/java/com/dony/api/matching/AnnouncementServiceTest.java`
- Modify: `src/test/java/com/dony/api/matching/AnnouncementControllerIntegrationTest.java`

**Interfaces:**
- Consumes: `config.urgency().thresholdDays()` (Task 1).
- Produces: `GET /announcements?urgent=true` restreint à `departureDate ∈ [today, today+seuil]` ; `AnnouncementSearchResponse.urgent()` → `boolean`.

- [ ] **Step 1: Ajouter le champ `urgent` au DTO**

Dans `AnnouncementSearchResponse.java`, ajouter `boolean urgent` en dernier champ du record (après `isFavorite`) :

```java
        LocalDateTime handoverWindowEnd,
        boolean isFavorite,
        boolean urgent
) {}
```

- [ ] **Step 2: Calculer `urgent` dans le mapper**

Dans `AnnouncementSearchMapper.java` (`@Component`), injecter `DonyConfigProperties` par le constructeur (ajouter le champ + param), puis calculer `urgent` là où le record est construit (méthodes batch ~79-104 et simple ~132-156) :

```java
private final DonyConfigProperties config;

// constructeur : ajouter DonyConfigProperties config en param + this.config = config;

private boolean computeUrgent(java.time.LocalDate departureDate) {
    if (departureDate == null) return false;
    java.time.LocalDate today = java.time.LocalDate.now(java.time.ZoneOffset.UTC);
    int threshold = config.urgency().thresholdDays();
    return !departureDate.isBefore(today)
            && !departureDate.isAfter(today.plusDays(threshold));
}
```

Passer `computeUrgent(entity.getDepartureDate())` comme dernier argument du constructeur `new AnnouncementSearchResponse(...)` aux deux endroits.

- [ ] **Step 3: Ajouter le param `urgent` au controller**

Dans `AnnouncementController.java`, ajouter au `searchAnnouncements(...)` :

```java
@RequestParam(required = false) Boolean urgent,
```

et le passer à l'appel service `announcementService.searchAnnouncements(...)` (ajouter l'argument `urgent` à la signature service).

- [ ] **Step 4: Écrire le test service (échoue d'abord)**

Dans `AnnouncementServiceTest.java` :

```java
@Test
void searchAnnouncements_urgentTrue_restrictsToNextThresholdDays() {
    // Arrange : mock repo pour capturer la Specification / vérifier les bornes de date.
    // Le service doit forcer departureDate BETWEEN today AND today+3 quand urgent==true.
    LocalDate today = LocalDate.now(ZoneOffset.UTC);
    // ... appel service avec urgent=true ...
    // Assert : la spec appliquée borne departureDateFrom=today et departureDateTo=today+3.
    // (adapter à la façon dont AnnouncementServiceTest vérifie déjà les specs de date)
}
```

Note implémenteur : calquer sur un test existant de `AnnouncementServiceTest` qui vérifie déjà le filtrage par `departureDateFrom/To` (chercher `departureDateFrom` dans le fichier) ; réutiliser le même mécanisme d'assertion.

- [ ] **Step 5: Lancer — doit échouer**

Run: `./mvnw test -Dtest=AnnouncementServiceTest#searchAnnouncements_urgentTrue_restrictsToNextThresholdDays`
Expected: FAIL (param urgent inconnu / non appliqué).

- [ ] **Step 6: Implémenter la logique urgent dans le service**

Dans `AnnouncementService.searchAnnouncements(...)`, ajouter le param `Boolean urgent` à la signature et, avant l'application des specs de date (vers ligne 161) :

```java
LocalDate effectiveFrom = departureDateFrom;
LocalDate effectiveTo = departureDateTo;
if (Boolean.TRUE.equals(urgent)) {
    LocalDate today = LocalDate.now(ZoneOffset.UTC);
    LocalDate urgentTo = today.plusDays(config.urgency().thresholdDays());
    // Intersection avec un éventuel filtre de date déjà fourni.
    effectiveFrom = (effectiveFrom == null || effectiveFrom.isBefore(today)) ? today : effectiveFrom;
    effectiveTo = (effectiveTo == null || effectiveTo.isAfter(urgentTo)) ? urgentTo : effectiveTo;
}
```

puis utiliser `effectiveFrom`/`effectiveTo` dans les specs `departureDateFrom`/`departureDateTo` (lignes 162-164). Injecter `DonyConfigProperties config` dans le service s'il ne l'a pas déjà.

- [ ] **Step 7: Test controller IT (échoue puis passe)**

Dans `AnnouncementControllerIntegrationTest.java` :

```java
@Test
void search_urgentTrue_returnsOnlyImminentDepartures() throws Exception {
    // Seed : une annonce departureDate = today+1 (urgente), une departureDate = today+10 (non urgente).
    mockMvc.perform(get("/announcements").param("urgent", "true")
                    .header("Authorization", "Bearer fake-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content[*].urgent", everyItem(is(true))));
}
```

Run: `./mvnw test -Dtest=AnnouncementControllerIntegrationTest#search_urgentTrue_returnsOnlyImminentDepartures`
Expected: d'abord FAIL, puis PASS après Steps 1-6.

- [ ] **Step 8: Vérifier toute la suite**

Run: `./mvnw test -Dtest=AnnouncementServiceTest,AnnouncementControllerIntegrationTest`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/main/java/com/dony/api/matching/ src/test/java/com/dony/api/matching/
git commit -m "feat(matching): filtre urgent + champ urgent sur la recherche de trajets"
```

---

### Task 3: Filtre `urgent` + champ DTO — recherche demandes

**Files:**
- Modify: `src/main/java/com/dony/api/requests/controller/PackageRequestController.java:104-132`
- Modify: `src/main/java/com/dony/api/requests/service/PackageRequestSpecifications.java:28-35`
- Modify: `src/main/java/com/dony/api/requests/service/PackageRequestService.java`
- Modify: `src/main/java/com/dony/api/requests/dto/PackageRequestSearchResponse.java:12-31`
- Modify: `src/main/java/com/dony/api/requests/service/PackageRequestSearchMapper.java`
- Modify: `src/test/java/com/dony/api/requests/controller/PackageRequestControllerIT.java`

**Interfaces:**
- Consumes: `config.urgency().thresholdDays()` (Task 1).
- Produces: `GET /package-requests?urgent=true` restreint à `desiredDate ∈ [today, today+seuil]` ; `PackageRequestSearchResponse.urgent()` → `boolean`.

- [ ] **Step 1: Ajouter une Specification urgent**

Dans `PackageRequestSpecifications.java`, ajouter :

```java
public static Specification<PackageRequestEntity> urgent(int thresholdDays) {
    return (root, query, cb) -> {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        return cb.between(root.get("desiredDate"), today, today.plusDays(thresholdDays));
    };
}
```

- [ ] **Step 2: Ajouter le champ `urgent` au DTO**

Dans `PackageRequestSearchResponse.java`, ajouter `boolean urgent` en dernier champ du record.

- [ ] **Step 3: Calculer `urgent` dans le mapper**

Dans `PackageRequestSearchMapper.java` (`@Component`), injecter `DonyConfigProperties config`, ajouter :

```java
private boolean computeUrgent(java.time.LocalDate desiredDate) {
    if (desiredDate == null) return false;
    java.time.LocalDate today = java.time.LocalDate.now(java.time.ZoneOffset.UTC);
    int threshold = config.urgency().thresholdDays();
    return !desiredDate.isBefore(today) && !desiredDate.isAfter(today.plusDays(threshold));
}
```

et passer `computeUrgent(entity.getDesiredDate())` en dernier argument dans les deux `toSearchResponse(...)` (méthodes ~57 et ~101).

- [ ] **Step 4: Ajouter le param urgent au controller + spec**

Dans `PackageRequestController.search(...)`, ajouter `@RequestParam(required = false) Boolean urgent` et, dans la construction de la Specification (lignes 119-124), après `.and(dateRange(...))` :

```java
if (Boolean.TRUE.equals(urgent)) {
    spec = spec.and(PackageRequestSpecifications.urgent(config.urgency().thresholdDays()));
}
```

Injecter `DonyConfigProperties config` dans le controller (ou le passer au service). Si le seuil est appliqué côté service, déplacer la logique dans `PackageRequestService.search`.

- [ ] **Step 5: Test IT (échoue puis passe)**

Dans `PackageRequestControllerIT.java` :

```java
@Test
void search_urgentTrue_returnsOnlyImminentRequests() throws Exception {
    // Seed : une demande desiredDate = today+2 (urgente), une desiredDate = today+9 (non urgente).
    mockMvc.perform(get("/package-requests").param("urgent", "true")
                    .header("Authorization", "Bearer fake-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content[*].urgent", everyItem(is(true))));
}
```

Run: `./mvnw test -Dtest=PackageRequestControllerIT#search_urgentTrue_returnsOnlyImminentRequests`
Expected: FAIL puis PASS.

- [ ] **Step 6: Vérifier + commit**

Run: `./mvnw test -Dtest=PackageRequestControllerIT`
Expected: PASS.

```bash
git add src/main/java/com/dony/api/requests/ src/test/java/com/dony/api/requests/
git commit -m "feat(requests): filtre urgent + champ urgent sur la recherche de demandes"
```

---

### Task 4: Vérification globale + push + PR

- [ ] **Step 1: Suite complète**

Run: `./mvnw test`
Expected: BUILD SUCCESS (0 échec).

- [ ] **Step 2: Push + PR draft**

```bash
git push -u origin feature/urgent-announcements
gh pr create --draft --title "feat: filtre urgent (trajets + demandes)" --body "Seuil dony.urgency.threshold-days (défaut 3). Param urgent=true sur /announcements et /package-requests. Champ urgent dans les DTO. Aucune migration."
```

## Self-review effectué

- Couverture spec §3.1–3.5 : Task 1 (config+endpoint), Task 2 (annonces filtre+DTO), Task 3 (demandes filtre+DTO). ✓
- Bornes exactes (today..today+3) : identiques dans service, specs et mappers. ✓
- Pas de migration : confirmé (dérivé). ✓
