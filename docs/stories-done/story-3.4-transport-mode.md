# Story 3.4 — Mode de transport sur les annonces (Flutter)

**Date:** 2026-05-02
**Status:** ✅ Complète

---

## Résumé

Ajout d'un sélecteur de mode de transport sur le formulaire de publication/modification d'annonces (`PLANE` | `CAR` | `TRAIN` | `BUS` | `BOAT` | `OTHER`). L'utilisateur choisit son mode via une rangée de chips (DonyChip) avec icône et label en français. Phase A : la valeur est envoyée au backend, désérialisée à la réception et stockée dans `AnnouncementModel`. Phase B (à venir) utilisera la valeur pour afficher des icônes spécifiques sur la carte des annonces.

---

## Fichiers créés

- `lib/features/matching/data/models/transport_mode.dart` — enum Dart `TransportMode` (6 valeurs) + extension UI (`label`, `icon`) + helpers de wire format (`toWire()`, `transportModeFromWire()` tolérant aux valeurs inconnues).
- `test/features/matching/data/models/transport_mode_test.dart` — tests de l'enum, des helpers wire et de l'extension UI.
- `test/features/matching/data/models/announcement_model_test.dart` — tests de sérialisation/désérialisation du champ `transportMode` dans `AnnouncementModel` (présent, absent, valeur inconnue).
- `test/features/matching/presentation/screens/create_announcement_screen_test.dart` — widget tests du chip picker (rendu des 6 chips, sélection, gating du submit, pré-sélection en mode édition).

## Fichiers modifiés

- `lib/features/matching/data/models/announcement_model.dart` — ajout du champ `transportMode` (nullable `TransportMode?`), avec converters `@JsonKey` qui passent par `transportModeFromWire`/`toWire` pour la sérialisation.
- `lib/features/matching/data/models/announcement_model.g.dart` — régénéré via `build_runner` pour inclure le nouveau champ.
- `lib/features/matching/data/datasources/announcement_remote_datasource.dart` — `createAnnouncement` et `updateAnnouncement` ajoutent `"transportMode": mode.toWire()` (chaîne uppercase) au payload POST/PUT.
- `lib/features/matching/data/repositories/announcement_repository.dart` — propage le paramètre `transportMode` du BLoC vers la datasource.
- `lib/features/matching/bloc/announcement_event.dart` — `AnnouncementCreateRequested` et `AnnouncementUpdateRequested` reçoivent un `TransportMode? transportMode`.
- `lib/features/matching/bloc/announcement_bloc.dart` — les handlers `_onCreateRequested` et `_onUpdateRequested` transfèrent le champ au repository.
- `lib/features/matching/presentation/screens/create_announcement_screen.dart` — ajout du picker chip (DonyChip × 6 dans un `Wrap`) + `ValueNotifier<TransportMode?>` local, validation submit (bouton désactivé tant qu'aucun mode sélectionné), pré-sélection automatique en mode édition.
- `test/features/matching/bloc/announcement_bloc_test.dart` — tests étendus pour vérifier que `transportMode` est bien propagé au repository (création + update).
- `test/features/matching/data/repositories/announcement_repository_test.dart` — tests du passage du champ vers la datasource.
- `test/features/matching/data/datasources/announcement_remote_datasource_test.dart` — tests du payload sortant (`"transportMode": "PLANE"`).

---

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur

**Création** :
1. L'utilisateur ouvre `/announcements/create`.
2. Il remplit les villes, la date, le poids, le prix.
3. Il choisit un mode de transport en tapant sur un des 6 chips (Avion, Voiture, Train, Bus, Bateau, Autre).
4. Le chip sélectionné prend la couleur active (`kGreenLight` background + `kGreenPrimary` border et icône).
5. Le bouton "Publier mon trajet" reste désactivé tant qu'aucun mode n'est sélectionné.
6. Submit → `AnnouncementCreateRequested(..., transportMode: TransportMode.plane)` → BLoC.
7. Le repository appelle `POST /api/v1/announcements` avec `"transportMode": "PLANE"` (uppercase) dans le payload JSON.
8. Le backend renvoie l'`AnnouncementResponse` avec `transportMode: "PLANE"`.
9. La désérialisation passe par `transportModeFromWire("PLANE") → TransportMode.plane`.

**Édition** :
1. L'utilisateur arrive sur `/announcements/{id}/edit` avec une `AnnouncementModel` en `extra`.
2. `initState` du screen lit `widget.announcement.transportMode` et pré-positionne le `ValueNotifier`.
3. Le chip correspondant est marqué comme sélectionné dès l'ouverture.
4. Modification → `AnnouncementUpdateRequested(..., transportMode: ...)` → `PUT /api/v1/announcements/{id}`.

### BLoC : events et states

- **`AnnouncementCreateRequested`** — étendu avec `TransportMode? transportMode` (rendu non-null par la validation submit, mais le type reste nullable pour des raisons de symétrie avec le model).
- **`AnnouncementUpdateRequested`** — idem, transporte aussi l'`id`.
- Aucun nouveau state : on réutilise `AnnouncementCreated`, `AnnouncementUpdated`, `AnnouncementError`.

### Composants UI

- **`DonyChip`** (depuis le design-system dony) — utilisé pour les 6 modes de transport plutôt qu'un chip custom. Aligné avec la règle `CLAUDE.md` : « TOUJOURS utiliser le design system dony, jamais réimplémenter un widget existant ».
- **Icônes Material rounded** :
  - `flight_rounded` → Avion
  - `directions_car_rounded` → Voiture
  - `train_rounded` → Train
  - `directions_bus_rounded` → Bus
  - `directions_boat_rounded` → Bateau
  - `commute_rounded` → Autre
- **Labels FR** : Avion · Voiture · Train · Bus · Bateau · Autre (extension `TransportMode.label`).
- **Layout** : `Wrap(spacing: 8, runSpacing: 8)` — les chips reflowent sur les petits écrans.

### Wire format

- Format JSON : `"transportMode": "PLANE"` (chaîne uppercase qui matche exactement le nom de l'enum Java côté backend).
- Sérialisation : `TransportMode.plane.toWire() == "PLANE"`.
- Désérialisation tolérante :
  - `transportModeFromWire("PLANE") == TransportMode.plane` ✅
  - `transportModeFromWire(null) == null` ✅
  - `transportModeFromWire("BIKE") == null` (valeur inconnue → null, pas de crash) ✅

### Appels API

- **POST `/api/v1/announcements`** — payload :
  ```json
  {
    "departureCity": "Paris",
    "arrivalCity": "Dakar",
    "departureDate": "2026-05-15",
    "availableKg": 10.5,
    "pricePerKg": 5.0,
    "transportMode": "PLANE"
  }
  ```
- **PUT `/api/v1/announcements/{id}`** — même body, mode peut changer.
- **GET** (search/detail/my/bids) — backend renvoie `transportMode: "PLANE"` (parfois `null` ou champ absent en compat ascendante → géré par `transportModeFromWire`).

### Pièges et points d'attention

- **`transportMode` nullable côté Dart** : on a délibérément rendu le champ `TransportMode?` dans `AnnouncementModel` (alors que côté backend il est `NOT NULL`). Cela protège contre :
  - Une réponse backend antérieure à V35 (champ absent du JSON → `null`).
  - Une valeur côté serveur que le client ne connaît pas encore (futur ajout d'un mode → `null` au lieu de crash).
- **Submit gating** : la validation `_transportMode.value != null` est en plus de toutes les autres validations existantes (villes, date, prix). Sans ce check, on enverrait `null` au backend et on prendrait un 422.
- **Pré-sélection en édition** : `widget.announcement.transportMode` peut être `null` si l'annonce a été créée avant V35 — dans ce cas, aucun chip n'est sélectionné par défaut et l'utilisateur doit en choisir un avant de pouvoir submit.
- **`DonyChip` vs `ChoiceChip` Material** : `DonyChip` impose la palette dony (vert primaire + light) ; ne pas le remplacer par `ChoiceChip` ou `FilterChip` Material qui rompent le design system.
- **Couverture sur `create_announcement_screen.dart`** : le fichier dépasse 1100 lignes et a une couverture globale de 68% (dette pré-existante avant la story). Le code spécifiquement ajouté pour le chip picker est entièrement couvert par les nouveaux widget tests. Ne pas considérer le 68% comme une régression de cette story.

## Critères d'acceptation couverts

- [x] **Given** un voyageur KYC-vérifié sur le formulaire de création, **When** il sélectionne un chip de mode de transport, **Then** le chip s'affiche en état actif (couleur dony) et le bouton submit s'active si tous les autres champs sont remplis.
- [x] **Given** un formulaire sans mode de transport sélectionné, **When** tous les autres champs sont remplis, **Then** le bouton "Publier mon trajet" reste désactivé (pas d'appel API).
- [x] **Given** une annonce existante avec `transportMode = TransportMode.car`, **When** l'utilisateur ouvre le formulaire d'édition, **Then** le chip "Voiture" est pré-sélectionné.
- [x] **Given** une réponse backend sans champ `transportMode`, **When** elle est désérialisée, **Then** `AnnouncementModel.transportMode == null` (pas de crash).
- [x] **Given** une réponse backend avec `transportMode: "BIKE"` (valeur inconnue côté Dart), **When** elle est désérialisée, **Then** `AnnouncementModel.transportMode == null` (pas de crash).
- [x] **Given** un submit en création avec `transportMode = TransportMode.plane`, **When** la datasource envoie le payload, **Then** le JSON contient `"transportMode": "PLANE"` (uppercase, conforme au wire format backend).

## Tests

- `flutter test --coverage` → **999 tests, all green** (~6 model + 4 repo/datasource + 3 widget tests ajoutés).
- Couverture sur les fichiers touchés :
  - `lib/features/matching/data/models/transport_mode.dart` — **100%**
  - `lib/features/matching/data/models/announcement_model.dart` — **100%**
  - `lib/features/matching/bloc/announcement_bloc.dart` — **100%**
  - `lib/features/matching/bloc/announcement_event.dart` — **100%**
  - `lib/features/matching/data/repositories/announcement_repository.dart` — **100%**
  - `lib/features/matching/data/datasources/announcement_remote_datasource.dart` — **92.5%**
  - `lib/features/matching/presentation/screens/create_announcement_screen.dart` — **68%** (dette pré-existante : fichier de 1100+ lignes ; le code du chip picker ajouté par cette story est intégralement couvert).

## Décisions techniques

- **`DonyChip` (design-system) plutôt qu'un chip custom** : règle `CLAUDE.md` impose le réemploi systématique des composants du design-system dony. Réimplémenter un chip aurait dupliqué la logique d'état actif/inactif et le styling.
- **`ValueNotifier<TransportMode?>` plutôt que `setState`** : cohérent avec le reste du formulaire `CreateAnnouncementScreen` qui utilise déjà des `ValueNotifier` pour les autres champs (date, capacité, etc.). Évite un `setState` global qui rebuilderait toute la page à chaque tap de chip.
- **`TransportMode?` nullable dans `AnnouncementModel`** : defensive deserialization. Le backend garantit `NOT NULL`, mais la nullabilité côté client protège contre les vieux payloads (avant V35) et les futures valeurs inconnues. C'est un pattern commun pour les enums distribués client/serveur.
- **`transportModeFromWire` retourne `null` pour les valeurs inconnues** : plutôt que de throw, on laisse passer un `null`. Cela évite qu'une valeur ajoutée côté backend (futur mode `BIKE` par ex.) crashe les anciennes versions du client.
- **Wire format uppercase** : on suit la sérialisation `EnumType.STRING` de JPA (qui produit le nom Java de l'enum, en uppercase). Toute la chaîne (Dart → JSON → Java) utilise les mêmes chaînes exactes (`PLANE`, `CAR`, ...).
- **Ne pas faire un widget séparé `TransportModePicker`** : le picker est <60 lignes intégrées au formulaire ; un widget séparé aurait ajouté un `StatefulWidget` ou un constructeur avec callback sans gain notable. À reconsidérer si on a besoin du picker dans une autre écran.
