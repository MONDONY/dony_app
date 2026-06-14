# Phase 3 — Suivi : passe de conformité design + corrections

**Date :** 2026-06-14 · **Statut :** validé (brainstorming visuel)
**Réf :** `docs/superpowers/specs/2026-06-09-phase-3-suivi-design.md` (spec d'origine) · `docs/superpowers/plans/2026-06-09-phase-3-suivi.md`

## Contexte

La Phase 3 (onglet Suivi additif + ScanHub réel) est **déjà implémentée** sur `feature/phase-3-suivi`
(10 commits). La structure par profil est validée et conservée. Cette passe corrige des écarts
au design system dony et deux points produit, sans toucher à l'architecture (dispatcher, cubit,
sélecteurs purs, flux scan/offline restent inchangés).

## Décisions validées (maquettes Visual Companion)

La répartition **3 profils / 1 onglet « Suivi »** est conservée telle quelle :
- **Expéditeur pur** → recherche de colis (in-shell).
- **Voyageur occasionnel** → recherche + entrée « 📷 Scanner un trajet » (push ScanHub).
- **Voyageur pro** → ScanHub + entrée « 📦 Suivre un colis » (push recherche).

### Changements

1. **En-tête de recherche — retrait de l'icône camion.**
   `TrackingSearchScreen._buildSearchHeader` : supprimer le bloc icône `Icons.local_shipping_outlined`
   (la boîte `primaryContainer`). Le titre « Numéro de suivi » + description restent. Resserrer
   l'espacement supérieur en conséquence.

2. **Onglet « Suivi » (bottom-nav) — icône cible/radar.**
   `main_shell.dart` : `tab2Icon` passe de `Icons.local_shipping_rounded` à
   `Icons.track_changes_rounded` (icône pleine et outlined identiques, onglet figé inchangé).

3. **ScanHub — sémantique du badge d'étape (photo, pas obligation d'étape).**
   `scan_hub_screen.dart` (`_EtapeChip`) :
   - Les 3 étapes restent à scanner. Le badge ne communique **que** l'exigence **photo**.
   - **Départ** et **Arrivée** (`photoRequired: true`) → badge compact « 📷 Photo » (accent/erreur subtil).
   - **Transit** (`photoRequired: false`) → **aucun badge** (photo facultative).
   - Supprimer les libellés « obligatoire » / « optionnelle » (ce dernier laissait croire l'étape sautable).
   - Les flags `photoRequired` restent inchangés (Départ=true, Transit=false, Arrivée=true).
   - Ajouter une ligne d'aide sous la section : « Photo obligatoire au départ et à l'arrivée.
     Au transit, la photo est facultative. »

4. **Conformité design system + zéro overflow (toutes les surfaces touchées).**
   - Tailles d'icônes harmonisées (boîtes secondaires 36, quick-action 38, icône interne ≤ 20).
   - Touch targets ≥ 44 (entrées secondaires, chips, quick actions).
   - Radius cohérents (cards 16, inputs 12, boutons 14, chips/badges arrondis).
   - Espacements : padding horizontal 16–20, sections 20–24.
   - **Aucun overflow** sur petits écrans (chips d'étapes : texte court + badge compact ;
     `FittedBox`/ellipsis si nécessaire ; vérifié à 320 dp de large).
   - Animations d'entrée fluides (`flutter_animate` : fadeIn 250–300 ms easeOutCubic, slideY léger,
     stagger 60 ms si pertinent) — cohérentes avec le reste de l'app.

## Fichiers touchés

| Fichier | Changement |
|---|---|
| `lib/features/tracking/presentation/screens/tracking_search_screen.dart` | Retrait icône camion en-tête + espacement |
| `lib/app/main_shell.dart` | `tab2Icon` → `Icons.track_changes_rounded` |
| `lib/features/tracking/presentation/screens/scan_hub_screen.dart` | Badge photo (Départ/Arrivée), rien au Transit, ligne d'aide, conformité tailles/overflow/anim |
| `test/...` (existants) | MAJ assertions impactées (libellés badge, icône onglet) |

## Hors périmètre

- Pas de changement backend (le `photoRequired` reste un flag front pilotant le flux de scan ;
  si le back valide la photo par étape, il accepte déjà transit sans photo).
- Pas de modification de la logique de dispatch, du `ScanHubCubit`, des sélecteurs purs,
  du flux `/tracking/scan*` ni de la file offline.

## Tests

- `flutter analyze` → aucune erreur.
- Suites tracking existantes vertes ; MAJ des assertions sur les libellés/icône modifiés.
- Vérif manuelle overflow à 320 dp (Départ/Transit/Arrivée).
