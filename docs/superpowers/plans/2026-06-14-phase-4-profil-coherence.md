# Phase 4 — Profil cohérent & additif · Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre le profil propre et additif (expéditeur lean → voyageur ajoute champs/sections), avec édition en écran plein, upload photo, avis enrichis, onglets réorganisés — **sans aucune régression**.

**Architecture:** Backend Spring Boot (migration V139 + 4 champs user + endpoint avatar + enrichissement avis/profil public) ; front Flutter (modèles data, écran d'édition, profil public, réorg onglets, flows). Modèle **additif** piloté par `UserModel.isTraveler`/`isSender` — `ActiveRoleCubit` inchangé.

**Tech Stack:** Spring Boot 3.4 / Java 21 / JPA / Flyway / Hetzner S3 (StorageService) · Flutter / flutter_bloc / GoRouter / Dio / image_picker / flutter_animate · spec : `docs/superpowers/specs/2026-06-14-phase-4-profil-coherence-design.md`.

**Branche :** `feature/phase-4-profil` (déjà active).

---

## ⚠️ Inventaire anti-régression (à préserver intégralement)

Toute réorganisation d'onglet DOIT conserver ces actions au tap. Référence : `lib/features/profile/presentation/profile_screen.dart`.

**Onglet Activité :**
| Tuile | Action |
|---|---|
| Mes envois en cours | `context.push('/announcements')` + trailing `$activeBids en cours` |
| Mes négociations *(si activeBids>0)* | `context.push('/negotiations')` |
| Mes destinataires | `context.push('/profile/recipients')` |
| Mes abonnements | `context.push('/profile/subscriptions')` |
| Mes litiges | `context.push('/disputes')` |
| Mes trajets *(voyageur)* | `context.push('/announcements')` + trailing `à venir` |
| Colis sur mes trajets *(voyageur)* | `context.push('/package-requests/match')` + trailing `matchs` |
| Mes modèles de trajet *(voyageur)* | `context.push('/trip-templates')` |
| **Mes adresses** *(voyageur → à déplacer)* | `context.push('/profile/addresses')` |
| Bannière complétion profil | → ouvrira `/profile/edit` (était `EditProfileBottomSheet.show`) |
| Bannière suppression compte | `ReactivateAccount()` |

**Onglet Compte :**
| Tuile | Action |
|---|---|
| Téléphone | `AddPhoneSheet.show(context)` |
| Email | `AddEmailSheet.show(context)` |
| KYC | `_kycTile(context, user)` (inchangé) |
| Mon profil public | `context.push('/profile/public')` |
| Mes avis reçus | `context.push('/profile/reviews')` |
| Moyens de paiement | ComingSoon → **MASQUER** |
| Factures | ComingSoon → **MASQUER** |
| Crédits & codes promo | ComingSoon → **MASQUER** |
| Parrainages | `context.push('/profile/referral')` + trailing `0 invité` |
| J'ai un code parrain *(si !alreadyReferred)* | `RedeemCodeBottomSheet.show` + reload ReferralBloc |
| Recevoir mes paiements *(voyageur)* | `context.push('/payments/onboarding')` |
| Carte commission cash *(voyageur)* | `context.push('/payments/commission-method')` |
| Ma grille de prix *(voyageur)* | `context.push('/profile/price-grid')` + subtitle |
| Paiements & factures voyage *(voyageur)* | ComingSoon → **MASQUER** |
| Compte PRO *(voyageur)* | `UpgradeProBottomSheet.show` → **remplacer** par `context.push('/profile/upgrade-to-pro')` |
| Devenir voyageur dony *(non-voyageur)* | `context.push('/profile/become-traveler')` + trailing statut → **carte CTA** |
| Mon portefeuille | `context.push('/payments/wallet')` + subtitle |
| Bouton édition header (ligne 234) | `EditProfileBottomSheet.show` → **remplacer** par `/profile/edit` |

**Règle :** après chaque réorg, lancer `flutter analyze` (0 erreur) + `flutter test` (tout vert) avant commit. Aucune route ni event ci-dessus ne doit disparaître sauf les 4 ComingSoon explicitement masqués.

---

# PARTIE A — BACKEND (`dony-back/`)

### Task A1 : Migration V139 + enum TransportMode

**Files:**
- Create: `dony-back/src/main/resources/db/migration/V139__profile_fields.sql`
- Create: `dony-back/src/main/java/com/dony/api/auth/TransportMode.java`

- [ ] **Step 1 : Écrire la migration**

```sql
-- V139__profile_fields.sql
ALTER TABLE users ADD COLUMN bio varchar(280);
ALTER TABLE users ADD COLUMN avatar_url varchar(512);
ALTER TABLE users ADD COLUMN transport_mode varchar(16);

CREATE TABLE user_languages (
    user_id  uuid NOT NULL REFERENCES users(id),
    language varchar(32) NOT NULL,
    PRIMARY KEY (user_id, language)
);
```

- [ ] **Step 2 : Créer l'enum**

```java
package com.dony.api.auth;

public enum TransportMode {
    AVION, VOITURE, TRAIN
}
```

- [ ] **Step 3 : Démarrer l'app pour valider Flyway**

Run: `cd dony-back && ./mvnw -q spring-boot:run -Dspring.profiles.active=dev` (puis Ctrl-C une fois « Started » + Flyway `V139` appliqué).
Expected: log `Migrating schema "public" to version "139 - profile fields"`.

- [ ] **Step 4 : Commit**

```bash
git add dony-back/src/main/resources/db/migration/V139__profile_fields.sql dony-back/src/main/java/com/dony/api/auth/TransportMode.java
git commit -m "feat(profil): migration V139 champs profil + enum TransportMode"
```

---

### Task A2 : Champs UserEntity

**Files:**
- Modify: `dony-back/src/main/java/com/dony/api/auth/UserEntity.java`

- [ ] **Step 1 : Ajouter les champs** (à côté de `proCompanyName`)

```java
@Column(name = "bio", length = 280)
private String bio;

@Column(name = "avatar_url", length = 512)
private String avatarUrl;

@Enumerated(EnumType.STRING)
@Column(name = "transport_mode", length = 16)
private TransportMode transportMode;

@ElementCollection(fetch = FetchType.EAGER)
@CollectionTable(name = "user_languages", joinColumns = @JoinColumn(name = "user_id"))
@Column(name = "language", length = 32)
private Set<String> languages = new HashSet<>();
```

- [ ] **Step 2 : Getters/setters** (suivre le style existant)

```java
public String getBio() { return bio; }
public void setBio(String bio) { this.bio = bio; }
public String getAvatarUrl() { return avatarUrl; }
public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }
public TransportMode getTransportMode() { return transportMode; }
public void setTransportMode(TransportMode transportMode) { this.transportMode = transportMode; }
public Set<String> getLanguages() { return languages; }
public void setLanguages(Set<String> languages) { this.languages = languages; }
```

- [ ] **Step 3 : Compiler**

Run: `cd dony-back && ./mvnw -q -DskipTests compile`
Expected: BUILD SUCCESS.

- [ ] **Step 4 : Commit**

```bash
git add dony-back/src/main/java/com/dony/api/auth/UserEntity.java
git commit -m "feat(profil): champs bio/avatarUrl/transportMode/languages sur UserEntity"
```

---

### Task A3 : UpdateProfileRequest + UserResponse + mapping

**Files:**
- Modify: `dony-back/src/main/java/com/dony/api/auth/dto/UpdateProfileRequest.java`
- Modify: `dony-back/src/main/java/com/dony/api/auth/dto/UserResponse.java`
- Modify: `dony-back/src/main/java/com/dony/api/auth/AuthService.java` (updateProfile ~117-168, toResponse ~462-480)
- Test: `dony-back/src/test/java/com/dony/api/auth/AuthServiceTest.java`

- [ ] **Step 1 : Test d'échec — mise à jour bio/langues/transport**

```java
@Test
void updateProfile_persistsBioLanguagesTransport() {
    UserEntity user = baseUser(); // helper existant ou minimal
    when(userRepository.findByFirebaseUid("uid")).thenReturn(Optional.of(user));
    when(userRepository.save(any())).thenAnswer(i -> i.getArgument(0));

    var req = new UpdateProfileRequest(null, null, null, null, null, null,
            "Voyageur sérieux", Set.of("FR", "WO"), "AVION");

    UserResponse res = authService.updateProfile("uid", req);

    assertThat(res.bio()).isEqualTo("Voyageur sérieux");
    assertThat(res.languages()).containsExactlyInAnyOrder("FR", "WO");
    assertThat(res.transportMode()).isEqualTo("AVION");
}
```

- [ ] **Step 2 : Lancer → échec compilation (champs absents)**

Run: `cd dony-back && ./mvnw -q -Dtest=AuthServiceTest#updateProfile_persistsBioLanguagesTransport test`
Expected: échec compilation (constructeur UpdateProfileRequest, méthodes res.bio()…).

- [ ] **Step 3 : Étendre les DTOs**

`UpdateProfileRequest` :
```java
public record UpdateProfileRequest(
    @Size(max = 100) String firstName,
    @Size(max = 100) String lastName,
    @Email @Size(max = 255) String email,
    @Past LocalDate birthDate,
    @Size(max = 100) String city,
    @Pattern(regexp = "^\\+[1-9]\\d{1,14}$", message = "Format E.164 requis (ex: +33612345678)")
    String phoneNumber,
    @Size(max = 280) String bio,
    Set<String> languages,
    @Pattern(regexp = "AVION|VOITURE|TRAIN", message = "Mode de transport invalide")
    String transportMode
) {}
```

`UserResponse` : ajouter `String bio, Set<String> languages, String transportMode` à la fin du record.

- [ ] **Step 4 : Mapping `updateProfile`** (après le bloc phoneNumber, avant `save`)

```java
if (request.bio() != null) {
    String v = request.bio().trim();
    user.setBio(v.isEmpty() ? null : v);
}
if (request.languages() != null) {
    user.setLanguages(new HashSet<>(request.languages()));
}
if (request.transportMode() != null) {
    String v = request.transportMode().trim();
    user.setTransportMode(v.isEmpty() ? null : TransportMode.valueOf(v));
}
```

- [ ] **Step 5 : Mapping `toResponse`** (ajouter les 3 args)

```java
user.getBio(),
user.getLanguages(),
user.getTransportMode() != null ? user.getTransportMode().name() : null
```

- [ ] **Step 6 : Lancer le test → succès**

Run: `cd dony-back && ./mvnw -q -Dtest=AuthServiceTest test`
Expected: PASS.

- [ ] **Step 7 : Commit**

```bash
git add dony-back/src/main/java/com/dony/api/auth/dto/UpdateProfileRequest.java dony-back/src/main/java/com/dony/api/auth/dto/UserResponse.java dony-back/src/main/java/com/dony/api/auth/AuthService.java dony-back/src/test/java/com/dony/api/auth/AuthServiceTest.java
git commit -m "feat(profil): PATCH /auth/me étendu (bio/langues/transport)"
```

---

### Task A4 : Endpoint upload avatar (URL publique)

**Files:**
- Modify: `dony-back/src/main/java/com/dony/api/common/StorageService.java` (ajout `publicUrl`)
- Modify: `dony-back/src/main/java/com/dony/api/auth/AuthService.java` (méthode `updateAvatar`)
- Modify: `dony-back/src/main/java/com/dony/api/auth/AuthController.java` (`POST /me/avatar`)
- Test: `dony-back/src/test/java/com/dony/api/auth/AuthServiceTest.java`

> **Décision** : l'avatar est **public**. On stocke l'URL publique directement dans `avatar_url`. Prérequis déploiement : le préfixe `users/` du bucket doit être lisible publiquement (objets uploadés avec ACL public-read). On réutilise le préfixe `users/{uid}/` (déjà autorisé dans `StorageService`).

- [ ] **Step 1 : `StorageService.publicUrl`** (construit une URL stable)

```java
@Value("${storage.public-base-url}")
private String publicBaseUrl; // ex: https://<bucket>.<endpoint>

/** URL publique stable d'un objet (préfixe public-read uniquement, jamais KYC). */
public String publicUrl(String objectKey) {
    return publicBaseUrl.replaceAll("/+$", "") + "/" + objectKey;
}
```

Ajouter `storage.public-base-url` dans `application-dev.yml` / `application.yml`.

- [ ] **Step 2 : Test d'échec — updateAvatar persiste l'URL**

```java
@Test
void updateAvatar_uploadsAndPersistsPublicUrl() throws Exception {
    UserEntity user = baseUser();
    when(userRepository.findByFirebaseUid("uid")).thenReturn(Optional.of(user));
    when(userRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    MultipartFile file = new MockMultipartFile("file", "a.jpg", "image/jpeg", new byte[]{1,2,3});
    when(storageService.uploadFile(eq(file), startsWith("users/uid/"))).thenReturn("users/uid/123_a.jpg");
    when(storageService.publicUrl("users/uid/123_a.jpg")).thenReturn("https://cdn/x/users/uid/123_a.jpg");

    UserResponse res = authService.updateAvatar("uid", file);

    assertThat(res.avatarUrl()).isEqualTo("https://cdn/x/users/uid/123_a.jpg");
}
```

- [ ] **Step 3 : Lancer → échec (méthode absente)**

Run: `cd dony-back && ./mvnw -q -Dtest=AuthServiceTest#updateAvatar_uploadsAndPersistsPublicUrl test`
Expected: échec compilation.

- [ ] **Step 4 : `AuthService.updateAvatar`**

```java
@Transactional
public UserResponse updateAvatar(String firebaseUid, MultipartFile file) throws IOException {
    UserEntity user = userRepository.findByFirebaseUid(firebaseUid)
            .orElseThrow(() -> new DonyBusinessException(HttpStatus.NOT_FOUND, "Utilisateur introuvable"));
    if (file == null || file.isEmpty()) {
        throw new DonyBusinessException(HttpStatus.BAD_REQUEST, "Fichier manquant");
    }
    if (file.getSize() > 10L * 1024 * 1024) {
        throw new DonyBusinessException(HttpStatus.PAYLOAD_TOO_LARGE, "Image trop volumineuse (max 10 Mo)");
    }
    String key = storageService.uploadFile(file, "users/" + firebaseUid + "/");
    user.setAvatarUrl(storageService.publicUrl(key));
    return toResponse(userRepository.save(user));
}
```

- [ ] **Step 5 : Endpoint controller**

```java
@PostMapping(value = "/me/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<UserResponse> uploadAvatar(@RequestParam("file") MultipartFile file) throws IOException {
    String firebaseUid = requireFirebaseUid();
    return ResponseEntity.ok(authService.updateAvatar(firebaseUid, file));
}
```

- [ ] **Step 6 : Test → succès + compile**

Run: `cd dony-back && ./mvnw -q -Dtest=AuthServiceTest test`
Expected: PASS.

- [ ] **Step 7 : Commit**

```bash
git add dony-back/src/main/java/com/dony/api/common/StorageService.java dony-back/src/main/java/com/dony/api/auth/AuthService.java dony-back/src/main/java/com/dony/api/auth/AuthController.java dony-back/src/main/resources/application*.yml dony-back/src/test/java/com/dony/api/auth/AuthServiceTest.java
git commit -m "feat(profil): POST /auth/me/avatar upload photo (URL publique)"
```

---

### Task A5 : Profil public enrichi

**Files:**
- Modify: `dony-back/src/main/java/com/dony/api/auth/dto/ProfilePublicResponse.java`
- Modify: `dony-back/src/main/java/com/dony/api/auth/ProfilePublicService.java` (~34-65)
- Test: `dony-back/src/test/java/com/dony/api/auth/ProfilePublicServiceTest.java` (créer si absent)

- [ ] **Step 1 : Étendre `ProfilePublicResponse`** (ajouter en fin de record)

```java
String bio,
List<String> languages,
String transportMode
```

- [ ] **Step 2 : Test d'échec — service expose les nouveaux champs**

```java
@Test
void getProfilePublic_includesBioLanguagesTransportAvatar() {
    UserEntity u = baseUser();
    u.setBio("Hello"); u.setAvatarUrl("https://cdn/a.jpg");
    u.setLanguages(Set.of("FR")); u.setTransportMode(TransportMode.AVION);
    when(userRepository.findById(u.getId())).thenReturn(Optional.of(u));
    when(ratingService.getUserRatings(u.getId(), 0, 3))
        .thenReturn(new UserRatingsSummaryResponse(BigDecimal.ZERO, 0, Map.of(), List.of(), 0, 0));

    ProfilePublicResponse r = profilePublicService.getProfilePublic(u.getId());

    assertThat(r.bio()).isEqualTo("Hello");
    assertThat(r.avatarUrl()).isEqualTo("https://cdn/a.jpg");
    assertThat(r.languages()).containsExactly("FR");
    assertThat(r.transportMode()).isEqualTo("AVION");
}
```

- [ ] **Step 3 : Lancer → échec**

Run: `cd dony-back && ./mvnw -q -Dtest=ProfilePublicServiceTest test`
Expected: échec compilation.

- [ ] **Step 4 : Mapping service** (remplacer `null` avatar + ajouter champs)

```java
user.getAvatarUrl(),        // remplace le null actuel
// ... champs existants ...
user.getBio(),
new ArrayList<>(user.getLanguages()),
user.getTransportMode() != null ? user.getTransportMode().name() : null
```

- [ ] **Step 5 : Test → succès**

Run: `cd dony-back && ./mvnw -q -Dtest=ProfilePublicServiceTest test`
Expected: PASS.

- [ ] **Step 6 : Commit**

```bash
git add dony-back/src/main/java/com/dony/api/auth/dto/ProfilePublicResponse.java dony-back/src/main/java/com/dony/api/auth/ProfilePublicService.java dony-back/src/test/java/com/dony/api/auth/ProfilePublicServiceTest.java
git commit -m "feat(profil): profil public expose avatar/bio/langues/transport"
```

---

### Task A6 : Avis enrichis (auteur + corridor)

**Files:**
- Modify: `dony-back/src/main/java/com/dony/api/ratings/dto/RatingItemResponse.java`
- Modify: `dony-back/src/main/java/com/dony/api/ratings/RatingService.java` (getUserRatings ~251-280)
- Test: `dony-back/src/test/java/com/dony/api/ratings/RatingServiceTest.java`

- [ ] **Step 1 : Étendre `RatingItemResponse`**

```java
public record RatingItemResponse(
        int stars,
        String comment,
        LocalDateTime createdAt,
        boolean excluded,
        String authorName,        // prénom + initiale, null si anonyme (recipient)
        String authorAvatarUrl,
        String departureCity,
        String arrivalCity
) {}
```

- [ ] **Step 2 : Test d'échec — mapping auteur + corridor**

```java
@Test
void getUserRatings_enrichesAuthorAndCorridor() {
    UUID rated = UUID.randomUUID(), rater = UUID.randomUUID(), bidId = UUID.randomUUID(), annId = UUID.randomUUID();
    RatingEntity rating = ratingWith(rated, rater, bidId, 5, "super");
    UserEntity raterUser = userNamed(rater, "Fatou", "Mbaye"); raterUser.setAvatarUrl("https://cdn/f.jpg");
    BidEntity bid = bidWith(bidId, annId);
    AnnouncementEntity ann = announcementWith(annId, "Paris", "Dakar");
    // stubs repos: findByRatedUserId page, findIncluded..., userRepository.findById(rater), bidRepository.findById(bidId), announcementRepository.findById(annId), userRepository.findById(rated)
    stubGetUserRatings(rated, List.of(rating), raterUser, bid, ann);

    var res = ratingService.getUserRatings(rated, 0, 20);
    var item = res.ratings().get(0);

    assertThat(item.authorName()).isEqualTo("Fatou M.");
    assertThat(item.authorAvatarUrl()).isEqualTo("https://cdn/f.jpg");
    assertThat(item.departureCity()).isEqualTo("Paris");
    assertThat(item.arrivalCity()).isEqualTo("Dakar");
}
```

- [ ] **Step 3 : Lancer → échec**

Run: `cd dony-back && ./mvnw -q -Dtest=RatingServiceTest#getUserRatings_enrichesAuthorAndCorridor test`
Expected: échec compilation.

- [ ] **Step 4 : Helper nom auteur** (réutiliser `buildDisplayName` si pertinent, sinon)

```java
/** « Prénom + initiale » sans PII complète. null si auteur inconnu. */
private String authorShortName(UserEntity author) {
    if (author == null) return null;
    String fn = author.getFirstName();
    String ln = author.getLastName();
    if (fn == null || fn.isBlank()) return null;
    String initial = (ln != null && !ln.isBlank()) ? " " + ln.trim().charAt(0) + "." : "";
    return fn.trim() + initial;
}
```

- [ ] **Step 5 : Enrichir le mapping** (dans `getUserRatings`, remplacer le `.map(...)`)

```java
List<RatingItemResponse> items = ratingsPage.getContent().stream().map(r -> {
    UserEntity author = r.getRaterId() != null
            ? userRepository.findById(r.getRaterId()).orElse(null) : null;
    String dep = null, arr = null;
    BidEntity bid = bidRepository.findById(r.getBidId()).orElse(null);
    if (bid != null) {
        AnnouncementEntity ann = announcementRepository.findById(bid.getAnnouncementId()).orElse(null);
        if (ann != null) { dep = ann.getDepartureCity(); arr = ann.getArrivalCity(); }
    }
    return new RatingItemResponse(
            r.getStars(), r.getComment(), r.getCreatedAt(), r.isExcludedFromAverage(),
            authorShortName(author),
            author != null ? author.getAvatarUrl() : null,
            dep, arr);
}).collect(Collectors.toList());
```

> Injecter `bidRepository` + `announcementRepository` dans `RatingService` s'ils n'y sont pas déjà (vérifier le constructeur ; `getPendingRating` les utilise déjà → probablement présents). Vérifier les noms exacts des getters `getDepartureCity`/`getArrivalCity`/`getAnnouncementId` sur `AnnouncementEntity`/`BidEntity` (les corriger si différents).

- [ ] **Step 6 : Test → succès + suite ratings**

Run: `cd dony-back && ./mvnw -q -Dtest=RatingServiceTest test`
Expected: PASS.

- [ ] **Step 7 : Commit**

```bash
git add dony-back/src/main/java/com/dony/api/ratings/dto/RatingItemResponse.java dony-back/src/main/java/com/dony/api/ratings/RatingService.java dony-back/src/test/java/com/dony/api/ratings/RatingServiceTest.java
git commit -m "feat(profil): avis enrichis auteur (prénom+initiale) + corridor"
```

- [ ] **Step 8 : Suite back complète + couverture**

Run: `cd dony-back && ./mvnw test jacoco:report`
Expected: tout vert, couverture ≥ 90 %.

---

# PARTIE B — FRONT DATA (`dony_app/`)

### Task B1 : UserModel — nouveaux champs

**Files:**
- Modify: `lib/features/auth/data/models/user_model.dart`
- Test: `test/features/auth/data/models/user_model_test.dart`

- [ ] **Step 1 : Test d'échec — fromJson/toJson**

```dart
test('UserModel parse bio/avatarUrl/languages/transportMode', () {
  final u = UserModel.fromJson({
    'id': 'u1', 'roles': ['SENDER'],
    'bio': 'Hello', 'avatarUrl': 'https://cdn/a.jpg',
    'languages': ['FR', 'WO'], 'transportMode': 'AVION',
  });
  expect(u.bio, 'Hello');
  expect(u.avatarUrl, 'https://cdn/a.jpg');
  expect(u.languages, ['FR', 'WO']);
  expect(u.transportMode, 'AVION');
  expect(u.toJson()['bio'], 'Hello');
});
```

- [ ] **Step 2 : Lancer → échec**

Run: `flutter test test/features/auth/data/models/user_model_test.dart`
Expected: FAIL (getters absents).

- [ ] **Step 3 : Ajouter champs + fromJson + toJson + copyWith**

```dart
final String? bio;
final String? avatarUrl;
final List<String> languages;
final String? transportMode;
```
fromJson :
```dart
bio: json['bio'] as String?,
avatarUrl: json['avatarUrl'] as String?,
languages: (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
transportMode: json['transportMode'] as String?,
```
toJson : ajouter `'bio'`, `'avatarUrl'`, `'languages'`, `'transportMode'`. Mettre à jour le constructeur (`this.languages = const []`) et `copyWith` (+ `props` si Equatable).

- [ ] **Step 4 : Test → succès**

Run: `flutter test test/features/auth/data/models/user_model_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/data/models/user_model.dart test/features/auth/data/models/user_model_test.dart
git commit -m "feat(profil): UserModel bio/avatarUrl/languages/transportMode"
```

---

### Task B2 : AuthRepository + AuthBloc (update étendu + upload avatar)

**Files:**
- Modify: `lib/features/auth/data/repositories/auth_repository.dart` (updateProfile + uploadAvatar)
- Modify: `lib/features/auth/bloc/auth_event.dart` (AuthUpdateProfileRequested + AuthAvatarUploadRequested)
- Modify: `lib/features/auth/bloc/auth_bloc.dart` (handlers)
- Test: `test/features/auth/bloc/auth_bloc_test.dart`

- [ ] **Step 1 : Test d'échec — update avec bio/langues/transport**

```dart
blocTest<AuthBloc, AuthState>(
  'emits AuthProfileUpdated with bio/languages/transport',
  build: () {
    when(() => repo.updateProfile(
      bio: any(named: 'bio'),
      languages: any(named: 'languages'),
      transportMode: any(named: 'transportMode'),
      firstName: any(named: 'firstName'), lastName: any(named: 'lastName'),
      email: any(named: 'email'), birthDate: any(named: 'birthDate'),
      city: any(named: 'city'), phoneNumber: any(named: 'phoneNumber'),
    )).thenAnswer((_) async => userWith(bio: 'X'));
    return bloc;
  },
  act: (b) => b.add(const AuthUpdateProfileRequested(bio: 'X', languages: ['FR'], transportMode: 'AVION')),
  expect: () => [isA<AuthLoading>(), isA<AuthProfileUpdated>()],
);
```

- [ ] **Step 2 : Lancer → échec**

Run: `flutter test test/features/auth/bloc/auth_bloc_test.dart`
Expected: FAIL (params nommés absents).

- [ ] **Step 3 : Étendre `AuthUpdateProfileRequested`** (ajouter `bio`, `languages`, `transportMode` aux champs, constructeur, props).

- [ ] **Step 4 : Nouvel event**

```dart
class AuthAvatarUploadRequested extends AuthEvent {
  final String filePath;
  const AuthAvatarUploadRequested(this.filePath);
  @override
  List<Object?> get props => [filePath];
}
```

- [ ] **Step 5 : Repository — updateProfile étendu + uploadAvatar**

```dart
Future<UserModel> updateProfile({
  String? firstName, String? lastName, String? email,
  DateTime? birthDate, String? city, String? phoneNumber,
  String? bio, List<String>? languages, String? transportMode,
}) async {
  final res = await _apiClient.dio.patch('/auth/me', data: {
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (email != null) 'email': email,
    if (birthDate != null) 'birthDate': birthDate.toIso8601String().split('T').first,
    if (city != null) 'city': city,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (bio != null) 'bio': bio,
    if (languages != null) 'languages': languages,
    if (transportMode != null) 'transportMode': transportMode,
  });
  return UserModel.fromJson(res.data as Map<String, dynamic>);
}

Future<UserModel> uploadAvatar(String filePath) async {
  final form = FormData.fromMap({
    'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
  });
  final res = await _apiClient.dio.post('/auth/me/avatar', data: form);
  return UserModel.fromJson(res.data as Map<String, dynamic>);
}
```

- [ ] **Step 6 : Handlers AuthBloc** — passer les 3 params dans `_onUpdateProfileRequested` ; nouveau handler :

```dart
on<AuthAvatarUploadRequested>(_onAvatarUploadRequested);
// ...
Future<void> _onAvatarUploadRequested(
  AuthAvatarUploadRequested event, Emitter<AuthState> emit) async {
  emit(const AuthLoading());
  try {
    final updated = await _authRepository.uploadAvatar(event.filePath);
    unawaited(_analytics.logEvent(AnalyticsEvents.profilePhotoUpdated));
    emit(AuthProfileUpdated(updated));
  } catch (e) {
    emit(AuthError(_friendlyError(e)));
  }
}
```
*(Si `AuthBloc` n'a pas encore `_analytics`, ne pas l'ajouter ici — voir Task G1.)*

- [ ] **Step 7 : Tests → succès**

Run: `flutter test test/features/auth/bloc/auth_bloc_test.dart`
Expected: PASS.

- [ ] **Step 8 : Commit**

```bash
git add lib/features/auth/
git commit -m "feat(profil): AuthRepository/Bloc update étendu + upload avatar"
```

---

### Task B3 : RatingItem enrichi

**Files:**
- Modify: `lib/features/ratings/data/models/rating_summary.dart`
- Test: `test/features/ratings/data/models/rating_summary_test.dart` (créer si absent)

- [ ] **Step 1 : Test d'échec**

```dart
test('RatingItem parse author + corridor', () {
  final r = RatingItem.fromJson({
    'stars': 5, 'createdAt': '2026-01-01T00:00:00', 'excluded': false,
    'authorName': 'Fatou M.', 'authorAvatarUrl': 'https://cdn/f.jpg',
    'departureCity': 'Paris', 'arrivalCity': 'Dakar',
  });
  expect(r.authorName, 'Fatou M.');
  expect(r.departureCity, 'Paris');
  expect(r.arrivalCity, 'Dakar');
});
```

- [ ] **Step 2 : Lancer → échec.** Run: `flutter test test/features/ratings/data/models/rating_summary_test.dart` → FAIL.

- [ ] **Step 3 : Étendre `RatingItem`** (champs `authorName`, `authorAvatarUrl`, `departureCity`, `arrivalCity` nullable + fromJson).

- [ ] **Step 4 : Test → succès.** Run même commande → PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/ratings/data/models/rating_summary.dart test/features/ratings/data/models/rating_summary_test.dart
git commit -m "feat(profil): RatingItem auteur + corridor"
```

---

### Task B4 : ProfilePublicModel enrichi

**Files:**
- Modify: `lib/features/profile/data/models/profile_public_model.dart`
- Test: `test/features/profile/data/models/profile_public_model_test.dart` (créer si absent)

- [ ] **Step 1 : Test d'échec**

```dart
test('ProfilePublicModel parse bio/languages/transportMode', () {
  final m = ProfilePublicModel.fromJson({
    'userId': 'u1', 'displayName': 'A', 'kycVerified': true, 'isProAccount': false,
    'isKiloPro': false, 'completedBidsCount': 0, 'averageRating': 0.0, 'ratingCount': 0,
    'memberSince': '2024', 'badges': [],
    'bio': 'Hi', 'languages': ['FR'], 'transportMode': 'AVION',
  });
  expect(m.bio, 'Hi'); expect(m.languages, ['FR']); expect(m.transportMode, 'AVION');
});
```

- [ ] **Step 2 : Lancer → échec.** → FAIL.

- [ ] **Step 3 : Ajouter `String? bio; List<String> languages; String? transportMode;`** + fromJson (`languages` défaut `[]`).

- [ ] **Step 4 : Test → succès.**

- [ ] **Step 5 : Commit**

```bash
git add lib/features/profile/data/models/profile_public_model.dart test/features/profile/data/models/profile_public_model_test.dart
git commit -m "feat(profil): ProfilePublicModel bio/langues/transport"
```

---

# PARTIE C — ÉCRAN « MODIFIER LE PROFIL »

### Task C1 : EditProfileScreen + route

**Files:**
- Create: `lib/features/profile/presentation/screens/edit_profile_screen.dart`
- Modify: `lib/app/router.dart` (route `/profile/edit`)
- Test: `test/features/profile/presentation/screens/edit_profile_screen_test.dart`

> Réutiliser la logique de champs de `edit_profile_bottom_sheet.dart` (prénom, nom, email, birthDate, city) — la migrer telle quelle, puis ajouter À propos / Langues / Transport.

- [ ] **Step 1 : Test widget d'échec** (rendu + sticky save)

```dart
testWidgets('EditProfileScreen rend les champs + bouton sticky', (tester) async {
  await tester.pumpWidget(_wrap(const EditProfileScreen())); // _wrap fournit AuthBloc mock authentifié
  await tester.pump();
  expect(find.text('Modifier le profil'), findsOneWidget);
  expect(find.widgetWithText(TextField, 'Prénom'), findsOneWidget);
  expect(find.text('À propos'), findsOneWidget);
  expect(find.widgetWithText(DonyButton, 'Enregistrer'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec** (écran absent). Run: `flutter test test/features/profile/presentation/screens/edit_profile_screen_test.dart` → FAIL.

- [ ] **Step 3 : Créer `EditProfileScreen`** — `StatefulWidget` (controllers), `Scaffold(backgroundColor: kBackground)`, AppBar retour ‹ + titre + body `SingleChildScrollView` (champs groupés), **bouton sticky bas** via `bottomNavigationBar`/`Container` (jamais dans le child scrollable). Champs :
  - Prénom, Nom (préremplis depuis `AuthBloc.state.user`).
  - **À propos** : `TextField maxLength: 280` + compteur.
  - Email, Date de naissance (date picker), Ville.
  - **Préférences** (si `user.isTraveler`) : Langues (chips multi-select), Mode de transport (segmented AVION/VOITURE/TRAIN).
  - Avatar en tête (Task C2).
  - `BlocListener<AuthBloc>` : sur `AuthProfileUpdated` → `context.pop(true)` ; sur `AuthError` → snackbar.
  - Submit → `context.read<AuthBloc>().add(AuthUpdateProfileRequested(... bio, languages, transportMode ...))`.

- [ ] **Step 4 : Route** dans `router.dart` (à côté de `/profile/upgrade-to-pro`)

```dart
GoRoute(
  path: '/profile/edit',
  builder: (context, state) => const EditProfileScreen(),
),
```
*(AuthBloc est global — vérifier qu'il est fourni au-dessus du router ; il l'est via le MultiBlocProvider racine.)*

- [ ] **Step 5 : Test → succès.** → PASS.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/profile/presentation/screens/edit_profile_screen.dart lib/app/router.dart test/features/profile/presentation/screens/edit_profile_screen_test.dart
git commit -m "feat(profil): écran Modifier le profil + route /profile/edit"
```

---

### Task C2 : Upload photo dans l'écran

**Files:**
- Modify: `lib/features/profile/presentation/screens/edit_profile_screen.dart`
- Test: `test/features/profile/presentation/screens/edit_profile_screen_test.dart`

- [ ] **Step 1 : Test — tap avatar déclenche le picker** (mock `ImagePicker` via abstraction injectable, ou vérifier l'appel `AuthAvatarUploadRequested` après sélection simulée). Vérifie qu'un `AuthAvatarUploadRequested` est ajouté quand un fichier est retourné.

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Implémenter** — avatar `DonyAvatar(imageUrl: user.avatarUrl)` + pastille caméra ; au tap : `ImagePicker().pickImage(source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024)` → si `xfile != null` et taille < 10 Mo → `context.read<AuthBloc>().add(AuthAvatarUploadRequested(xfile.path))`. Loading overlay pendant `AuthLoading`.

- [ ] **Step 4 : Test → succès.**

- [ ] **Step 5 : Commit**

```bash
git add lib/features/profile/presentation/screens/edit_profile_screen.dart test/features/profile/presentation/screens/edit_profile_screen_test.dart
git commit -m "feat(profil): upload photo de profil depuis l'écran d'édition"
```

---

### Task C3 : Migrer les callers + supprimer la bottom sheet

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart` (lignes ~234 et ~412)
- Delete: `lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart`
- Modify/Delete: `test/.../edit_profile_bottom_sheet_test.dart` (le cas échéant)

- [ ] **Step 1 : Remplacer caller header (~234)**

```dart
onEditProfile: () async {
  final changed = await context.push<bool>('/profile/edit');
  if ((changed ?? false) && context.mounted) {
    context.read<AuthBloc>().add(const AuthCheckRequested());
  }
},
```

- [ ] **Step 2 : Remplacer caller bannière complétion (~412)**

```dart
onTap: () async {
  final changed = await context.push<bool>('/profile/edit');
  if ((changed ?? false) && context.mounted) {
    context.read<AuthBloc>().add(const AuthCheckRequested());
  }
},
```
*(L'écran d'édition fait déjà `context.pop(true)` après succès — Task C1. `AuthProfileUpdated`/`AuthCheckRequested` rafraîchit le header.)*

- [ ] **Step 3 : Supprimer la sheet + son import**

```bash
git rm lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart
```
Retirer l'import `edit_profile_bottom_sheet.dart` de `profile_screen.dart`.

- [ ] **Step 4 : Analyze + tests** (vérifier aucun caller orphelin)

Run: `flutter analyze && flutter test test/features/profile/`
Expected: 0 erreur, tests verts.

- [ ] **Step 5 : Commit**

```bash
git add -A
git commit -m "refactor(profil): édition profil en écran plein, suppression bottom sheet"
```

---

# PARTIE D — PROFIL PUBLIC + SHEET AVIS

### Task D1 : À propos + Langues/Transport sur le profil public

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_public_screen.dart`
- Test: `test/features/profile/presentation/screens/profile_public_screen_test.dart`

- [ ] **Step 1 : Test d'échec** — bio visible, Langues/Transport visibles si voyageur, masqués sinon.

```dart
testWidgets('profil public affiche À propos + langues si présents', (tester) async {
  await tester.pumpWidget(_wrapLoaded(profile: profileWith(bio: 'Hello', languages: ['FR'], transportMode: 'AVION')));
  await tester.pumpAndSettle();
  expect(find.text('À propos'), findsOneWidget);
  expect(find.text('Hello'), findsOneWidget);
  expect(find.text('Langues'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Implémenter** — dans `_LoadedView`, insérer après `_HeroCard` : carte **À propos** (si `profile.bio` non vide), puis après `_StatsRow` : carte 2 colonnes **Langues/Transport** (si `profile.languages.isNotEmpty || profile.transportMode != null`). Ordre final : Hero → À propos → Stats → Langues/Transport → Badges → Avis → Contact.

- [ ] **Step 4 : Test → succès.**

- [ ] **Step 5 : Commit**

```bash
git add lib/features/profile/presentation/screens/profile_public_screen.dart test/features/profile/presentation/screens/profile_public_screen_test.dart
git commit -m "feat(profil): profil public — À propos + langues + transport"
```

---

### Task D2 : Bottom sheet « Tous les avis »

**Files:**
- Create: `lib/features/profile/presentation/widgets/all_reviews_bottom_sheet.dart`
- Create: `lib/features/profile/bloc/user_reviews_bloc.dart` (+ event/state) *(ou réutiliser `MyReviewsBloc` paramétré par userId — vérifier sa réutilisabilité)*
- Modify: `lib/features/profile/presentation/screens/profile_public_screen.dart` (bouton « Voir tous les avis »)
- Test: `test/features/profile/presentation/widgets/all_reviews_bottom_sheet_test.dart`

- [ ] **Step 1 : Test d'échec** — la sheet affiche le résumé (note + répartition) et la liste (nom + corridor).

```dart
testWidgets('all reviews sheet montre résumé + items avec corridor', (tester) async {
  await tester.pumpWidget(_wrapSheet(summary: summaryWith(items: [itemWith(authorName: 'Fatou M.', dep: 'Paris', arr: 'Dakar')])));
  await tester.pumpAndSettle();
  expect(find.textContaining('4,9'), findsWidgets);
  expect(find.text('Fatou M.'), findsOneWidget);
  expect(find.textContaining('Paris'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Implémenter la sheet** — `DonyBottomSheet.show` (`isScrollControlled`), handle, en-tête : note moyenne + barres `distribution` ; corps : `ListView` paginé qui charge `getUserRatings(userId, page)` (réutiliser `rating_list_item.dart` ; ajouter affichage nom/avatar/corridor). Read-only → **pas de DonyButton** (conforme règle bottom sheet). Pagination : charger page suivante au scroll en bas.

- [ ] **Step 4 : Bouton sur la carte Avis** — dans `_RecentReviewsSection`, ajouter sous les 2-3 avis un bouton texte « Voir tous les avis ($ratingCount) » → `AllReviewsBottomSheet.show(context, userId: ...)`.

- [ ] **Step 5 : Test → succès.**

- [ ] **Step 6 : Commit**

```bash
git add lib/features/profile/ test/features/profile/presentation/widgets/all_reviews_bottom_sheet_test.dart
git commit -m "feat(profil): bottom sheet tous les avis (résumé + pagination + corridor)"
```

---

# PARTIE E — RÉORGANISATION ONGLETS (anti-régression)

### Task E1 : Déplacer « Mes adresses » → Mon carnet

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart` (_ActivityTab)
- Test: `test/features/profile/presentation/profile_screen_test.dart`

- [ ] **Step 1 : Test** — « Mes adresses » présent pour un **expéditeur non-voyageur** (avant : seulement voyageur).

```dart
testWidgets('Mes adresses visible pour expéditeur (dans Mon carnet)', (tester) async {
  await tester.pumpWidget(_wrapProfile(user: senderOnly()));
  await tester.pumpAndSettle();
  expect(find.text('Mes adresses'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Déplacer la tuile** — retirer « Mes adresses » de la section `MES TRAJETS` (voyageur), l'ajouter dans `MON CARNET` (commune) avec **la même action** `context.push('/profile/addresses')` et subtitle « livraison de mes colis ». Régler `showDivider` : la dernière tuile du carnet = « Mes adresses » `showDivider: false`, « Mes abonnements » repasse `showDivider: true`.

- [ ] **Step 4 : Test → succès + non-régression** (`flutter test test/features/profile/`).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart test/features/profile/presentation/profile_screen_test.dart
git commit -m "refactor(profil): Mes adresses déplacé dans Mon carnet (base)"
```

---

### Task E2 : Fusion Paiements + masquage ComingSoon

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart` (_AccountTab)
- Test: `test/features/profile/presentation/profile_screen_test.dart`

- [ ] **Step 1 : Test** — les tuiles ComingSoon ont disparu, « Mon portefeuille » sous section « PAIEMENTS ».

```dart
testWidgets('ComingSoon masqués, portefeuille sous PAIEMENTS', (tester) async {
  await tester.pumpWidget(_wrapProfile(user: senderOnly(), tab: 1));
  await tester.pumpAndSettle();
  expect(find.text('Moyens de paiement'), findsNothing);
  expect(find.text('Factures'), findsNothing);
  expect(find.text('Crédits & codes promo'), findsNothing);
  expect(find.text('PAIEMENTS'), findsOneWidget);
  expect(find.text('Mon portefeuille'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Implémenter** —
  - Supprimer la section `PAIEMENTS & FACTURES` entière (ses 3 tuiles étaient toutes ComingSoon).
  - Supprimer la tuile « Paiements & factures voyage » (ComingSoon) de la section voyageur REVENUS.
  - Renommer la section `MON PORTEFEUILLE` → label `PAIEMENTS` (garder la tuile « Mon portefeuille » → `/payments/wallet`).
  - Retirer l'import `ComingSoonBottomSheet` s'il n'est plus utilisé ailleurs (vérifier).

- [ ] **Step 4 : Test + analyze.** Run: `flutter analyze && flutter test test/features/profile/` → 0 erreur, vert.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart test/features/profile/presentation/profile_screen_test.dart
git commit -m "refactor(profil): fusion section Paiements + masquage tuiles Bientôt"
```

---

### Task E3 : Devenir voyageur en carte CTA

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart` (_AccountTab)
- Create: `lib/features/profile/presentation/widgets/become_traveler_cta_card.dart`
- Test: `test/features/profile/presentation/profile_screen_test.dart`

- [ ] **Step 1 : Test** — pour non-voyageur, carte CTA en haut de l'onglet Compte, tap → route become-traveler.

```dart
testWidgets('CTA Devenir voyageur en haut de Compte (non-voyageur)', (tester) async {
  await tester.pumpWidget(_wrapProfile(user: senderOnly(), tab: 1));
  await tester.pumpAndSettle();
  expect(find.text('Devenir voyageur'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Créer `BecomeTravelerCtaCard`** (carte gradient `kGreenPrimary→kGreenDark`/bleu, icône 🧭, titre + sous-titre, chevron) → `onTap: context.push('/profile/become-traveler')`. La placer **en haut** de `_AccountTab` `if (!isTraveler)`. Supprimer l'ancienne section liste « DEVENIR VOYAGEUR ». **Conserver** l'info statut (KYC/Stripe) — l'intégrer dans la carte ou en sous-texte.

- [ ] **Step 4 : Test + non-régression.**

- [ ] **Step 5 : Commit**

```bash
git add lib/features/profile/ test/features/profile/presentation/profile_screen_test.dart
git commit -m "feat(profil): Devenir voyageur en carte CTA en tête de Compte"
```

---

# PARTIE F — FLOWS

### Task F1 : PRO en écran unique + downgrade

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart` (~817 : tuile COMPTE PRO)
- Modify: `lib/features/profile/presentation/screens/upgrade_to_pro_screen.dart` (état déjà-PRO + downgrade)
- Delete: `lib/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart`
- Test: `test/features/profile/presentation/screens/upgrade_to_pro_screen_test.dart`

- [ ] **Step 1 : Test** — si `isProAccount`, l'écran montre infos société + bouton « Revenir en compte standard ».

```dart
testWidgets('UpgradeToProScreen montre downgrade si déjà PRO', (tester) async {
  await tester.pumpWidget(_wrapPro(user: proUser())); // AuthBloc state pro
  await tester.pumpAndSettle();
  expect(find.text('Revenir en compte standard'), findsOneWidget);
});
```

- [ ] **Step 2 : Lancer → échec.**

- [ ] **Step 3 : Router la tuile** (profile_screen ~817)

```dart
onTap: user != null ? () => context.push('/profile/upgrade-to-pro') : null,
```

- [ ] **Step 4 : Écran PRO** — lire `AuthBloc.state.user.isProAccount`. Si PRO : afficher nom société + SIRET (lecture) + `DonyButton('Revenir en compte standard', variant: destructive)` → dialog confirm → `ProfileRepository.downgradeFromPro()` (`DELETE /auth/me/upgrade-to-pro`, déjà existant) → `AuthCheckRequested`. Sinon : formulaire actuel (inchangé). Confirmation PRO via dialog (déjà présent).

- [ ] **Step 5 : Supprimer la sheet**

```bash
git rm lib/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart
```
Retirer l'import dans `profile_screen.dart`. Vérifier aucun autre caller (`rtk proxy grep -rn UpgradeProBottomSheet lib/`).

- [ ] **Step 6 : Analyze + tests.** Run: `flutter analyze && flutter test test/features/profile/` → 0 erreur, vert.

- [ ] **Step 7 : Commit**

```bash
git add -A
git commit -m "refactor(profil): PRO en écran unique + downgrade, suppression bottom sheet"
```

---

### Task F2 : Polish stepper Devenir voyageur

**Files:**
- Modify: `lib/features/profile/presentation/screens/become_traveler_screen.dart`
- Test: `test/features/profile/presentation/screens/become_traveler_screen_test.dart`

> Polish visuel uniquement — **ne pas toucher** à la logique d'activation (`TravelerUpgradeActivateRequested`/`Deactivate`) ni aux conditions `canActivate`.

- [ ] **Step 1 : Test de non-régression** — bouton « Activer mon compte voyageur » présent quand KYC+Stripe OK ; le test existant doit rester vert.

- [ ] **Step 2 : Appliquer le hero + stepper visuel** (numéros d'étape, ✓ vert quand fait) sans changer les callbacks. Bouton déjà sticky.

- [ ] **Step 3 : Tests → succès** (`flutter test test/features/profile/presentation/screens/become_traveler_screen_test.dart`).

- [ ] **Step 4 : Commit**

```bash
git add lib/features/profile/presentation/screens/become_traveler_screen.dart test/features/profile/presentation/screens/become_traveler_screen_test.dart
git commit -m "style(profil): polish stepper Devenir voyageur"
```

---

# PARTIE G — ANALYTICS & FINALISATION

### Task G1 : Analytics

**Files:**
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `lib/features/auth/bloc/auth_bloc.dart` + `lib/core/di/injection.dart` (injecter `AnalyticsService` dans AuthBloc si absent)
- Modify: `lib/features/profile/presentation/widgets/all_reviews_bottom_sheet.dart` (event ouverture) — ou dans le bloc associé
- Modify: `dony_app/CLAUDE.md` (table events)
- Test: tests bloc concernés

- [ ] **Step 1 : Déclarer les events**

```dart
static const profilePhotoUpdated = 'profile_photo_updated';
static const profileAboutUpdated = 'profile_about_updated';
static const publicReviewsOpened = 'public_reviews_opened';
```

- [ ] **Step 2 : Tirer les events** — `profile_photo_updated` (Task B2 handler), `profile_about_updated` dans `_onUpdateProfileRequested` si `event.bio != null && event.bio.isNotEmpty`, `public_reviews_opened` à l'ouverture de la sheet (`unawaited`, propriété `rating_count`). Si `AuthBloc` n'a pas `AnalyticsService`, l'injecter via constructeur + `injection.dart` (`getIt<AnalyticsService>()`).

- [ ] **Step 3 : Mettre à jour la table des events** dans `dony_app/CLAUDE.md`.

- [ ] **Step 4 : Tests verts** (`flutter test test/features/auth/ test/features/profile/`).

- [ ] **Step 5 : Commit**

```bash
git add lib/ dony_app/CLAUDE.md test/
git commit -m "feat(profil): analytics photo/à-propos/avis + injection AnalyticsService"
```

---

### Task G2 : Vérification finale + doc story

**Files:**
- Create: `dony_app/docs/stories-done/story-phase-4-profil-coherence.md`

- [ ] **Step 1 : Suite complète front**

Run: `flutter analyze && flutter test --coverage`
Expected: 0 erreur, tous tests verts, couverture ≥ 90 %.

- [ ] **Step 2 : Suite complète back**

Run: `cd dony-back && ./mvnw test jacoco:report`
Expected: vert, couverture ≥ 90 %.

- [ ] **Step 3 : Vérification anti-régression manuelle** — relancer l'app (`flutter run --dart-define-from-file=env.dev.json`), parcourir les 3 onglets en compte expéditeur ET voyageur : vérifier que **chaque tuile de l'inventaire** ouvre la bonne destination ; éditer le profil (champs + photo) ; ouvrir profil public + tous les avis ; passer/quitter PRO ; devenir voyageur.

- [ ] **Step 4 : Écrire la story** (`docs/stories-done/story-phase-4-profil-coherence.md`) selon le template `dony_app/CLAUDE.md`.

- [ ] **Step 5 : Commit**

```bash
git add dony_app/docs/stories-done/story-phase-4-profil-coherence.md
git commit -m "docs(profil): story phase 4 profil cohérent"
```

---

## Self-review (couverture spec)

- §2 data → A1/A2/A3/A5/A6 (back) + B1/B3/B4 (front) ✅
- §3 back endpoints → A3 (PATCH), A4 (avatar), A5 (public), A6 (avis) ✅
- §4.1 A edit screen → C1/C2/C3 ✅
- §4.2 B public + sheet avis → D1/D2 ✅
- §4.3 C onglets → E1/E2/E3 ✅
- §4.4 D become traveler → F2 ✅
- §4.5 E PRO écran unique → F1 ✅
- §5 analytics → G1 ✅
- §6 tests ≥90 % → chaque task TDD + G2 ✅

**Points à vérifier à l'exécution (non bloquants) :**
- Noms exacts getters `AnnouncementEntity.getDepartureCity/getArrivalCity` + `BidEntity.getAnnouncementId` (Task A6).
- `RatingService` injecte déjà `bidRepository`/`announcementRepository` (sinon les ajouter au constructeur + tests).
- `AuthBloc` possède déjà `AnalyticsService` ? sinon Task G1 l'injecte.
- Config `storage.public-base-url` + bucket `users/` public-read (Task A4, déploiement).
