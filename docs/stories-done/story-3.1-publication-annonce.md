# Story 3.1 — Publication d'une annonce de trajet (Flutter)

**Date:** 2026-04-20
**Status:** ✅ Complète

## Résumé
Implémentation de la fonctionnalité permettant à un voyageur (KYC-vérifié) de publier une annonce de trajet. Le formulaire inclut les villes de départ et d'arrivée (corridors MVP), la date de départ, la capacité disponible (slider 1–30 kg, pas de 0.5 kg) et le prix par kg.

## Fichiers créés
- `lib/features/matching/data/models/announcement_model.dart` — Modèle de données de l'annonce avec sérialisation JSON via `json_serializable`.
- `lib/features/matching/data/models/announcement_model.g.dart` — Fichier généré par `build_runner` pour la sérialisation.
- `lib/features/matching/data/datasources/announcement_remote_datasource.dart` — Datasource gérant l'appel API `POST /api/v1/announcements`.
- `lib/features/matching/data/repositories/announcement_repository.dart` — Repository faisant le pont entre la datasource et le BLoC.
- `lib/features/matching/bloc/announcement_event.dart` — Events du BLoC matching.
- `lib/features/matching/bloc/announcement_state.dart` — States du BLoC matching.
- `lib/features/matching/bloc/announcement_bloc.dart` — State management pour la création (et la liste/détail/modification) des annonces.
- `lib/features/matching/presentation/screens/create_announcement_screen.dart` — Écran formulaire de création et d'édition, respectant le design system dony.

## Fichiers modifiés
- `lib/app/router.dart` — Ajout des routes `/announcements/create` (avec redirect KYC), `/announcements/:id`, `/announcements/:id/edit`, `/announcements`.
- `lib/core/di/injection.dart` — Enregistrement de `AnnouncementRemoteDatasource`, `AnnouncementRepository`, `AnnouncementBloc` via GetIt.
- `lib/app/app.dart` — Ajout de `BlocProvider<AnnouncementBloc>` dans le `MultiBlocProvider` global (correction bug : le BLoC n'était pas fourni à l'arbre, ce qui causait un crash à l'ouverture des écrans matching).

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur
1. L'utilisateur (voyageur) navigue vers `/announcements/create`.
2. Le `GoRouter` vérifie dans l'`AuthState` si `isKycVerified` est `true`. Si non, il redirige vers `/kyc`.
3. L'utilisateur remplit le formulaire et appuie sur "Publier mon trajet".
4. Validation client-side : ville sélectionnée, départ ≠ arrivée, date obligatoire, prix > 0.
5. Le `AnnouncementBloc` reçoit `AnnouncementCreateRequested`.
6. Le BLoC émet `AnnouncementLoading` → l'UI désactive le bouton et affiche un spinner.
7. Le repository appelle `POST /api/v1/announcements` via Dio.
8. Succès → `AnnouncementCreated` émis → SnackBar vert + `context.go('/announcements')`.
9. Erreur → `AnnouncementError` → SnackBar rouge avec le message.

### BLoC : events et states
- **Events** :
  - `AnnouncementCreateRequested` — déclenché au submit du formulaire (création).
  - `AnnouncementUpdateRequested` — déclenché au submit du formulaire (édition), transporte l'`id` en plus.
  - `AnnouncementListRequested` — déclenché dans `initState` de `AnnouncementListScreen`.
  - `AnnouncementDetailRequested` — déclenché dans `initState` de `AnnouncementDetailScreen`.
- **States** :
  - `AnnouncementInitial` — état initial.
  - `AnnouncementLoading` — pendant tout appel API.
  - `AnnouncementCreated` — succès de la création.
  - `AnnouncementUpdated` — succès de la modification.
  - `AnnouncementListLoaded` — liste chargée avec succès.
  - `AnnouncementDetailLoaded` — détail chargé avec succès.
  - `AnnouncementError` — échec avec message.

### Écran CreateAnnouncementScreen
- Stateful pour les champs de formulaire locaux (`_departureCity`, `_arrivalCity`, `_departureDate`, `_availableKg`, `_priceController`). Ce `setState` est intentionnel : il gère uniquement l'état de l'UI du formulaire, pas l'état métier.
- Accepte un paramètre optionnel `announcement` : si fourni, le formulaire est pré-rempli et envoie un `AnnouncementUpdateRequested` (mode édition).
- Après succès (création ou modification), navigue vers `/announcements` via `context.go`.

### Appels API
- **POST `/api/v1/announcements`** — body :
  ```json
  {
    "departureCity": "Paris",
    "arrivalCity": "Dakar",
    "departureDate": "2026-05-15",
    "availableKg": 10.5,
    "pricePerKg": 5.0
  }
  ```
- La date est formatée `yyyy-MM-dd` (type `LocalDate` côté Spring Boot) dans la datasource via `DateFormat('yyyy-MM-dd').format(departureDate)`.

### Pièges et points d'attention
- **`AnnouncementBloc` doit être dans `MultiBlocProvider`** (app.dart) — sans ça, `context.read<AnnouncementBloc>()` lance une exception. Bug corrigé le 2026-04-20.
- La vérification `isKycVerified` est lue depuis `AuthBloc`. Si l'AuthState n'est pas à jour après une vérification KYC réussie, le redirect KYC peut être déclenché à tort.
- Le slider utilise `divisions: 58` pour un pas de 0.5 kg (min=1, max=30). Un `divisions: 29` donnerait un pas de 1 kg.
- `availableKg` est envoyé comme `double` dans le JSON. Spring Boot le reçoit en `BigDecimal`.

## Critères d'acceptation couverts
- [x] Given un voyageur `kycStatus = VERIFIED`, When il soumet le formulaire, Then l'annonce est créée avec `status = ACTIVE` et il est redirigé vers la liste.
- [x] Given un voyageur `kycStatus = PENDING`, When il accède à `/announcements/create`, Then il est redirigé vers `/kyc`.
- [x] Given un formulaire sans date, When soumis, Then le message "La date de départ est obligatoire" s'affiche et l'API n'est pas appelée.

## Décisions techniques
- **Formulaire partagé création/édition** : `CreateAnnouncementScreen` reçoit un `AnnouncementModel?` optionnel. Cela évite de dupliquer le formulaire et garantit que toute modification du formulaire s'applique aux deux modes.
- **Guard KYC dans GoRouter** : le `redirect` est sur la route plutôt que dans le BLoC ou le widget, pour centraliser la logique d'accès dans le router.
- **`AnnouncementBloc` en `factory` dans GetIt** : une nouvelle instance est créée à chaque `BlocProvider`. Cela évite que l'état d'une session précédente persiste à la réouverture de l'écran.
