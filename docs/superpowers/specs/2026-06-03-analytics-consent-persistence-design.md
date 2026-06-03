# Persistance du consentement analytics (backend + sync) — Design

**Date:** 2026-06-03
**Statut:** approuvé (implémentation en cours)

## Problème

Le consentement analytics RGPD est stocké uniquement dans Hive (local). Conséquences :
- Désinstallation / réinstallation → consentement perdu → l'utilisateur est redemandé.
- Multi-appareils → chaque appareil redemande indépendamment.
- Aucune preuve légale (timestamp + version de politique) que le consentement a été donné — exigence RGPD/CNIL.

## Solution

**Hive = cache local rapide. Backend = source de vérité. `audit_log` = preuve légale immuable.**

| Action | Hive | Backend (`users`) | `audit_log` |
|--------|------|-------------------|-------------|
| L'utilisateur répond | écrit immédiat | PUT (set colonnes) | entrée `ANALYTICS_CONSENT_UPDATED` |
| Login | lu (rapide) | GET → réconcilie Hive | — |
| Réinstall | perdu → récupéré au login | source de vérité | historique conservé |

---

## Contrat API

### `GET /api/v1/auth/me/analytics-consent`
Réponse `200` :
```json
{ "granted": true, "consentAt": "2026-06-03T04:55:08.960Z", "policyVersion": "1.0" }
```
`granted` est `null` si l'utilisateur n'a jamais répondu (`consentAt` et `policyVersion` alors `null`).

### `PUT /api/v1/auth/me/analytics-consent`
Body :
```json
{ "granted": true, "policyVersion": "1.0", "source": "manual" }
```
- `granted` : **requis** (`@NotNull Boolean`).
- `policyVersion` : optionnel (`String`, max 32). Version de la politique affichée à l'utilisateur.
- `source` : optionnel (`String`, max 32). Origine de la décision : `manual` | `auto_non_gdpr` | `settings` | `sync`.

Réponse `204 No Content`. Crée une entrée `audit_log` (`ANALYTICS_CONSENT_UPDATED`, payload `{granted, policyVersion, source}`).

Erreurs : RFC 7807 `ProblemDetail` via `GlobalExceptionHandler` (404 `user-not-found` si utilisateur introuvable).

---

## Backend (`dony-back`)

### Migration `V120__analytics_consent.sql`
```sql
ALTER TABLE users ADD COLUMN analytics_consent BOOLEAN;            -- null = jamais répondu
ALTER TABLE users ADD COLUMN analytics_consent_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN analytics_consent_version VARCHAR(32);
ALTER TABLE users ADD COLUMN analytics_consent_source VARCHAR(32);
```
Nullable (pas de DEFAULT) : `null` distingue « jamais répondu » de « refusé ».

### `UserEntity` — nouveaux champs
Suivre la convention existante (`Instant` pour `*_at`, cf. `deletionRequestedAt`) :
```java
@Column(name = "analytics_consent")
private Boolean analyticsConsent;        // null = jamais répondu

@Column(name = "analytics_consent_at")
private Instant analyticsConsentAt;

@Column(name = "analytics_consent_version")
private String analyticsConsentVersion;

@Column(name = "analytics_consent_source")
private String analyticsConsentSource;
```
+ getters/setters au même style que les autres champs.

### DTOs (`com.dony.api.auth.dto`)
```java
public record AnalyticsConsentRequest(
    @NotNull Boolean granted,
    @Size(max = 32) String policyVersion,
    @Size(max = 32) String source) {}

public record AnalyticsConsentResponse(
    Boolean granted, String consentAt, String policyVersion) {}
```
`consentAt` sérialisé en ISO-8601 (`Instant.toString()`), `null` si jamais répondu.

### `AuthController` — endpoints (modèle : `privacy-settings`)
```java
@GetMapping("/me/analytics-consent")
public ResponseEntity<AnalyticsConsentResponse> getAnalyticsConsent() {
    return ResponseEntity.ok(authService.getAnalyticsConsent(requireFirebaseUid()));
}

@PutMapping("/me/analytics-consent")
public ResponseEntity<Void> updateAnalyticsConsent(
        @Valid @RequestBody AnalyticsConsentRequest request) {
    authService.updateAnalyticsConsent(requireFirebaseUid(),
        request.granted(), request.policyVersion(), request.source());
    return ResponseEntity.noContent().build();
}
```

### `AuthService` — méthodes (modèle : `getPrivacySettings`/`updatePrivacySettings`)
- `getAnalyticsConsent(firebaseUid)` → `@Transactional(readOnly = true)`, 404 `user-not-found`.
- `updateAnalyticsConsent(firebaseUid, granted, policyVersion, source)` → `@Transactional` :
  - set `analyticsConsent = granted`, `analyticsConsentAt = Instant.now()`, version, source ;
  - `userRepository.save(user)` ;
  - `auditService.log("USER", user.getId(), "ANALYTICS_CONSENT_UPDATED", user.getId(), Map.of("granted", granted, "policyVersion", ..., "source", ...))` (utiliser des valeurs non-null dans la map).

### Tests backend
- `AuthServiceTest` : get (répondu / jamais répondu), update (set colonnes + audit log appelé).
- `AuthControllerIntegrationTest` (MockMvc, `@ActiveProfiles("test")`, `@MockBean FirebaseAuth`) : GET 200, PUT 204, PUT sans `granted` → 400/422.
- Couverture ≥ 90 % sur le nouveau code.

---

## Frontend (`dony_app` / worktree `dony_app-analytics`)

### Constante de version
```dart
const kAnalyticsPolicyVersion = '1.0';
```
(dans `analytics_service.dart`). Le client envoie la version qu'il a affichée → le backend la stocke (preuve de ce que l'utilisateur a vu).

### Abstraction remote (modèle : `AnalyticsBackend` déjà dans le fichier)
```dart
abstract interface class AnalyticsConsentRemote {
  Future<bool?> fetch();   // null = backend n'a pas de réponse
  Future<void> push({required bool granted,
      required String policyVersion, required String source});
}

class NoopAnalyticsConsentRemote implements AnalyticsConsentRemote {
  const NoopAnalyticsConsentRemote();
  @override Future<bool?> fetch() async => null;
  @override Future<void> push({...}) async {}
}
```
+ `ApiAnalyticsConsentRemote(ApiClient)` (Dio) :
- `fetch()` → `GET /auth/me/analytics-consent` → `resp.data['granted'] as bool?`.
- `push()` → `PUT /auth/me/analytics-consent`, body `{granted, policyVersion, source}`.

### `AnalyticsService` — modifications
- Constructeur : ajouter `AnalyticsConsentRemote remote = const NoopAnalyticsConsentRemote()`.
- `setConsent({required bool granted, String source = 'manual'})` :
  Hive write + `_applyConsent()` (inchangé) **+** `unawaited(_remote.push(granted: granted, policyVersion: kAnalyticsPolicyVersion, source: source))`.
- Nouvelle `syncFromBackend()` (appelée au login) — réconciliation :
  ```
  try {
    final backendGranted = await _remote.fetch();   // bool?
    if (backendGranted != null) {
      if (consent != backendGranted) {
        await _hive.userPrefs.put(HiveService.kAnalyticsConsent, backendGranted);
      }
      if (_configured) await _applyConsent();
    } else if (hasAnswered) {
      // backend ignore la réponse → on pousse l'état local (réinstall / offline)
      unawaited(_remote.push(granted: consent!,
          policyVersion: kAnalyticsPolicyVersion, source: 'sync'));
    }
  } catch (_) { /* réseau indisponible → on garde l'état local */ }
  ```
  Le backend prime sur le local : si l'utilisateur a révoqué sur un autre appareil (`granted=false`), le local s'aligne.

### DI (`injection.dart`)
```dart
getIt.registerLazySingleton<AnalyticsConsentRemote>(
  () => ApiAnalyticsConsentRemote(getIt<ApiClient>()),
);
// AnalyticsService :
() => AnalyticsService(getIt<HiveService>(), remote: getIt<AnalyticsConsentRemote>()),
```

### `AnalyticsConsentGate` — login
Sur `user != null` : `identify(uid)` puis `await _analytics.syncFromBackend()` **avant** la détection GPS / redirection consentement. Ainsi un utilisateur réinstallé qui a déjà consenti côté backend n'est PAS redemandé (`hasAnswered` redevient `true` après sync).

### Sources aux points d'appel `setConsent`
- `analytics_consent_screen.dart` (écran inscription) → défaut `manual`.
- `analytics_consent_sheet.dart` → défaut `manual`.
- `pin_setup_screen.dart` (auto-grant hors RGPD) → `source: 'auto_non_gdpr'`.
- `privacy_settings_screen.dart` (toggle réglages) → `source: 'settings'`.

### Tests frontend
- `AnalyticsService` : `setConsent` pousse au remote ; `syncFromBackend` (backend=true/false/null × local répondu/non) ; tolérance d'erreur réseau.
- `ApiAnalyticsConsentRemote` : fetch/push avec Dio mocké.
- Mettre à jour les helpers de test existants si la signature `AnalyticsService` change (le défaut `NoopAnalyticsConsentRemote` évite de casser les appels existants).
- Couverture ≥ 90 % sur le nouveau code.

---

## Points de vigilance
- **PII** : aucune donnée perso dans le payload audit ni dans les events (uniquement `granted`/`version`/`source`).
- **`audit_log` immuable** : INSERT seulement, jamais UPDATE/DELETE.
- **Ownership** : les endpoints opèrent sur l'utilisateur du token Firebase (`requireFirebaseUid()`), jamais d'ID arbitraire.
- **Non-bloquant** : `push` est `unawaited` côté client — le tracking et l'UX ne doivent jamais attendre le réseau.
- **Rétro-compat** : `NoopAnalyticsConsentRemote` par défaut → les tests existants instanciant `AnalyticsService(hive)` continuent de compiler.
