# Annonces & demandes urgentes — Design

**Date :** 2026-07-17
**Statut :** Validé (en attente review utilisateur)
**Portée :** Cross-stack — `dony-back` (1 PR) + `dony_app` (1 PR)

---

## 1. Problème & objectif

Permettre aux utilisateurs de repérer et filtrer rapidement les publications dont l'échéance est proche :
- un **trajet** dont le départ est imminent (le voyageur veut remplir ses kg vite),
- une **demande d'envoi** dont la date souhaitée est imminente (l'expéditeur veut envoyer vite).

Livrables : un **badge « 🔥 Urgent »** sur les cartes concernées et un **chip de filtre « Urgent »** dans la recherche qui n'affiche que les publications urgentes.

## 2. Définition de « urgent » (règle métier)

Une publication est **urgente si sa date clé tombe dans les `N` prochains jours** (aujourd'hui inclus) :

| Type | Date clé | Urgent si |
|------|----------|-----------|
| Trajet (annonce) | `departureDate` | `today ≤ departureDate ≤ today + N` |
| Demande d'envoi | `desiredDate` | `today ≤ desiredDate ≤ today + N` |

- **`N` = 3 jours** par défaut.
- **Pas de champ `isUrgent`, pas de case à cocher.** L'urgence est *dérivée* de la date : honnête (fait, non déclaratif), pas d'abus possible, aucune migration DB.
- Bornes exactes : une date == `today + N` **est** urgente ; `today + N + 1` ne l'est **pas**. Une date passée (`< today`) n'est pas urgente (hors périmètre, l'annonce ne devrait plus être active).

### Seuil configurable

Le seuil vit côté backend, surchargeable par variable d'environnement (cohérent avec la variabilisation de `application.yml`) :

```yaml
dony:
  urgency:
    threshold-days: ${DONY_URGENCY_THRESHOLD_DAYS:3}
```

Le front récupère le seuil au démarrage (pour calculer le badge localement) via l'endpoint config.

## 3. Backend (`dony-back`)

### 3.1 Config
- `DonyConfigProperties` : ajouter `urgency().thresholdDays()` (défaut 3).
- Endpoint : `GET /config/urgency-threshold` → `{ "thresholdDays": 3 }` (public, comme `/config/commission-rate`).

### 3.2 Recherche annonces — `GET /announcements`
- Nouveau `@RequestParam(required = false) Boolean urgent`.
- Si `urgent == true` : contraindre la requête à `departureDate BETWEEN today AND today + thresholdDays`.
- Implémentation : réutilise le filtrage par date existant (`departureDateFrom` / `departureDateTo`) au niveau service/repository — quand `urgent` est vrai, on force `from = today`, `to = today + threshold` (sans écraser un filtre de date explicite incompatible : si l'appelant passe déjà une plage, `urgent` la restreint par intersection).

### 3.3 Recherche demandes — `GET /package-requests`
- Nouveau `@RequestParam(required = false) Boolean urgent`.
- Si `urgent == true` : ajouter à la `Specification` existante `desiredDate BETWEEN today AND today + thresholdDays`.

### 3.4 Réponses DTO
- `AnnouncementSearchResponse` et `PackageRequestSearchResponse` : **exposer `urgent` (boolean)** calculé côté serveur, pour que le front badge de façon fiable sans dépendre de son horloge locale ni du fuseau.
- (Le front garde aussi le calcul local via le seuil config comme repli, mais la source de vérité du badge = le champ `urgent` de la réponse.)

### 3.5 Tests back
- `thresholdDays` par défaut = 3 ; surcharge via env.
- Filtre annonces `urgent=true` : date `today+3` incluse, `today+4` exclue, date passée exclue.
- Filtre demandes `urgent=true` : mêmes bornes sur `desiredDate`.
- Champ `urgent` des DTO correct.
- `GET /config/urgency-threshold` renvoie le seuil.

## 4. Frontend (`dony_app`)

### 4.1 Chargement du seuil
- Au démarrage (comme `dony.commission.rate`), charger `thresholdDays` via `IConfigRepository` et le stocker dans un helper (`lib/core/urgency/dony_urgency.dart`) : `int get urgencyThresholdDays` + `setUrgencyThresholdDays(int)` + repli 3.

### 4.2 Badge « 🔥 Urgent »
- Source de vérité : le champ `urgent` renvoyé par l'API (`AnnouncementModel.urgent`, `PackageRequestSearchItem.urgent`). Repli local si absent : `date ≤ today + urgencyThresholdDays`.
- Widget `DonyUrgentBadge` (petit pill rouge `DonyColors.urgencyRed` + « 🔥 Urgent »), placé sur :
  - les cartes trajet (`TravelerCard`),
  - les cartes demande (`PackageRequestListCard`, carrousels near-me),
  - l'écran détail (trajet + demande) — cohérence.

### 4.3 Chip filtre « Urgent »
- Nouveau chip binaire dans `_filterChipsRow` (home_screen), à côté de Colis / Trajets / Toutes dates / Note.
- État : `bool _urgentOnly` dans `_HomeScreenState`.
- **Se combine avec l'onglet courant** :
  - onglet Trajets → `GET /announcements?urgent=true`,
  - onglet Colis → `GET /package-requests?urgent=true`,
  - vue Tout → les deux avec `urgent=true`.
- Passé dans `SearchParams` (annonces) et les params de recherche demandes.
- Markers carte : filtrés de la même façon (les recherches renvoient déjà filtré).
- Le compteur du header (« N résultats ») reflète le résultat filtré serveur.

### 4.4 Feedback à la création
- Formulaire trajet (`create_trip` / `create_announcement`) et formulaire demande (wizard package request) : sous le champ date, si la date choisie ≤ `today + urgencyThresholdDays`, afficher un texte informatif non bloquant : « 🔥 Départ proche — ce trajet sera signalé urgent » / « 🔥 Date proche — cette demande sera signalée urgente ».

### 4.5 Relation avec l'`UrgencyFilter` existant
- Le `UrgencyFilter` granulaire (4 niveaux : `< 3j`, `3–7j`, `7–14j`, `14j+`) du **sheet de filtres avancés** reste inchangé.
- Le nouveau chip « Urgent » est un **raccourci binaire** = équivalent du niveau `veryUrgent` (≤ seuil), mais piloté serveur et couvrant aussi les demandes.
- Pas de conflit : les deux peuvent coexister ; si les deux sont posés, l'intersection s'applique (comportement naturel).

### 4.6 Tests front
- `dony_urgency` : seuil par défaut 3, `setUrgencyThresholdDays` borne les valeurs aberrantes.
- Badge : affiché quand `urgent == true` (API) ou date ≤ seuil (repli) ; masqué sinon (bornes exactes).
- Chip : toggle → `_urgentOnly` → param `urgent` dans la recherche (annonces + demandes selon onglet).
- Feedback création : texte présent/absent selon la date choisie.

## 5. Hors périmètre (YAGNI)

- Pas de champ `isUrgent` explicite ni de case à cocher.
- Pas de notification « nouvelle annonce urgente ».
- Pas de tri par urgence (seulement filtre binaire).
- Pas de refonte du `UrgencyFilter` granulaire.

## 6. Ordre de livraison

1. **PR back** (`dony-back`) : config + param `urgent` sur les 2 endpoints + champ `urgent` DTO + endpoint seuil + tests.
2. **PR front** (`dony_app`) : chargement seuil + badge + chip filtre + feedback création + tests.

(Le front dépend du back pour le champ `urgent` fiable, mais peut fonctionner en repli local si le back n'est pas encore déployé.)
