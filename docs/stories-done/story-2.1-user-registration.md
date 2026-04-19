# Story 2.1 — Inscription utilisateur (Flutter)

**Date:** 2026-04-19
**Status:** ✅ Complète

## Résumé
Implémentation du flow complet d'inscription : saisie du numéro de téléphone, vérification OTP via Firebase Phone Auth, sélection des rôles, et création du compte via l'API backend.

## Fichiers créés
- `lib/features/auth/bloc/auth_bloc.dart` — BLoC gérant tout le flow d'authentification
- `lib/features/auth/bloc/auth_event.dart` — events : AuthCheckRequested, AuthSendOtpRequested, AuthPhoneVerified, AuthRegisterRequested, AuthLogoutRequested
- `lib/features/auth/bloc/auth_state.dart` — states : AuthInitial, AuthLoading, AuthOtpSent, AuthOtpVerified, AuthAuthenticated, AuthError
- `lib/features/auth/data/models/user_model.dart` — modèle utilisateur avec fromJson
- `lib/features/auth/data/datasources/auth_remote_datasource.dart` — appels API (register, getProfile)
- `lib/features/auth/data/repositories/auth_repository.dart` — wrapper du datasource
- `lib/features/auth/presentation/screens/phone_auth_screen.dart` — saisie du numéro
- `lib/features/auth/presentation/screens/otp_verification_screen.dart` — saisie du code OTP
- `lib/features/auth/presentation/screens/role_selection_screen.dart` — choix SENDER / TRAVELER

## Fichiers modifiés
- `lib/app/app.dart` — ajout du MultiBlocProvider avec AuthBloc
- `lib/core/di/injection.dart` — enregistrement AuthRemoteDatasource, AuthRepository, AuthBloc
- `lib/features/splash/presentation/splash_screen.dart` — navigation intelligente selon l'état Firebase + backend

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur
1. SplashScreen vérifie que le backend est UP
2. Si Firebase user existe → dispatch AuthCheckRequested → GET /auth/me
   - Succès (compte existe) → /home
   - Échec (pas encore inscrit) → /auth/role avec _pendingPhoneNumber récupéré de Firebase
   - Pas de Firebase user → /auth/phone
3. PhoneAuthScreen → saisie numéro → AuthSendOtpRequested → Firebase verifyPhoneNumber
4. OtpVerificationScreen → saisie code → AuthPhoneVerified → Firebase signInWithCredential
5. RoleSelectionScreen → sélection rôle → AuthRegisterRequested → POST /auth/register
6. AuthAuthenticated émis → navigation vers /kyc

### BLoC : events et states

**Events**
- `AuthCheckRequested` — déclenché par SplashScreen au démarrage pour vérifier l'état d'authentification
- `AuthSendOtpRequested(phoneNumber)` — déclenché par PhoneAuthScreen, lance Firebase verifyPhoneNumber
- `AuthPhoneVerified(verificationId, smsCode)` — déclenché par OtpVerificationScreen après saisie du code
- `AuthRegisterRequested(roles)` — déclenché par RoleSelectionScreen après sélection des rôles
- `AuthLogoutRequested` — déclenché pour déconnecter l'utilisateur

**States**
- `AuthInitial` — état de départ, aucune authentification
- `AuthLoading` — opération en cours (appel Firebase ou API)
- `AuthOtpSent(verificationId, phoneNumber)` — SMS envoyé, attente du code
- `AuthOtpVerified(phoneNumber)` — Firebase authentifié, pas encore inscrit en backend
- `AuthAuthenticated(user)` — inscrit et authentifié, flux terminé
- `AuthError(message)` — erreur, message affiché à l'utilisateur

**Transitions importantes**
- `AuthOtpSent` → OtpVerificationScreen capte le `verificationId` dans initState via BlocListener
- `AuthOtpVerified` → RoleSelectionScreen : le backend n'est pas encore appelé ici
- `AuthAuthenticated` → RoleSelectionScreen navigue vers /kyc
- `AuthInitial` (depuis SplashScreen) → SplashScreen navigue vers /auth/role si Firebase user existe

### Écrans et widgets clés

**SplashScreen**
- Vérifie le backend (`GET /actuator/health`)
- Si UP : dispatch `AuthCheckRequested`, attend le résultat via `authBloc.stream.firstWhere()`
- Navigation : AuthAuthenticated → /home, AuthInitial avec Firebase user → /auth/role, sinon → /auth/phone

**OtpVerificationScreen**
- Écoute `AuthOtpSent` dans initState pour stocker le `verificationId` (arrive via BlocListener)
- Appuyer sur "Valider" → dispatch `AuthPhoneVerified(verificationId, code)`

**RoleSelectionScreen**
- Écoute `AuthAuthenticated` → context.go('/kyc')
- Écoute `AuthError` → affiche un SnackBar rouge

### Appels API
- `POST /api/v1/auth/register` avec `{phoneNumber, roles: ["SENDER"|"TRAVELER"]}` et Bearer token Firebase
- `GET /api/v1/auth/me` pour vérifier si l'utilisateur est déjà inscrit (lors du check au démarrage)
- Les erreurs HTTP sont capturées dans AuthBloc._onRegisterRequested → `_friendlyError()` → AuthError

### Pièges et points d'attention

**Completer pour Firebase verifyPhoneNumber**
`verifyPhoneNumber()` retourne immédiatement, les callbacks (codeSent, verificationFailed, etc.) arrivent plus tard de façon asynchrone. Sans `Completer<void>`, le handler BLoC se termine avant les callbacks → erreur "emit called after handler completed". Le `Completer` maintient le handler en vie jusqu'au premier callback significatif.

**`_pendingPhoneNumber` doit toujours être défini avant register**
`AuthBloc._onRegisterRequested` utilise `_pendingPhoneNumber`. Ce champ est rempli :
- Via `_onSendOtpRequested` (flow normal : saisie du numéro)
- Via `_onCheckRequested` si Firebase user existe mais pas inscrit en backend (flow reprise après crash)
Si on ajoute d'autres chemins vers /auth/role, vérifier que `_pendingPhoneNumber` est toujours défini.

**SplashScreen utilise `authBloc.stream.firstWhere()` (pas BlocListener)**
Pour la navigation, on attend explicitement le résultat de `AuthCheckRequested` via le stream du BLoC. Un `BlocListener` aurait déclenché la navigation immédiatement sur l'état initial `AuthInitial` avant même d'avoir dispatché l'event. Ne pas changer cette approche.

**Firebase Phone Auth nécessite un numéro de test en dev**
Firebase Phone Auth requiert le plan Blaze pour envoyer de vrais SMS. En développement, configurer un numéro de test dans Firebase Console → Authentication → Sign-in method → Phone → "Phone numbers for testing". Le numéro de test actuel est `+33766334898` / code `123456`.

## Critères d'acceptation couverts
- [x] Saisie du numéro → envoi OTP Firebase (avec gestion BILLING_NOT_ENABLED via numéro de test)
- [x] Saisie du code OTP → vérification Firebase → AuthOtpVerified
- [x] Sélection des rôles → appel POST /auth/register → AuthAuthenticated → navigation /kyc
- [x] Au démarrage, si Firebase user existe mais pas inscrit → retour sur /auth/role (pas /home)
- [x] Erreurs affichées en français via SnackBar rouge

## Décisions techniques

**Completer plutôt qu'un StreamSubscription manuel**
Firebase ne fournit pas de Future pour verifyPhoneNumber. Le Completer est la façon la plus simple de "bridger" l'API callback vers une API async/await compatible avec le handler BLoC.

**Vérification backend au démarrage via AuthBloc (pas directement en HTTP)**
La SplashScreen délègue la vérification à AuthBloc pour centraliser la logique d'authentification. Cela évite d'avoir du code HTTP dans la couche présentation.

**/auth/role accessible directement depuis SplashScreen**
Plutôt que de repasser par /auth/phone (et redemander l'OTP), on navigue directement vers /auth/role si Firebase user est déjà authentifié. Cela évite une friction inutile à l'utilisateur en cas de crash de l'app après l'OTP mais avant l'inscription.
