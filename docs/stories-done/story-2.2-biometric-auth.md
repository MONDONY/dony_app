# Story 2.2 — Connexion avec authentification biométrique (Flutter)

**Date:** 2026-04-19
**Status:** ✅ Complète

## Résumé
Implémentation de l'authentification biométrique (empreinte digitale / Face ID) au lancement de l'app. La biométrie se déclenche automatiquement au démarrage ; en cas d'échec ou d'indisponibilité, l'app bascule silencieusement vers l'écran PIN (Story 2.3).

## Fichiers créés
- `lib/features/auth/bloc/local_auth_event.dart` — events du cycle d'authentification locale
- `lib/features/auth/bloc/local_auth_state.dart` — states : Initial, Checking, PinRequired, Locked, Success, Error
- `lib/features/auth/bloc/local_auth_bloc.dart` — logique biométrie + PIN + blocage
- `lib/features/auth/data/services/local_auth_service.dart` — wrapper `local_auth` + `flutter_secure_storage`
- `lib/features/auth/presentation/screens/local_auth_screen.dart` — écran PIN/biométrie au retour dans l'app
- `lib/core/widgets/dony_keypad.dart` — pavé numérique 3×4 réutilisable avec bouton biométrie optionnel

## Fichiers modifiés
- `lib/app/router.dart` — ajout route `/auth/local`
- `lib/app/app.dart` — ajout `BlocProvider<LocalAuthBloc>` dans le MultiBlocProvider
- `lib/core/di/injection.dart` — enregistrement `LocalAuthService` (singleton) et `LocalAuthBloc` (factory)
- `pubspec.yaml` — ajout `flutter_animate`, `flutter_secure_storage`
- `android/app/src/main/AndroidManifest.xml` — permissions `USE_BIOMETRIC` et `USE_FINGERPRINT`

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur
1. L'app démarre → SplashScreen vérifie le backend puis appelle `AuthCheckRequested`
2. Si `AuthAuthenticated` → `context.go('/auth/local')` (l'utilisateur est enregistré)
3. `LocalAuthScreen.initState` dispatche `LocalAuthStarted`
4. `LocalAuthBloc._onStarted` appelle `LocalAuthService.isBiometricAvailable()`
5. Si biométrie disponible → `authenticateWithBiometric()` → succès → `LocalAuthSuccess` → `context.go('/home')`
6. Si biométrie indisponible ou échec → `LocalAuthPinRequired(attemptsLeft: 3, biometricAvailable: false/true)`
7. L'écran affiche le clavier PIN pour fallback

### BLoC : events et states
- **`LocalAuthStarted`** — déclenché dans `initState` via `addPostFrameCallback`. Tente la biométrie automatiquement.
- **`LocalAuthBiometricRequested`** — déclenché par le bouton empreinte du DonyKeypad. Permet de retenter manuellement.
- **`LocalAuthPinSubmitted(pin)`** — déclenché après saisie des 6 chiffres.
- **`LocalAuthLockExpired`** — déclenché par le `Timer.periodic` du widget quand le compte à rebours atteint 0.

States émis :
- `LocalAuthChecking` — pendant la vérification biométrique (affiche CircularProgressIndicator)
- `LocalAuthPinRequired(attemptsLeft, biometricAvailable)` — affiche le clavier PIN
- `LocalAuthLocked(secondsLeft)` — clavier désactivé, message de compte à rebours
- `LocalAuthSuccess` — redirige vers `/home`

### Écrans et widgets clés
**`LocalAuthScreen`** :
- `initState` : `addPostFrameCallback` pour dispatcher `LocalAuthStarted` après le premier frame
- `BlocConsumer` : listener pour navigation (`LocalAuthSuccess → /home`) et countdown (`LocalAuthLocked`)
- Le countdown est géré par `Timer.periodic` dans le widget (pas dans le BLoC) car `Emitter` n'est valide que pendant le traitement d'un event
- Affiche le bouton biométrie dans `DonyKeypad` uniquement si `state.biometricAvailable == true`

**`DonyKeypad`** :
- Widget réutilisable dans `lib/core/widgets/`
- Paramètre `onBiometric` optionnel : si null, le bouton empreinte est absent
- Paramètre `enabled` : désactive toutes les touches (état bloqué)

### Pièges et points d'attention
- **`addPostFrameCallback` obligatoire** dans `initState` : dispatcher un event BLoC directement dans `initState` peut lever une exception si le widget n'est pas encore monté dans l'arbre.
- **Le countdown dans le widget, pas dans le BLoC** : `Emitter<LocalAuthState>` est invalide après la fin du handler. Si on essayait d'émettre depuis un Timer dans le BLoC, cela crasherait. Le widget gère le Timer et dispatche `LocalAuthLockExpired` à la fin.
- **`flutter_secure_storage` nécessite un full rebuild** : après l'ajout du plugin (pas juste hot restart). Si `MissingPluginException` : arrêter l'app et relancer avec `flutter run`.
- **Permissions Android** : `USE_BIOMETRIC` est requis pour Android 9+. Sans cette permission dans `AndroidManifest.xml`, `canCheckBiometrics` retourne `false` silencieusement.

## Critères d'acceptation couverts
- [x] Appareil avec biométrie → invite automatique au démarrage → succès → tableau de bord en < 2s
- [x] Appareil sans biométrie → fallback silencieux vers écran PIN (pas d'erreur affichée)
- [x] 3 échecs biométriques → bascule vers PIN (la biométrie échoue → `LocalAuthPinRequired`)

## Décisions techniques
- **`local_auth` plutôt qu'un SDK custom** : package officiel Flutter, maintenu par Google, gère Face ID et empreinte de manière unifiée.
- **Biométrie `biometricOnly: true`** : on force l'empreinte/Face ID sans fallback PIN système Android — le fallback PIN est géré par notre propre interface.
- **`stickyAuth: true`** : si l'utilisateur quitte l'app pendant la demande biométrique (appel entrant), l'invite reste active au retour.
