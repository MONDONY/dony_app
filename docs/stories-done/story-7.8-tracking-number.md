# Story 7.8 — Numéro de suivi court DON-XXXXXX (Flutter)

**Date:** 2026-04-26
**Status:** ✅ Complète

## Résumé
Affichage du numéro de suivi `DON-XXXXXX` dans la fiche bid avec bouton copier, et nouvel écran de recherche publique accessible depuis l'onglet Suivi — permettant aux destinataires (sans l'app) de connaître le statut de leur colis.

## Fichiers créés
- `features/tracking/data/models/tracking_search_model.dart` — DTO de la réponse `GET /tracking/search`
- `features/tracking/presentation/screens/tracking_search_screen.dart` — écran de recherche par numéro

## Fichiers modifiés
- `features/matching/data/models/bid_model.dart` — champ `String? trackingNumber` ajouté
- `features/matching/data/models/bid_model.g.dart` — fromJson/toJson mis à jour manuellement
- `features/tracking/data/tracking_repository.dart` — méthode `searchByTrackingNumber()`
- `features/tracking/bloc/tracking_event.dart` — event `TrackingSearchRequested`
- `features/tracking/bloc/tracking_state.dart` — states `TrackingSearchLoading/Loaded/Error`
- `features/tracking/bloc/tracking_bloc.dart` — handler `_onSearchRequested`
- `features/matching/presentation/screens/bid_detail_screen.dart` — carte `_TrackingNumberCard`
- `app/router.dart` — route `/tracking/search` + hub `_TrackingHubScreen` sur l'onglet Suivi

## Comment ça fonctionne

### Flux utilisateur — affichage du numéro dans bid detail

1. L'expéditeur ouvre un bid ACCEPTED → `BidDetailScreen` reçoit un `BidModel` avec `trackingNumber` non null
2. `_TrackingNumberCard` s'affiche entre la carte corridor et les détails du trajet
3. Le bouton copier appelle `Clipboard.setData()` et affiche un snackbar 2 secondes
4. Le destinataire peut ensuite taper ce numéro sur `GET /tracking/search` (web ou app)

### Flux utilisateur — recherche par numéro

1. L'utilisateur ouvre l'onglet Suivi → `_TrackingHubScreen` avec un bouton "Rechercher par numéro"
2. `context.push('/tracking/search')` → `TrackingSearchScreen` avec son propre `TrackingBloc`
3. L'utilisateur saisit `DON-XXXXXX` et appuie sur Rechercher
4. BLoC émet `TrackingSearchLoading` puis appelle `_repository.searchByTrackingNumber()`
5. Si succès → `TrackingSearchLoaded` → `_TrackingResultCard` affiche corridor + badge statut + timeline
6. Si erreur (404) → `TrackingSearchError` → bandeau rouge avec message

### BLoC — transitions

```
TrackingSearchRequested
  → TrackingSearchLoading
  → TrackingSearchLoaded(result)   // succès
  → TrackingSearchError(message)   // 404 ou réseau
```

### Écrans — ce qu'ils affichent

**`_TrackingNumberCard`** (dans BidDetailScreen) :
- Icône camion + numéro en bold (letterSpacing 2) + bouton copier
- Visible uniquement si `bid.trackingNumber != null`

**`TrackingSearchScreen`** :
- Champ texte (textCapitalization.characters pour forcer majuscules)
- Bouton "Rechercher" + onSubmitted sur le champ
- Résultat : carte avec gradient bleu (corridor), badge statut coloré, timeline 5 étapes

**`_TrackingHubScreen`** (onglet Suivi) :
- Écran simple avec CTA vers `/tracking/search`
- Servira de hub pour les futures features Epic 7 (scanner QR, historique)

### Appels API
- `GET /tracking/search?number={DON-XXXXXX}` — sans token (public), réponse `TrackingSearchResponse`
- Erreur 404 → `DioException` catchée → `TrackingSearchError` avec message utilisateur

### Pièges et points d'attention
- **`bid_model.g.dart` mis à jour manuellement** : `build_runner` n'a pas été relancé. Si on ajoute d'autres champs à `BidModel` à l'avenir, relancer `flutter pub run build_runner build --delete-conflicting-outputs` pour regénérer le fichier entier et ne pas perdre `trackingNumber`.
- **`TrackingBloc` partagé** : le même BLoC gère les états QR et les états Search. Ouvrir un QR puis revenir et chercher par numéro dans la même instance peut produire un état inattendu. Dans la pratique, `TrackingSearchScreen` crée sa propre instance via `getIt<TrackingBloc>()`.
- **L'onglet Suivi** (`/tracking`) est maintenant `_TrackingHubScreen` — pas de BLoC injecté à ce niveau, le BLoC est créé uniquement dans la sous-route `/tracking/search`.

## Critères d'acceptation couverts
- [x] Numéro `DON-XXXXXX` visible dans la fiche bid (sender et traveler)
- [x] Bouton copier → Clipboard + snackbar de confirmation
- [x] Écran de recherche accessible depuis l'onglet Suivi
- [x] Timeline visuelle avec les 5 étapes (`PENDING` → `DELIVERED`)
- [x] États Loading / Error gérés proprement via BLoC
- [x] Pas de `setState` — BLoC uniquement. Pas de `Navigator.push` — GoRouter uniquement

## Décisions techniques
- **Timeline inline** dans le résultat plutôt qu'un écran dédié : réduit les navigations pour une info passive (le destinataire veut juste voir "en transit" ou "livré").
- **`textCapitalization.characters`** sur le champ de saisie : force les majuscules iOS/Android sans imposer une transformation manuelle à chaque frappe.
- **`_TrackingHubScreen` défini dans `router.dart`** plutôt qu'un fichier séparé : c'est un wrapper de navigation minimaliste, pas un vrai écran feature. Garder la logique proche du router évite la prolifération de fichiers pour un composant trivial.
