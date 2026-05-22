# Notification Preferences — Synchronisation Backend

**Date:** 2026-05-22
**Status:** Approuvé
**Branche:** feat/settings-screen

---

## Contexte

Les préférences de notifications (6 clés Hive) sont actuellement purement locales. Le filtrage foreground fonctionne via `NotificationService._isForegroundAllowed()` qui lit Hive. Mais les notifications background arrivent depuis le backend sans tenir compte des préférences : l'OS affiche le push directement, Flutter ne peut pas l'intercepter.

Pour filtrer les notifications background (app en arrière-plan ou fermée), le backend doit connaître les préférences de l'utilisateur et décider de ne pas envoyer le push du tout.

---

## Périmètre

### Prefs synchronisées (5 push)

| Clé Hive | Défaut | Types FCM couverts |
|----------|--------|-------------------|
| `push_activity_bids` | `true` | BID_CREATED, BID_ACCEPTED, BID_REJECTED, HANDOVER_DEFINED, PARCEL_REFUSED, BID_EXPIRED, TRIP_CANCELLED |
| `push_activity_negotiations` | `true` | negotiation_started, negotiation_counter, negotiation_awaiting_trip, negotiation_awaiting_payment, request_accepted, request_expired, negotiation_expired |
| `push_messages` | `true` | NEW_MESSAGE |
| `push_trip_reminder` | `true` | TRIP_IN_PROGRESS |
| `push_promo` | `false` | PROMO |

### Hors périmètre

- `email_promo` : reste local uniquement (pas de système d'emailing backend en MVP)
- Notifications critiques : `PAYMENT_RELEASED`, `DELIVERY_CONFIRMED`, `DISPUTE_OPENED` — jamais filtrées, ignorées par le système de prefs

---

## Trigger de synchronisation

**Sur chaque toggle** : dès que l'utilisateur bascule un switch, le BLoC persiste en Hive puis appelle `PUT /notifications/preferences` avec les 5 valeurs courantes.

**Comportement en cas d'échec réseau** : silencieux. La valeur locale Hive est conservée. Pas de rollback, pas de toast d'erreur. Le backend sera mis à jour au prochain toggle réussi.

---

## Backend

### Migration Flyway — V95

```sql
CREATE TABLE user_notification_preferences (
  user_id                     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  push_activity_bids          BOOLEAN NOT NULL DEFAULT TRUE,
  push_activity_negotiations  BOOLEAN NOT NULL DEFAULT TRUE,
  push_messages               BOOLEAN NOT NULL DEFAULT TRUE,
  push_trip_reminder          BOOLEAN NOT NULL DEFAULT TRUE,
  push_promo                  BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

- Clé primaire `user_id` (relation 1-1 avec `users`, pas de doublon possible)
- `ON DELETE CASCADE` : suppression propre si l'utilisateur est soft-deleted puis purgé
- Valeurs par défaut identiques aux defaults Flutter

### Entité JPA

```java
@Entity
@Table(name = "user_notification_preferences")
public class NotificationPrefsEntity {
    @Id
    private UUID userId;

    @Column(nullable = false)
    private boolean pushActivityBids = true;

    @Column(nullable = false)
    private boolean pushActivityNegotiations = true;

    @Column(nullable = false)
    private boolean pushMessages = true;

    @Column(nullable = false)
    private boolean pushTripReminder = true;

    @Column(nullable = false)
    private boolean pushPromo = false;

    @Column(nullable = false)
    @UpdateTimestamp
    private Instant updatedAt;
}
```

Note : n'étend **pas** `BaseEntity` — `BaseEntity` génère son propre `@Id` UUID auto, incompatible avec `userId` comme clé primaire métier. Le timestamp `updatedAt` est géré via `@UpdateTimestamp` Hibernate.

### DTO

```java
public record NotificationPrefsDto(
    boolean pushActivityBids,
    boolean pushActivityNegotiations,
    boolean pushMessages,
    boolean pushTripReminder,
    boolean pushPromo
) {}
```

### Repository JPA

```java
public interface NotificationPrefsJpaRepository
    extends JpaRepository<NotificationPrefsEntity, UUID> {}
```

### Service

```java
@Service
@Transactional
public class NotificationPrefsService {

    // Retourne les prefs ou les defaults si l'utilisateur n'en a pas encore
    public NotificationPrefsDto getPrefs(UUID userId) { ... }

    // Upsert : crée ou met à jour atomiquement
    public void upsert(UUID userId, NotificationPrefsDto dto) { ... }

    // Utilisé par le NotificationSender avant chaque push
    public boolean isAllowed(UUID userId, String notificationType) { ... }
}
```

`isAllowed()` mappe le type FCM vers la colonne correspondante et retourne la valeur. Les types critiques (`PAYMENT_RELEASED`, `DELIVERY_CONFIRMED`, `DISPUTE_OPENED`) retournent toujours `true` sans consulter la base.

### Controller — nouveaux endpoints dans `NotificationController`

```
GET  /notifications/preferences
     → 200 NotificationPrefsDto (defaults si pas encore de ligne)

PUT  /notifications/preferences
     → body: NotificationPrefsDto
     → 204 No Content
```

Les deux endpoints sont protégés par `FirebaseTokenFilter` (comme tous les endpoints existants). Le `userId` est extrait du token Firebase.

### Intégration dans le flux d'envoi push

Dans `FcmService.sendToUser()` (`notifications/FcmService.java`), avant le `sendToToken()` interne :

```java
if (!prefsService.isAllowed(userId, data.get("type"))) {
    log.debug("[FCM] Notification supprimée par pref user={} type={}", userId, data.get("type"));
    return false;
}
```

Les types critiques bypass ce check (retournent toujours `true` dans `isAllowed`).

---

## Flutter

### Nouveaux fichiers

#### `lib/features/settings/data/notification_prefs_datasource.dart`

```dart
class NotificationPrefsDatasource {
  final ApiClient _apiClient;

  Future<void> syncPrefs(Map<String, bool> prefs) async {
    await _apiClient.dio.put(
      '/notifications/preferences',
      data: {
        'pushActivityBids':         prefs['push_activity_bids'] ?? true,
        'pushActivityNegotiations': prefs['push_activity_negotiations'] ?? true,
        'pushMessages':             prefs['push_messages'] ?? true,
        'pushTripReminder':         prefs['push_trip_reminder'] ?? true,
        'pushPromo':                prefs['push_promo'] ?? false,
      },
    );
  }
}
```

#### `lib/features/settings/data/notification_prefs_repository.dart`

```dart
class NotificationPrefsRepository {
  final NotificationPrefsDatasource _datasource;

  Future<void> syncPrefs(Map<String, bool> prefs) async {
    try {
      await _datasource.syncPrefs(prefs);
    } catch (_) {
      // Échec silencieux — la valeur Hive locale est conservée
    }
  }
}
```

### Modification du BLoC

`NotificationPrefsBloc` reçoit `NotificationPrefsRepository` en paramètre :

```dart
class NotificationPrefsBloc extends Bloc<NotificationPrefsEvent, NotificationPrefsState> {
  final Box _box;
  final NotificationPrefsRepository _repository;

  NotificationPrefsBloc(this._box, this._repository) : ...

  void _onToggled(NotifPrefToggled event, Emitter emit) {
    final updated = Map<String, bool>.from(state.prefs);
    updated[event.key] = !(updated[event.key] ?? false);
    _box.put('notif_${event.key}', updated[event.key]);
    emit(NotificationPrefsState(prefs: updated));
    // Fire-and-forget : pas d'await, pas de loading state
    _repository.syncPrefs(updated);
  }
}
```

### DI (`injection.dart`)

```dart
getIt.registerLazySingleton<NotificationPrefsDatasource>(
  () => NotificationPrefsDatasource(getIt<ApiClient>()),
);
getIt.registerLazySingleton<NotificationPrefsRepository>(
  () => NotificationPrefsRepository(getIt<NotificationPrefsDatasource>()),
);
getIt.registerFactory<NotificationPrefsBloc>(
  () => NotificationPrefsBloc(
    getIt<HiveService>().userPrefs,
    getIt<NotificationPrefsRepository>(),
  ),
);
```

---

## Tests

### Flutter — BLoC

| Test | Comportement attendu |
|------|---------------------|
| Toggle `push_activity_bids` | `syncPrefs` appelé avec `pushActivityBids: false` |
| Toggle `push_promo` | `syncPrefs` appelé avec `pushPromo: true` |
| `syncPrefs` lève une exception | State émis normalement, pas de crash |
| Deux toggles successifs | `syncPrefs` appelé deux fois |

### Flutter — Datasource

| Test | Comportement attendu |
|------|---------------------|
| `syncPrefs` appelle `PUT /notifications/preferences` | Body JSON correctement encodé (camelCase) |

### Backend — Service

| Test | Comportement attendu |
|------|---------------------|
| `upsert` sur utilisateur sans prefs | Crée une ligne avec les valeurs fournies |
| `upsert` sur utilisateur avec prefs existantes | Met à jour les valeurs |
| `isAllowed` type critique | Retourne `true` indépendamment des prefs |
| `isAllowed` type filtrable avec pref `false` | Retourne `false` |
| `isAllowed` type inconnu | Retourne `true` (défaut permissif) |

### Backend — Controller

| Test | Comportement attendu |
|------|---------------------|
| `PUT /notifications/preferences` avec token valide | 204 No Content |
| `PUT /notifications/preferences` sans token | 401 |
| `GET /notifications/preferences` sans ligne existante | 200 avec defaults |
| `GET /notifications/preferences` avec ligne existante | 200 avec valeurs stockées |

---

## Fichiers créés / modifiés

### Backend

| Fichier | Action |
|---------|--------|
| `src/main/resources/db/migration/V95__user_notification_preferences.sql` | Créer |
| `src/main/java/com/dony/api/notifications/NotificationPrefsEntity.java` | Créer |
| `src/main/java/com/dony/api/notifications/NotificationPrefsDto.java` | Créer |
| `src/main/java/com/dony/api/notifications/NotificationPrefsJpaRepository.java` | Créer |
| `src/main/java/com/dony/api/notifications/NotificationPrefsService.java` | Créer |
| `src/main/java/com/dony/api/notifications/NotificationController.java` | Modifier (ajouter GET + PUT) |
| `src/main/java/com/dony/api/notifications/FcmService.java` | Modifier (check `isAllowed` dans `sendToUser()`) |
| `src/test/.../notifications/NotificationPrefsServiceTest.java` | Créer |
| `src/test/.../notifications/NotificationControllerTest.java` | Modifier |

### Flutter

| Fichier | Action |
|---------|--------|
| `lib/features/settings/data/notification_prefs_datasource.dart` | Créer |
| `lib/features/settings/data/notification_prefs_repository.dart` | Créer |
| `lib/features/settings/bloc/notification_prefs_bloc.dart` | Modifier (ajouter repo) |
| `lib/core/di/injection.dart` | Modifier (enregistrer datasource + repo) |
| `test/features/settings/bloc/notification_prefs_bloc_test.dart` | Modifier |
| `test/features/settings/data/notification_prefs_datasource_test.dart` | Créer |
