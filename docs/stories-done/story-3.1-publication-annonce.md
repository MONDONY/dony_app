# Story 3.1 — Publication d'une annonce de trajet (Flutter)

**Date:** 2026-04-20
**Status:** ✅ Complète

## Résumé
Implémentation de la fonctionnalité permettant à un voyageur (KYC-vérifié) de publier une annonce de trajet. Le formulaire inclut les villes de départ et d'arrivée, la date, la capacité et le prix par kg.

## Fichiers créés
- `lib/features/matching/data/models/announcement_model.dart` — Modèle de données de l'annonce, gérant la sérialisation JSON.
- `lib/features/matching/data/datasources/announcement_remote_datasource.dart` — Datasource gérant l'appel API `POST /api/v1/announcements`.
- `lib/features/matching/data/repositories/announcement_repository.dart` — Repository faisant le pont entre la datasource et le BLoC.
- `lib/features/matching/bloc/announcement_bloc.dart` — State management pour la création de l'annonce avec les events et states associés.
- `lib/features/matching/presentation/screens/create_announcement_screen.dart` — Écran contenant le formulaire de création respectant le design system Dony.

## Fichiers modifiés
- `lib/app/router.dart` — Ajout de la route `/announcements/create` avec un redirect vers KYC si le `kycStatus` n'est pas vérifié.
- `lib/core/di/injection.dart` — Enregistrement des dépendances de la feature Matching via GetIt.

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur
1. L'utilisateur (voyageur) accède à `/announcements/create`.
2. Le `GoRouter` vérifie dans l'`AuthState` si `isKycVerified` est true. Si non, il redirige vers `/kyc`.
3. L'utilisateur remplit le formulaire et appuie sur "Publier mon trajet".
4. Le `AnnouncementBloc` reçoit l'event `AnnouncementCreateRequested`.
5. Le BLoC émet `AnnouncementLoading`, et l'UI affiche un spinner sur le bouton.
6. Le `AnnouncementRepository` effectue la requête POST via Dio.
7. Si succès, `AnnouncementCreated` est émis, une notification "Annonce publiée" apparaît et on redirige vers `/announcements`. En cas d'erreur, un `SnackBar` rouge s'affiche.

### BLoC : events et states
- **Events** : 
  - `AnnouncementCreateRequested` : déclenché au submit du formulaire avec les paramètres de l'annonce.
- **States** : 
  - `AnnouncementInitial` : État initial.
  - `AnnouncementLoading` : Pendant l'appel API.
  - `AnnouncementCreated` : Succès de l'API.
  - `AnnouncementError` : Échec avec message.

### Écrans et widgets clés
- **CreateAnnouncementScreen** : 
  - Affiche un formulaire dynamique (Dropdowns, DatePicker avec Theme custom, Slider et InputText).
  - Écoute `AnnouncementBloc` pour réagir aux états de création.
  - Valide les données côté client (Prix > 0, Date requise) avant l'envoi API.

### Appels API
- **POST `/api/v1/announcements`** avec le body suivant :
  ```json
  {
    "departureCity": "Paris",
    "arrivalCity": "Dakar",
    "departureDate": "2026-04-21",
    "availableKg": 10.0,
    "pricePerKg": 5.0
  }
  ```

### Pièges et points d'attention
- La vérification du `kycStatus` est couplée à `AuthBloc`. Si l'état KYC change sans que l'`AuthState` soit mis à jour, l'accès peut être erronément bloqué ou autorisé.
- La date formatée à envoyer à l'API (`yyyy-MM-dd`) doit respecter la forme attendue par `LocalDate` en Java. Le formatage se fait dans la remote datasource.
- `availableKg` est un paramètre double dans le form UI, mappé par Flutter mais envoyé et traité en BigDecimal côté Spring Boot.

## Critères d'acceptation couverts
- [x] Given un voyageur avec `kycStatus = VERIFIED`, When il remplit et soumet le formulaire, Then l'annonce est créée en base et redirigé.
- [x] Given un voyageur avec `kycStatus = PENDING`, When il tente d'accéder, Then il est redirigé vers l'écran KYC.
- [x] Given un formulaire sans date, When validé, Then erreur côté UI.

## Décisions techniques
- Utilisation de `GoRouter` redirect property pour intercepter l'accès à la route de création en fonction de l'état d'authentification KYC.
- Le statut des annonces par défaut est géré par Spring Boot lors de la création pour garantir l'intégrité de la DB, le mobile ne l'envoie pas.
