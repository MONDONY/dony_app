# Story 8.1 — Configuration des canaux de notification Firebase FCM (Flutter)

**Date:** 2026-04-26
**Status:** ✅ Complète

## Résumé
`NotificationService` est completement implémenté : permissions, affichage local en foreground, navigation deep-link sur tap, upload du token FCM au backend à chaque connexion et refresh.

## Fichiers créés / modifiés
- `lib/features/notifications/data/notification_service.dart` — implémentation complète (remplace le stub)
- `lib/app/app.dart` — converti en `StatefulWidget` pour écouter le stream de navigation
- `lib/core/di/injection.dart` — `NotificationService` reçoit désormais `ApiClient`
- `pubspec.yaml` — ajout `flutter_local_notifications: ^18.0.0`

## Comment ça fonctionne

### Flux token FCM
1. `initialize()` est appelé dans `main.dart` après Firebase init
2. `requestPermission()` demande l'autorisation iOS / Android 13+
3. `getToken()` récupère le token et appelle `PUT /api/v1/auth/me/fcm-token`
4. `onTokenRefresh.listen(_uploadToken)` maintient le token à jour automatiquement

### Flux notification foreground
1. `FirebaseMessaging.onMessage` se déclenche quand l'app est au premier plan
2. `_handleForegroundMessage()` appelle `_localNotifications.show()` avec le canal `dony_transactional`
3. L'utilisateur voit une bannière de notification native Android/iOS

### Flux navigation sur tap
1. Tap sur notification background/terminated → `onMessageOpenedApp` ou `getInitialMessage`
2. `_handleNotificationTap()` calcule la route via `_routeForMessage(data)`
3. La route est émise dans `_navigationController` (stream broadcast)
4. `_DonyAppState` écoute ce stream et appelle `appRouter.go(route)`

### Routes supportées (champ `data.type`)
| type | route |
|---|---|
| `BID_CREATED` | `/matching/bids/{announcementId}` |
| `BID_ACCEPTED`, `BID_REJECTED`, `HANDOVER_DEFINED`, `PAYMENT_RELEASED`, `DELIVERY_CONFIRMED`, `DISPUTE_OPENED` | `/shipments/{bidId}` |
| `TRIP_CANCELLED` | `/home` |
| `CONFIRMATION_CODE_READY` | `/shipments/{bidId}` |

### Background handler
Fonction top-level `firebaseMessagingBackgroundHandler` annotée `@pragma('vm:entry-point')` — gère les messages quand l'app est en arrière-plan/terminée.

## Critères d'acceptation couverts
- [x] Token FCM envoyé au backend au démarrage et sur refresh
- [x] Notification locale affichée quand l'app est en foreground
- [x] Tap sur notification → navigation GoRouter vers l'écran concerné
- [x] Handler background top-level enregistré

## Tests
- `flutter analyze lib/` → 0 erreur, 0 warning
- `flutter test --coverage` → à lancer pour vérifier la couverture

## Décisions techniques
- **Stream broadcast plutôt que GlobalKey** : `NotificationService` émet des routes dans un `StreamController.broadcast()`, `DonyApp` écoute. Évite toute dépendance sur le layer routing depuis le service.
- **`DonyApp` devient StatefulWidget** : uniquement pour gérer le `StreamSubscription` (subscribe/cancel). Pas d'impact sur le build tree.
- **Canaux Android** : `dony_transactional` (haute priorité) créé programmatiquement à l'init.
