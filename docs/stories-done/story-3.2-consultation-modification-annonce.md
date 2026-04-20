# Story 3.2 — Consultation et modification d'une annonce (Flutter)

**Date:** 2026-04-20
**Status:** ✅ Complète

## Résumé
Implémentation de la liste des annonces du voyageur connecté ("Mes trajets") et de l'écran de détail avec modification. Les annonces affichent leur statut et le nombre de demandes reçues. La modification réutilise le formulaire de création pré-rempli et est bloquée côté backend si des bids sont déjà acceptés (HTTP 409).

## Fichiers créés
- `lib/features/matching/presentation/screens/announcement_list_screen.dart` — Liste paginée des annonces du voyageur avec statuts colorés et compteur de bids.
- `lib/features/matching/presentation/screens/announcement_detail_screen.dart` — Détail d'une annonce avec bouton de modification conditionnel.

## Fichiers modifiés
- `lib/features/matching/bloc/announcement_event.dart` — Ajout de `AnnouncementListRequested`, `AnnouncementDetailRequested`, `AnnouncementUpdateRequested`.
- `lib/features/matching/bloc/announcement_state.dart` — Ajout de `AnnouncementListLoaded`, `AnnouncementDetailLoaded`, `AnnouncementUpdated`.
- `lib/features/matching/bloc/announcement_bloc.dart` — Ajout des handlers `_onListRequested`, `_onDetailRequested`, `_onUpdateRequested`. Gestion spécifique de l'erreur HTTP 409 pour afficher le message métier.
- `lib/features/matching/data/datasources/announcement_remote_datasource.dart` — Ajout de `getMyAnnouncements`, `getAnnouncementDetail`, `updateAnnouncement`.
- `lib/features/matching/data/repositories/announcement_repository.dart` — Ajout des méthodes correspondantes.
- `lib/app/router.dart` — Ajout de `/announcements` (liste), `/announcements/:id` (détail), `/announcements/:id/edit` (modification).
- `lib/features/matching/presentation/screens/create_announcement_screen.dart` — Gestion du mode édition via `widget.announcement` optionnel.

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur — Liste
1. L'utilisateur navigue vers `/announcements`.
2. `AnnouncementListScreen.initState` déclenche `AnnouncementListRequested`.
3. Le BLoC émet `AnnouncementLoading` → spinner affiché.
4. `GET /api/v1/announcements/my` retourne la liste paginée (page 0, taille 20).
5. `AnnouncementListLoaded` émis → `ListView.builder` affiche les cards.
6. Chaque card affiche : corridor, date, capacité disponible, statut coloré, nombre de demandes reçues.
7. Tap sur une card → `context.push('/announcements/${item.id}')`.
8. FAB `+` → `context.push('/announcements/create')`.
9. Pull-to-refresh → `AnnouncementListRequested` redéclenché.

### Vue d'ensemble du flux utilisateur — Détail et modification
1. `AnnouncementDetailScreen.initState` déclenche `AnnouncementDetailRequested(id)`.
2. `GET /api/v1/announcements/{id}` retourne le détail.
3. `AnnouncementDetailLoaded` émis → affichage corridor, date, capacité, prix, compteur de bids.
4. Le bouton "Modifier" est visible uniquement si `status == 'ACTIVE'` ET `bidsCount == 0`. S'il y a des bids, le bouton est masqué.
5. Tap "Modifier" → `context.push('/announcements/${id}/edit', extra: announcement)`.
6. `CreateAnnouncementScreen` reçoit l'annonce en paramètre, pré-remplit le formulaire.
7. Submit → `AnnouncementUpdateRequested` → `PUT /api/v1/announcements/{id}`.
8. Succès → `AnnouncementUpdated` → SnackBar vert + `context.go('/announcements')`.
9. HTTP 409 → `AnnouncementError` avec message fixe "Modification impossible : des colis sont déjà acceptés pour ce trajet".

### BLoC : events et states
- **`AnnouncementListRequested`** — aucun paramètre, déclenché dans `initState` et sur pull-to-refresh.
- **`AnnouncementDetailRequested(id)`** — déclenché dans `initState` avec l'`id` de la route.
- **`AnnouncementUpdateRequested`** — transporte l'`id` + tous les champs du formulaire.
- **`AnnouncementListLoaded(announcements)`** — liste chargée, `ListView.builder` se reconstruit.
- **`AnnouncementDetailLoaded(announcement)`** — détail chargé, widgets conditionnels calculés.
- **`AnnouncementUpdated(announcement)`** — la modification a réussi, `CreateAnnouncementScreen` navigue vers la liste.

### Appels API
- **GET `/api/v1/announcements/my?page=0&size=20`** — retourne `{ content: [...], totalPages, ... }`. Seul `content` est utilisé côté Flutter.
- **GET `/api/v1/announcements/{id}`** — retourne un `AnnouncementResponse` complet avec `bidsCount`.
- **PUT `/api/v1/announcements/{id}`** — même body que le POST de création. Retourne HTTP 409 si une bid est acceptée.

### Pièges et points d'attention
- **`bidsCount` nullable** : le champ est `int?` dans `AnnouncementModel`. La condition `canEdit` utilise `(bidsCount ?? 0) == 0` pour éviter un `false` inattendu si le backend ne retourne pas ce champ.
- **État BLoC partagé** : `AnnouncementBloc` est fourni en global dans `MultiBlocProvider` (app.dart). Cela signifie que l'état persiste entre les navigations. Quand `AnnouncementListScreen` est reconstruit après une création ou modification, `initState` redéclenche `AnnouncementListRequested` pour rafraîchir — c'est le comportement attendu.
- **Navigation après modification** : `context.go('/announcements')` remplace la stack de navigation. L'utilisateur ne peut pas revenir au formulaire d'édition avec le bouton retour après une modification réussie. C'est intentionnel.
- **Route `/announcements/:id` vs `/announcements/create`** : GoRouter résout les routes dans l'ordre déclaré. La route `/announcements/create` doit être déclarée AVANT `/announcements/:id` pour ne pas être interprétée comme un id valant "create".
- **Passage de l'annonce en `extra`** : `/announcements/:id/edit` reçoit l'objet `AnnouncementModel` via `state.extra`. Si l'utilisateur arrive sur cette route par deep link (sans passer par le détail), `extra` sera null et le formulaire sera vide (mode création). À surveiller si on active les deep links sur cette route.

## Critères d'acceptation couverts
- [x] Given un voyageur ayant 2 annonces, When il consulte "Mes trajets", Then ses 2 annonces s'affichent avec statut et nombre de demandes, et les annonces des autres voyageurs n'apparaissent pas (`GET /my` filtre par utilisateur connecté côté backend).
- [x] Given une annonce sans bid acceptée, When le voyageur modifie la capacité, Then la modification est sauvegardée et visible.
- [x] Given une annonce avec au moins un bid accepté, When le voyageur tente de modifier, Then le message "Modification impossible : des colis sont déjà acceptés pour ce trajet" s'affiche (HTTP 409 parsé dans le BLoC).

## Décisions techniques
- **Réutilisation de `CreateAnnouncementScreen`** pour la modification : le formulaire est identique à la création. Passer l'`AnnouncementModel` en paramètre optionnel permet de gérer les deux modes sans dupliquer le code.
- **Gestion du 409 dans le BLoC** : la `DioException` est inspectée dans `_onUpdateRequested` pour distinguer le 409 des autres erreurs et afficher un message métier précis. Les autres erreurs affichent le message brut.
- **Bouton "Modifier" conditionnel** : le bouton n'est rendu que si `canEdit == true`. Cette décision évite de naviguer vers le formulaire pour constater ensuite que la modification est refusée — l'UX est plus directe.
