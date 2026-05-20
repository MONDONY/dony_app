# Design Spec — Redesign Scan Hub Voyageur

**Date:** 2026-05-19  
**Statut:** ✅ Validé  
**Scope:** Flutter uniquement — zéro changement backend

---

## Contexte

Actuellement, tapper l'onglet "Suivi" (index 2 dans la nav bar) en tant que voyageur appelle directement `context.push('/tracking/scan')`, ce qui ouvre immédiatement `QrScannerScreen` avec la caméra active. L'utilisateur n'a aucun contexte et aucun choix.

**Problème :** caméra surprise, pas de contexte du trajet, pas de sélection d'étape avant le scan.

---

## Objectif

Remplacer la navigation directe vers la caméra par un **hub intermédiaire** qui :
1. Contextualise le voyageur (trajet actif, progression des scans)
2. Lui laisse choisir l'**étape** (Départ / Transit / Arrivée) avant d'identifier le colis
3. Impose l'**identification du colis** (QR ou numéro) avant la prise de photo
4. Applique les règles de photo : **obligatoire** sur Départ et Arrivée, **facultative** sur Transit

---

## Changements de navigation

### Avant
```
Tap "Suivi" (voyageur) → context.push('/tracking/scan') → QrScannerScreen (caméra immédiate)
```

### Après
```
Tap "Suivi" (voyageur) → goBranch(2) → ScanHubScreen (/tracking)
```

La nav bar modifie son `onTap` pour l'index 2 : au lieu de `context.push('/tracking/scan')`, elle appelle `onTap(2)` (comme les autres onglets), ce qui route vers `/tracking` → `ScanHubScreen`.

`TrackingHubScreen` est remplacé par `ScanHubScreen` (dédié voyageur). La route `/tracking` existante est réutilisée.

---

## Écrans et flow

### Écran 1 — `ScanHubScreen` (onglet `/tracking`)

**Ce que le voyageur voit :**
- **Hero card trajet actif** : corridor (Paris → Dakar), date, nombre de colis, barre de progression des scans (ex. 1/3 scannés au départ)
- **Grille 3 étapes** : Départ / Transit / Arrivée — chaque carte affiche l'icône, le nom, et un badge photo (`📷 obligatoire` en rouge pour Départ/Arrivée, `📷 optionnelle` en gris pour Transit)
- **Deux raccourcis** en bas : "Scanner QR" (identifie directement) et "Saisir numéro" (DON-XXXXXX)

**Interactions :**
- Tap sur une étape → `ScanIdentifyScreen(etape: etape)`
- Tap "Scanner QR" → `QrScannerScreen` directement (étape déterminée après scan, comme aujourd'hui)
- Tap "Saisir numéro" → `ScanIdentifyScreen(etape: null)` avec focus sur le champ texte

---

### Écran 2 — `ScanIdentifyScreen`

**Paramètres :** `etape` (DEPART | TRANSIT | ARRIVEE | null si accès direct)

**Ce que le voyageur voit :**
- AppBar avec badge de l'étape sélectionnée (si connue)
- **Gros bouton vert** : "Ouvrir le scanner QR" → ouvre `QrScannerScreen`
- Séparateur "OU"
- **Champ texte** DON-XXXXXX (clavier alphanumérique, caps auto)
- **Bouton "Identifier →"** grisé jusqu'à ce qu'un des deux soit actif

**Après identification :**
- QR scanné → `bidId` extrait depuis URL (`/tracking/{bidId}`) → `packageLabel = bidId.substring(0, 8)` → passer à `ScanPhotoScreen`
- Numéro validé → appel `TrackingRepository.searchByTrackingNumber(number)` → retourne `TrackingSearchModel` avec `bidId` + `trackingNumber` → `packageLabel = trackingNumber` → passer à `ScanPhotoScreen`

**Si `etape` est null** (accès via "Scanner QR" direct) : pas de badge étape ; après identification, on montre le sélecteur d'étape (les 3 chips Départ/Transit/Arrivée) avant de continuer.

---

### Écran 3 — `ScanPhotoScreen` (caméra)

**Paramètres :** `bidId`, `etape`, `packageLabel` (ex. "DON-A47C")

> **Note :** `TrackingSearchModel` expose `trackingNumber` mais pas de nom d'expéditeur. `packageLabel` = `trackingNumber` si identifié via numéro, ou `bidId.substring(0, 8)` si identifié via QR (pas de lookup supplémentaire requis en MVP).

**Ce que le voyageur voit :**
- Caméra plein écran
- **Overlay contexte** en haut : pill avec le nom du colis, pill verte avec l'étape
- **Badge photo** : rouge "📷 Photo obligatoire" (Départ/Arrivée) ou orange "📷 Photo optionnelle" (Transit)
- Cadre rectangulaire centré (guides visuels)
- **Bouton "Prendre la photo"** (blanc, toujours visible)
- **Bouton "Passer"** : visible uniquement si `etape == TRANSIT`
- Mention GPS en bas ("📍 Géolocalisation automatique")

**Comportement :**
- GPS capturé silencieusement avant l'ouverture caméra (pattern existant : `Geolocator.getCurrentPosition` avant `ImagePicker`)
- EXIF GPS écrit sur la photo (pattern existant : `_writeGpsExif`)
- Après prise de photo → `ScanConfirmScreen`
- "Passer" (Transit uniquement) → `ScanConfirmScreen` sans photo

---

### Écran 4 — `ScanConfirmScreen`

**Paramètres :** `bidId`, `etape`, `photo?` (XFile), `position?` (Position)

**Ce que le voyageur voit :**
- Badge étape (ex. "🛫 Départ enregistré")
- Carte récap : miniature photo (ou placeholder si Transit sans photo), numéro DON (ou bidId tronqué), étape, tag GPS (pas de nom expéditeur — non disponible dans `TrackingSearchModel`)
- **Bouton "Valider le scan"** (vert, plein) → dispatch `QrScanSubmitRequested` via `TrackingBloc`
- **Bouton "Reprendre la photo"** (outline) → retour à `ScanPhotoScreen`

**Après validation :**
- `QrScanSuccess` → dialog succès (existant) puis retour au hub
- `QrScanQueued` → dialog offline (existant) puis retour au hub
- `QrScanError` → message d'erreur inline

---

## Règles photo

| Étape   | Photo     | Bouton "Passer" | Badge caméra                      |
|---------|-----------|-----------------|-----------------------------------|
| DEPART  | Obligatoire | ❌ absent      | 🔴 "📷 Photo obligatoire"         |
| TRANSIT | Facultative | ✅ présent     | 🟠 "📷 Photo optionnelle"         |
| ARRIVEE | Obligatoire | ❌ absent      | 🔴 "📷 Photo obligatoire"         |

---

## Architecture Flutter

### Nouveaux fichiers à créer

```
lib/features/tracking/presentation/screens/
├── scan_hub_screen.dart          # Remplace TrackingHubScreen pour voyageur
├── scan_identify_screen.dart     # Identification QR ou numéro
├── scan_photo_screen.dart        # Caméra avec contexte colis
└── scan_confirm_screen.dart      # Confirmation avant envoi
```

### Fichiers modifiés

- `lib/app/main_shell.dart` — `_DonyBottomNav` : index 2 voyageur → `onTap(2)` au lieu de `context.push('/tracking/scan')`
- `lib/app/router.dart` — route `/tracking` → `ScanHubScreen` (au lieu de `TrackingHubScreen`)

### BLoC utilisé

`TrackingBloc` existant (inchangé) — les events `QrScanSubmitRequested` et `ConfirmDeliveryRequested` sont réutilisés tels quels.

### Pas de nouveau BLoC

La navigation entre les 4 écrans est gérée par GoRouter (`context.push`) avec passage de paramètres via `extra`. Pas d'état partagé supplémentaire nécessaire.

---

## Routes GoRouter

```
/tracking                          → ScanHubScreen
/tracking/scan/identify            → ScanIdentifyScreen  (extra: {etape?, focusNumber})
/tracking/scan/photo               → ScanPhotoScreen     (extra: {bidId, etape, packageLabel})
/tracking/scan/confirm             → ScanConfirmScreen   (extra: {bidId, etape, photoPath?, gpsLat?, gpsLon?})
```

La route `/tracking/scan` existante (accès direct QR) est conservée pour compatibilité.

---

## Ce qui ne change pas

- `QrScannerScreen` — conservé intact, toujours accessible via `/tracking/scan`
- `TrackingBloc`, `TrackingRepository`, `TrackingEvent`, `TrackingState` — inchangés
- Backend — aucune migration, aucun nouvel event type
- `OfflineQueueBottomSheet`, `TrackingSearchBottomSheet` — inchangés
- `_ScanConfirmSheet` dans `QrScannerScreen` — inchangé (toujours utilisé pour le chemin QR direct)

---

## Critères d'acceptation

- [ ] Taper "Suivi" en tant que voyageur affiche `ScanHubScreen` (pas la caméra directement)
- [ ] Le trajet actif et la progression des scans sont visibles sur le hub
- [ ] Taper "Départ" ou "Arrivée" ouvre `ScanIdentifyScreen` avec le badge correspondant
- [ ] Sur `ScanIdentifyScreen`, le bouton "Identifier" est grisé tant qu'aucune identification n'a eu lieu
- [ ] Après identification, `ScanPhotoScreen` s'ouvre avec le contexte colis en overlay
- [ ] Sur Départ et Arrivée : pas de bouton "Passer", badge rouge "obligatoire"
- [ ] Sur Transit : bouton "Passer" visible, badge orange "optionnelle"
- [ ] Le GPS est capturé avant l'ouverture caméra
- [ ] `ScanConfirmScreen` affiche le récap complet avant l'envoi
- [ ] Les chemins QR direct et saisie numéro fonctionnent tous les deux
- [ ] Les dialogs offline et succès existants s'affichent correctement
- [ ] Tests BLoC existants non cassés
- [ ] Couverture ≥ 90 % sur les nouveaux écrans
