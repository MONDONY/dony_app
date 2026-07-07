# Redesign « Scan & Suivi » — design

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement the plan generated from this spec.

## Contexte

`ScanHubScreen` (`lib/features/tracking/presentation/screens/scan_hub_screen.dart`) est l'écran que le voyageur ouvre pour scanner ses colis à chaque étape (Départ/Transit/Arrivée). État actuel :

- Une seule card « trajet actif » (corridor, date, compteur colis confirmés, barre de progression scans départ)
- 3 chips étape (Départ/Transit/Arrivée) — tap → ouvre le scanner caméra en mode rafale, identifie le colis via le QR scanné
- 2 boutons « OU IDENTIFIER DIRECTEMENT » : Scanner QR (générique) et Numéro (saisie manuelle `DON-XXXXXX`)
- Le trajet affiché vient de `selectScannableTrip()` (`scan_hub_selectors.dart`) : un seul trajet, jamais deux — priorité aux `IN_PROGRESS` (le plus proche par date), sinon `ACTIVE`/`FULL` le plus proche

## Problèmes identifiés (retours utilisateur)

1. **Visuel daté** — cards trop grandes, pas assez soigné
2. **Infos manquantes** :
   - Aucun statut hors-ligne/synchro visible sur cet écran (la queue Hive `offline_queue` existe côté storage — `HiveService.offlineQueue` — mais `tracking_hub_screen.dart` la lit avec un stub `const []`, jamais branchée)
   - Aucune liste des colis du trajet (juste un chiffre, pas de détail)
   - Aucun historique des scans déjà effectués (qui/quand/étape)
3. **Flow inadapté** — écran étape-d'abord alors que l'usage réel est colis-d'abord (voir chaque colis et son statut, agir dessus), et pas de support si plusieurs trajets sont actifs en même temps (`selectScannableTrip` n'en retourne jamais qu'un — le second trajet `IN_PROGRESS` est invisible)

## Objectifs

- Écran colis-d'abord : liste des colis du trajet actif avec leur statut par étape, visible d'un coup d'œil
- Garder un accès rapide « scan en rafale » par étape (usage : scanner plusieurs colis d'affilée à l'embarquement)
- Ajouter un historique chronologique des scans effectués
- Afficher le statut hors-ligne/synchro (bandeau conditionnel, visible seulement s'il y a des scans en attente)
- Supporter plusieurs trajets actifs simultanés (switcher)
- Retirer le bouton « Scanner QR » générique — remplacé par le scan par étape (rafale) et le scan par ligne colis
- Garder la saisie manuelle du numéro (`DON-XXXXXX`), mais directement sur le hub (champ inline), pas derrière une navigation

## Design

### Structure de l'écran (haut → bas)

1. **AppBar** — « Scan & Suivi », inchangé
2. **Switcher trajets** — rangée horizontale scrollable de pills, une par trajet actif (`IN_PROGRESS`/`ACTIVE`/`FULL` scannable). **Masqué entièrement si un seul trajet actif** (cas le plus courant — pas de bruit visuel). Tap une pill → filtre tout ce qui suit sur ce trajet.
3. **Hero compact** — corridor (`Paris → Bamako`), nombre de colis confirmés. Plus de barre de progression départ dédiée (remplacée par les points de progression par colis, cf. section 5).
4. **Bandeau synchro** — conditionnel, visible uniquement si la queue offline contient des scans pour un colis du trajet actif. Ex : « ⚠️ 1 scan en attente de synchro ». Tap → ouvre `OfflineQueueBottomSheet.show()` existant (déjà fonctionnel, juste jamais alimenté).
5. **Scan rapide (3 boutons étape)** — Départ / Transit / Arrivée, inchangé fonctionnellement (route `/tracking/scan/identify` avec `etape` + `focusNumber: false`), juste restylé plus compact.
6. **Champ numéro inline** — `TextField` `DON-XXXXXX` + bouton valider, posé directement sous les boutons étape (pas de navigation pour taper un numéro). Soumission → `TrackingSearchRequested(number)` (même event que l'écran identifier existant). Sur succès, le bid retourné est cherché dans les colis déjà chargés du trajet actif ; l'étape à scanner est déduite automatiquement via `nextRequiredStep(bid)` (même logique que le bouton Scan par ligne) — **pas de sheet de sélection d'étape**, puisque le colis est déjà identifié par son numéro. Navigue directement vers `/tracking/scan/photo` avec `bidId` + étape déduite. Sur échec (numéro inconnu/hors trajets actifs) : message d'erreur inline, même pattern que `TrackingSearchError` dans `scan_identify_screen.dart`.
7. **Liste des colis** — une ligne dense par colis :
   - Numéro DON + nom destinataire
   - 3 points de progression (Départ/Transit/Arrivée : fait/pas fait)
   - Bouton « Scan » compact en bout de ligne → route vers `/tracking/scan/identify` (écran existant, QR **ou** numéro manuel — `ScanIdentifyScreen`) avec `etape` pré-rempli à la **prochaine étape requise** de CE colis précis (pas de sélection d'étape à faire, mais le scan/numéro reste vérifié — pas de bidId préconnu injecté, pour garder la vérification que le colis physique correspond bien)
   - Tap sur la ligne (hors bouton Scan) → navigue vers la fiche colis existante (`context.push('/bids/${bid.id}')`, réutilise la route déjà utilisée par `TripParcelsSection`)
8. **Historique des scans** — section en bas, liste chronologique (plus récent en premier) : heure, nom destinataire, badge étape. Alimentée par le nouvel endpoint backend groupé (cf. Backend).

### États

- **Loading** — inchangé (spinner centré)
- **Empty** (aucun trajet scannable) — inchangé (`_NoTripState`)
- **Error** — inchangé (`_ErrorState`)
- **Loaded, plusieurs trajets actifs** — switcher visible, contenu filtré sur le trajet sélectionné (état local, pas de rechargement réseau au changement de pill — toutes les données des trajets actifs sont chargées une fois)
- **Loaded, colis vide** (trajet sans colis confirmé — edge case rare mais possible juste après acceptation) — liste vide avec un message inline, pas d'empty state plein écran (le reste de l'écran — switcher, boutons étape — reste utile)

## Architecture

### Frontend

**`scan_hub_selectors.dart`** :
- `selectScannableTrip()` → renommé `selectScannableTrips()`, retourne `List<AnnouncementModel>` (tous les trajets `IN_PROGRESS`/`ACTIVE`/`FULL`, triés par date puis statut `IN_PROGRESS` en premier) au lieu d'un seul
- Nouveau : `String nextRequiredStep(BidModel bid)` — dérive la prochaine étape à scanner à partir du statut du bid (réutilise `_confirmedStatuses`/`_departedStatuses`, étend pour distinguer Transit/Arrivée si le statut le permet — vérifier les valeurs de statut disponibles côté `BidModel` avant l'implémentation, potentiel besoin d'un statut `IN_TRANSIT` vs `ARRIVED` distinct)

**`scan_hub_cubit.dart`** :
- `ScanHubLoaded` gagne `trips: List<AnnouncementModel>`, `selectedTripId: String`, `bidsByTrip: Map<String, List<BidModel>>`, `scanHistory: List<ScanHistoryEntry>` (nouveau modèle, cf. Backend)
- Nouvelle méthode `selectTrip(String tripId)` — change `selectedTripId` sans recharger le réseau (les données de tous les trajets actifs sont chargées ensemble au `load()`)
- `load()` appelle en plus le nouvel endpoint historique groupé, une fois par trajet actif (ou un seul appel multi-trajets si l'endpoint le permet — à trancher en phase d'implémentation selon la forme de l'endpoint)

**Bandeau synchro** :
- Lire `HiveService.offlineQueue` (déjà ouvert au démarrage), filtrer les entrées `OfflineScanEntry` dont `bidId` appartient à un bid du trajet sélectionné, non `synced`
- Mapper vers `OfflineScanItem` (type déjà utilisé par `OfflineQueueBottomSheet`) pour réutiliser le bottom sheet existant tel quel

**Nouveaux widgets** (`scan_hub_screen.dart`, remplacent `_TripHeroCard`/`_EtapesSection`/`_QuickActionsSection` existants) :
- `_TripSwitcher` (pills, masqué si `trips.length <= 1`)
- `_TripHeroCompact` (remplace `_TripHeroCard`, plus de barre de progression départ)
- `_SyncBanner` (conditionnel)
- `_QuickScanSteps` (remplace `_EtapesSection`, retire le texte d'aide sur la photo obligatoire — redondant une fois qu'on voit le badge photo directement dans le flow de scan)
- `_NumberEntryField` (nouveau) — `TextField` + submit, `StatefulWidget` (contrôleur local). Émet `TrackingSearchRequested(number)` sur `TrackingBloc` (déjà utilisé par `scan_identify_screen.dart`, même bloc partagé). Le hub doit donc être wrappé dans un `BlocProvider<TrackingBloc>`/écouter son state (`BlocListener` sur `TrackingSearchLoaded`/`TrackingSearchError`) pour réagir à la résolution — pattern à copier depuis `_handleSearchLoaded` de `scan_identify_screen.dart`, adapté pour résoudre l'étape via `nextRequiredStep()` sur le bid trouvé dans `bidsByTrip[selectedTripId]` au lieu d'ouvrir `_EtapePickerSheet` (qui est private à `scan_identify_screen.dart`, non réutilisable depuis le hub — de toute façon inutile ici puisque l'étape se déduit automatiquement)
- `_ColisListSection` (nouveau, remplace le compteur seul)
- `_ColisRow` (nouveau, ligne dense + bouton Scan)
- `_ScanHistorySection` (nouveau)

**Supprimés** : `_QuickActionsSection`, `_QuickBtn` (bouton Scanner QR générique — le bouton Numéro est remplacé par `_NumberEntryField`, inline plutôt qu'une navigation)

### Backend

**Nouveau endpoint** : `GET /tracking/announcements/{announcementId}/events` (package `com.dony.api.tracking`)
- `BidEntity.announcementId` et `TrackingEventEntity.bidId` sont des colonnes UUID brutes (pas de relation JPA `@ManyToOne`) — pas de requête dérivée à travers une relation possible.
- Implémentation en 2 requêtes dans `TrackingService` : `bidRepository.findByAnnouncementId(announcementId)` (vérifier que cette méthode existe déjà — sinon l'ajouter) pour obtenir les `bidId`, puis nouvelle méthode `TrackingEventRepository.findByBidIdInOrderByScannedAtDesc(List<UUID> bidIds)`
- Retourne les événements de tous les bids du trajet, triés du plus récent au plus ancien — évite le fan-out N+1 côté client (un appel par colis)
- Vérification ownership : le trajet doit appartenir au voyageur authentifié (même pattern que les autres endpoints `tracking/**`)
- DTO réponse : `donNumber`, `recipientName` (ou nom du destinataire du bid), `eventType` (DEPART/TRANSIT/ARRIVEE), `scannedAt`

## Hors scope (explicite)

- Le support multi-trajets ne change rien à `selectScannableTrip` pour les AUTRES écrans qui pourraient l'utiliser — vérifier en phase d'implémentation si `selectScannableTrip` est appelé ailleurs que `scan_hub_cubit.dart` avant de le renommer/changer sa signature (sinon garder l'ancien nom en wrapper autour du nouveau)
- La queue offline (`HiveService.offlineQueue`) est lue en lecture seule pour le bandeau — pas de changement au mécanisme d'écriture/sync existant (`TrackingBloc`/`OfflineSyncRequested`)
- Pas de refonte de la fiche colis (`/bids/{id}`) — l'écran redirige vers l'existant tel quel
- Pas de pagination sur l'historique des scans (un trajet a rarement plus d'une dizaine de colis × 3 étapes = ~30 événements max, liste simple suffit)

## Tests

- `scan_hub_selectors_test.dart` (existe probablement déjà pour `selectScannableTrip`/`computeScanProgress` — à vérifier et étendre) : couvrir `selectScannableTrips` (plusieurs trajets, tri, cas 0/1/N trajets)
- `scan_hub_cubit_test.dart` : `selectTrip()` change l'état sans appel réseau, `load()` gère l'échec du nouvel endpoint historique sans faire échouer tout l'écran (dégrader gracieusement — historique vide + le reste fonctionne)
- Widget tests `scan_hub_screen_test.dart` : switcher masqué si 1 trajet, visible + filtrant si N, bandeau synchro absent/présent selon la queue, bouton Scan par ligne navigue avec la bonne étape, champ numéro inline → succès navigue direct vers la photo avec l'étape déduite, échec affiche l'erreur inline sans crasher l'écran
- Backend : test d'intégration nouvel endpoint (ownership, tri, plusieurs bids/trajets)
