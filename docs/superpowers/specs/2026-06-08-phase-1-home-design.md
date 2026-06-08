# Phase 1 — Home (carte additive, fin du switch)

**Date :** 2026-06-08 | **Statut :** ✅ Design validé (brainstorming) — en attente du plan d'implémentation
**Fondation :** voir `2026-06-08-navigation-additive-model-foundation.md`

---

## Objectif & gain UX

Supprimer le switch de rôle de la Home et le remplacer par une **carte unifiée additive** : l'expéditeur voit les trajets, le voyageur voit en plus les colis. Aucun « quel mode suis-je ? ». Pur expéditeur : Home identique à aujourd'hui.

## État actuel (pour mémoire)

- `home_screen.dart` rend `_MapSenderView`. Le contenu dépend de `ActiveRoleCubit` :
  - expéditeur → pins = annonces de trajets ; filtres date/note/poids/€-kg/KiloPro/corridors ; carrousel near-me voyageurs ; sheet liste voyageurs.
  - voyageur → pins = demandes de colis ; filtres date range/poids max/taille ; carrousel near-me colis ; sheet liste colis.
- Le pill de switch (`role_mode_pill.dart`) est en overlay haut-gauche, visible si `isTraveler`.

## Design cible

### 1. Carte unifiée additive

- **Pur expéditeur :** la carte montre **uniquement les trajets**. Pin = **emoji type de transport (✈️/🚗/🚆/🚌) + prix/kg**. Identique à aujourd'hui. Aucun élément voyageur.
- **Voyageur :** la carte montre **les deux types de pins** :
  - **📦 + prix fixe** → demande d'envoi d'un expéditeur (ce que le voyageur peut transporter). Tap → faire une offre pour transporter.
  - **✈️/🚗/🚆 + prix/kg** → trajet d'un autre voyageur (le voyageur reste expéditeur, peut envoyer son colis). Tap → faire une offre pour envoyer.
- Devenir voyageur **ajoute** les pins 📦 — c'est l'additif. Pas de bascule, pas de mode.

### 2. Filtre de focus (voyageur uniquement)

- Petit filtre segmenté en haut : **« Tout / 📦 Colis / ✈️ Trajets »**, **défaut = Tout**.
- Ce n'est **pas un mode/rôle** : c'est un filtre d'affichage local à la carte, qui par défaut montre tout → aucun choix forcé.
- **Pilote les filtres détaillés affichés :**
  - focus **Tout** → filtres communs (corridor, date)
  - focus **Colis** → filtres colis (taille, poids max, date range)
  - focus **Trajets** → filtres trajets (note, poids, €/kg, KiloPro)
- **Pur expéditeur :** ce filtre de focus **n'apparaît pas** (il n'a que des trajets à voir).

### 3. Comportements dérivés

- **Mode near-me** (carrousel proximité) : respecte le filtre de focus (Tout/Colis/Trajets).
- **Liste de résultats** (draggable sheet) : respecte le filtre de focus ; en-tête adapte le décompte (« 4 colis · 3 trajets » en Tout, etc.).
- **Actions :** inchangées — tap 📦 → flux d'offre de transport existant ; tap trajet → flux d'offre/bid d'envoi existant.

### 4. Corrections Home incluses (gain UX)

- **États vides *filter-aware* :** distinguer « aucun résultat » de « aucun résultat **avec ces filtres** » + CTA *réinitialiser les filtres*.
- **Retrait du doublon d'offre :** aujourd'hui le voyageur peut faire une offre depuis le carrousel near-me **et** depuis les cartes liste → ne garder qu'un seul chemin cohérent.

### 5. Suppression du switch Home

- Retrait du `role_mode_pill.dart` de la Home (et du widget si plus utilisé ailleurs après Phase 4).
- La Home ne lit plus `ActiveRoleCubit` ; elle se base sur `user.isTraveler` + l'état local du filtre de focus.
- **Le switch du Profil reste** (transitoire, cf. fondation) — il n'impacte plus la Home.

## Inventaire zéro-régression (Home)

Doit rester fonctionnel après Phase 1 :

- **Expéditeur :** carte trajets, tous les filtres trajets (date, note, poids, €/kg, KiloPro, corridors), near-me voyageurs, sheet liste, faire une offre sur un trajet, barre corridor, cloche notifs. → **strictement inchangé.**
- **Voyageur :** pins colis 📦, filtres colis (taille, poids max, date range), near-me colis, faire une offre sur un colis. → **conservés**, désormais accessibles via le focus (Colis ou Tout) sans switch. **Ajout** : il voit aussi les trajets (focus Tout/Trajets) — nouveau, non régressif.

## Fichiers touchés (prévisionnel)

| Fichier | Changement |
|---|---|
| `lib/features/home/presentation/home_screen.dart` | Carte additive (pins par capacité), filtre de focus, near-me & sheet pilotés par focus, états vides filter-aware, retrait doublon offre, retrait lecture `ActiveRoleCubit` |
| `lib/core/widgets/role_mode_pill.dart` | Retrait de l'usage Home (suppression différée à Phase 4 si plus aucun usage) |
| `lib/features/home/...` (filtres/markers) | Logique de filtres pilotée par le focus ; rendu conditionnel des pins par `isTraveler` |
| `lib/core/services/analytics_events.dart` | Event(s) du filtre de focus |
| `CLAUDE.md` | Maj table des events |

*(Liste affinée dans le plan d'implémentation.)*

## Analytics

- Nouvel event pour le filtre de focus (ex. `home_map_focus_changed`, propriété `focus` ∈ { `all`, `parcels`, `trips` }), tiré dans le BLoC Home, `unawaited`, sans PII.
- Events existants (offre, bid, vue annonce…) **préservés**.

## Tests

- Widget Home : pur expéditeur → trajets seuls, pas de filtre de focus ; voyageur → deux types de pins + filtre de focus (défaut Tout).
- Focus → bon set de filtres détaillés affichés ; near-me & sheet filtrés.
- États vides filter-aware (avec/sans filtres actifs).
- Non-régression : tous les tests Home expéditeur existants passent.
- Couverture ≥ 90 %.

## Cas limites

- **Voyageur sans trajet publié :** voit quand même colis + trajets (il peut jauger la demande / envoyer son propre colis).
- **Perte du rôle voyageur :** `user.isTraveler` repasse à false → carte redevient trajets seuls, filtre de focus disparaît. (Plus besoin de `syncWithRoles` côté Home.)
- **Carte chargée (beaucoup de pins) :** clustering/limitation existants conservés ; le focus aide à désencombrer.

## Décisions ouvertes (mineures)
- Position visuelle exacte du filtre de focus dans l'overlay (au-dessus ou intégré à la barre corridor).
- Wording du décompte mixte dans l'en-tête de la sheet.
- Nom précis de l'event analytics.
