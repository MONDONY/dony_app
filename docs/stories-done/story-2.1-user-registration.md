# Story 2.1 — Inscription utilisateur (Flutter)

**Date:** 2026-04-19
**Status:** ✅ Complète

## Résumé
Implémentation du flux complet d'inscription : saisie du numéro de téléphone, vérification OTP Firebase, sélection du rôle, appel API backend pour créer le compte.

## Fichiers créés
- `lib/features/auth/data/models/user_model.dart` — modèle utilisateur avec fromJson
- `lib/features/auth/data/datasources/auth_remote_datasource.dart` — appels API register et getProfile
- `lib/features/auth/data/repositories/auth_repository.dart` — repository auth
- `lib/features/auth/bloc/auth_event.dart` — events: AuthSendOtpRequested, AuthPhoneVerified, AuthRegisterRequested, AuthCheckRequested, AuthLogoutRequested
- `lib/features/auth/bloc/auth_state.dart` — states: AuthInitial, AuthLoading, AuthOtpSent, AuthOtpVerified, AuthAuthenticated, AuthError
- `lib/features/auth/bloc/auth_bloc.dart` — BLoC gérant le flux Firebase Phone Auth + appel backend
- `lib/features/auth/presentation/screens/phone_auth_screen.dart` — saisie numéro avec sélection indicatif pays
- `lib/features/auth/presentation/screens/otp_verification_screen.dart` — 6 champs OTP, timer resend 60s
- `lib/features/auth/presentation/screens/role_selection_screen.dart` — sélection SENDER/TRAVELER avec cartes animées

## Fichiers modifiés
- `lib/app/router.dart` — routes /auth/phone, /auth/otp, /auth/role avec vrais screens
- `lib/core/di/injection.dart` — enregistrement AuthRemoteDatasource, AuthRepository, AuthBloc
- `lib/app/app.dart` — MultiBlocProvider avec AuthBloc
- `lib/features/splash/presentation/splash_screen.dart` — navigation auto vers /auth/phone après connexion backend OK ; /home si Firebase user déjà connecté

## Critères d'acceptation couverts
- [x] Firebase envoie un SMS de vérification au numéro saisi (AuthSendOtpRequested)
- [x] Après validation du code SMS, un compte est créé en base de données (AuthPhoneVerified + AuthRegisterRequested)
- [x] Numéro déjà existant → message d'erreur affiché à l'utilisateur
- [x] kycStatus = PENDING → navigation vers /kyc après inscription réussie

## Décisions techniques
- `verificationId` capturé dans `initState` du `OtpVerificationScreen` (état BLoC déjà à `AuthOtpSent` quand l'écran s'ouvre)
- Pays disponibles : France, UK, USA + principaux pays d'Afrique subsaharienne (Sénégal, Côte d'Ivoire, Mali, Cameroun, Gabon, Congo, RD Congo)
- Le numéro local avec zéro initial est normalisé en E.164 automatiquement (ex: 06... → +336...)
- Auto-vérification Android (verificationCompleted) : inscription automatique avec rôles vides → à améliorer si nécessaire
- `AuthOtpVerified.phoneNumber` transmis pour que le BLoC puisse l'utiliser dans `AuthRegisterRequested`
