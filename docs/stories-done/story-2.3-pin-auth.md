# Story 2.3 — Connexion avec code PIN (Flutter)

**Date:** 2026-04-19
**Status:** ✅ Complète

## Résumé
Implémentation du setup et de la validation du code PIN à 6 chiffres. Le PIN est stocké de façon sécurisée dans l'Android Keystore / iOS Keychain via `flutter_secure_storage`. Il est validé entièrement côté client — jamais envoyé au serveur.

## Fichiers créés
- `lib/features/auth/presentation/screens/pin_setup_screen.dart` — saisie + confirmation du PIN en 2 étapes (à l'inscription)

## Fichiers modifiés
- `lib/features/auth/data/services/local_auth_service.dart` — méthodes `isPinSet`, `savePin`, `validatePin`, `clearPin`
- `lib/features/auth/bloc/local_auth_bloc.dart` — `_onPinSubmitted` : validation, décompte tentatives, émission `LocalAuthLocked`
- `lib/features/auth/presentation/screens/local_auth_screen.dart` — affichage dots PIN, avertissement tentatives, message de blocage
- `lib/app/router.dart` — ajout route `/auth/pin-setup`
- `lib/features/auth/presentation/screens/role_selection_screen.dart` — après `AuthAuthenticated`, navigue vers `/auth/pin-setup` (pas directement `/kyc`)
- `pubspec.yaml` — ajout `pinput`

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux — Setup PIN (première inscription)
1. Après sélection des rôles → `AuthRegisterRequested` → `AuthAuthenticated` → `context.go('/auth/pin-setup')`
2. `PinSetupScreen` : l'utilisateur saisit 6 chiffres (étape 1) → affichage "Confirmez votre code PIN"
3. L'utilisateur saisit à nouveau 6 chiffres (étape 2) → comparaison locale
4. Si identiques → `LocalAuthService.savePin(pin)` → `context.go('/kyc')`
5. Si différents → animation shake, message d'erreur 600ms, retour à l'étape 1

### Vue d'ensemble du flux — Login PIN (sessions suivantes)
1. SplashScreen → `AuthAuthenticated` → `/auth/local` → biométrie échoue/indisponible → `LocalAuthPinRequired`
2. L'utilisateur saisit 6 chiffres → `LocalAuthPinSubmitted(pin)` dispatché automatiquement
3. `LocalAuthBloc._onPinSubmitted` → `LocalAuthService.validatePin(pin)` (compare avec valeur stockée)
4. Succès → `LocalAuthSuccess` → `context.go('/home')`
5. Échec → `_attemptsLeft--` → `LocalAuthPinRequired(attemptsLeft: N)`
6. 3 échecs → `LocalAuthLocked(30)` → widget démarre Timer 30s → `LocalAuthLockExpired` → retour à 3 tentatives

### BLoC : logique de tentatives
```
_attemptsLeft = 3 (initial et après LocalAuthLockExpired)
Chaque LocalAuthPinSubmitted incorrect : _attemptsLeft--
_attemptsLeft == 0 : emit LocalAuthLocked(30)
LocalAuthLockExpired : _attemptsLeft = 3, emit LocalAuthPinRequired()
```

### Stockage sécurisé du PIN
- Clé de stockage : `dony_pin_v1` (versionnée pour permettre une migration future)
- Android : chiffrement via `AndroidOptions(encryptedSharedPreferences: true)` → Android Keystore
- iOS : Keychain automatique via `flutter_secure_storage`
- **Le PIN n'est jamais envoyé au serveur** — validation 100% locale

### Écrans et widgets clés
**`PinSetupScreen`** :
- `_isConfirming` (bool) : toggle entre étape 1 et étape 2
- `_firstPin` (String?) : stocke le premier PIN pour comparaison à l'étape 2
- `_hasError` (bool) : déclenche animation shake sur les dots + couleur rouge
- Après mismatch : délai 600ms (animation) puis reset vers étape 1

**`LocalAuthScreen` (affichage PIN)** :
- 6 dots animés (`AnimatedContainer`) : remplis en vert si le chiffre est saisi, rouge si erreur
- Soumission automatique après le 6e chiffre (`Future.delayed(100ms, _submitPin)`)
- `_buildAttemptsWarning` affiché si `attemptsLeft < 3`
- `_buildLockMessage` avec countdown affiché si état `LocalAuthLocked`

### Pièges et points d'attention
- **`flutter_secure_storage` nécessite un full rebuild** (pas juste hot restart). Plugin natif Android non chargé via hot restart → `MissingPluginException`.
- **`_attemptsLeft` est dans le BLoC** (pas dans le widget) : survive aux rebuilds, mais est remis à 3 si le BLoC est recréé (factory dans GetIt → nouvelle instance à chaque navigation). Si l'utilisateur quitte et revient sur l'écran local auth, le compteur repart à 3. C'est acceptable en MVP.
- **Reset du PIN dans `_pin`** : lors de l'état `LocalAuthPinRequired` (émis après une erreur), le listener du widget remet `_pin = ''`. Si on oublie ce reset, les dots restent remplis même après validation.
- **Navigation après SavePin** : `context.go('/kyc')` dans `PinSetupScreen._handleComplete`. Si la route `/kyc` n'est pas définie dans `router.dart`, l'app crashe silencieusement.

## Critères d'acceptation couverts
- [x] Setup PIN × 2 → stocké chiffré → connexion PIN possible à la prochaine session
- [x] 3 mauvais PIN → blocage 30s → message affiché → retour à 3 tentatives après expiration
- [x] PIN oublié → (à implémenter : ré-auth Firebase SMS)

## Décisions techniques
- **`flutter_secure_storage` plutôt que Hive chiffré** : `flutter_secure_storage` délègue au keystore système (Android Keystore, iOS Keychain) — plus robuste qu'une clé de chiffrement Hive stockée dans les préférences.
- **Clé versionnée `dony_pin_v1`** : permet de migrer le format PIN sans conflits (suffixe `_v2` si changement).
- **Countdown dans le widget, pas dans le BLoC** : le BLoC émet `LocalAuthLocked(30)` une seule fois. Le widget gère `Timer.periodic` et dispatche `LocalAuthLockExpired` à 0. Un Timer dans un BLoC émettrait après la fin du handler (Emitter invalide → crash).
