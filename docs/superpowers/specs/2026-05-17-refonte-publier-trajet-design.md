# Refonte du bottom sheet « Publier un trajet » — Design

**Date :** 2026-05-17
**Feature :** `matching` — assistant de publication de trajet (côté voyageur)
**Statut :** design validé, prêt pour le plan d'implémentation

---

## 1. Contexte

Le bottom sheet « Publier un trajet » (v5, commit `fe98015`) présente 15 problèmes
UX/UI identifiés sur captures réelles (rapport `screen/refacto/detail_trajet/fix/RAPPORT-UX.md`) :
3 bloquants, 5 majeurs, 7 de polish. L'écran de confirmation payout Stripe
(« Compte bancaire connecté ») est aussi concerné par un bug de débordement.

Le code vit dans `lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart`
(2865 lignes) + `capacity_selector.dart` + le BLoC `AnnouncementFormBloc`.

## 2. Périmètre

Les **3 lots** du rapport, packagés en **un seul spec** et **un plan en 3 phases**
(Bloquants → Structure → Polish), chaque phase livrable et testable indépendamment.

**Hors périmètre :** migration globale des `Icons.*` Material du reste de l'app
(seuls les fichiers touchés par ce chantier passent à Phosphor) ; restructuration
complète du fichier de 2865 lignes (découpage « au fur et à mesure » uniquement).

## 3. Source de vérité visuelle

Maquettes validées le 2026-05-17 — dossier `maquettes/v6/` (9 captures) :

| Capture | Écran |
|---|---|
| `15-33-49` | Étape 1 · Trajet — état initial |
| `15-34-01` | Étape 1 · Autocomplétion ville (fix B1) |
| `15-34-08` | Étape 2 · Capacité preset valise (23/32 kg) |
| `15-34-21` | Étape 2 · Capacité « Kg libre » |
| `15-34-27` | Étape 2 · Capacité « Personnalisé » + slider |
| `15-34-40` | Étape 3 · Prix & conditions |
| `15-34-48` | Étape 3 · Conditions (scrollé) |
| `15-34-54` | Aperçu avant publication |
| `15-35-05` | Compte bancaire connecté (fix B3) |

Le rendu Flutter doit reproduire ces maquettes : espacements, rayons, hiérarchie,
structure. Les **couleurs** passent par les tokens sémantiques (`color_tokens.dart`)
pour fonctionner en clair **et** en sombre — les couleurs des maquettes sont
indicatives.

## 4. Architecture & découpage de fichiers

Principe : on extrait uniquement ce que les 3 phases touchent lourdement.

**Fichiers créés :**

```
lib/features/matching/presentation/widgets/create_announcement/
├── trajet_step.dart            ← corps étape 1
├── lieux_capacite_step.dart    ← corps étape 2
├── prix_conditions_step.dart   ← corps étape 3
└── capacity_control.dart       ← contrôle de capacité 4 chips (remplace capacity_selector.dart)

lib/core/design/
└── dony_icons.dart             ← mapping sémantique Phosphor (voir §5)
```

**Fichiers modifiés :**

- `create_announcement_bottom_sheet.dart` — **reste à son emplacement** (évite de
  casser tous les imports). Allégé : ne garde que `.show()`, le header, le
  stepper, le footer sticky et la bascule d'étape ; délègue les corps aux 3
  `*_step.dart`.
- `core/design/widgets/dony_text_field.dart` — étendu d'une variante « tappable »
  (ouvre un picker au lieu du clavier) au même habillage que la variante texte.
- `announcement_form_state.dart` / `announcement_form_bloc.dart` / `_event.dart` —
  nouveau `CapacityUnit.custom` (voir §6).
- L'écran `connect_onboarding` « Recevoir mes paiements » — fix B3 uniquement.

**Non touché :** `_LockedCityRow`, `_LockedTotalPriceCard`, billet, etc. — restent
dans le fichier d'origine.

**Contraintes héritées** (`dony_app/CLAUDE.md`) : BLoC only (pas de `setState`),
GoRouter, bottom sheet `isScrollControlled` + `viewInsets.bottom`, handle 40×4,
radius inputs 12 / boutons 14 / chips 20 / cards 16, Plus Jakarta Sans,
`flutter_animate` (entrée 250-300 ms `easeOutCubic`), touch targets 44×44.

## 5. Système d'icônes — Phosphor

Ajout du package **`phosphor_flutter`**. Les emoji des maquettes et les `Icons.*`
Material des fichiers touchés sont remplacés par des icônes Phosphor, **teintables**
via les tokens. Un fichier `dony_icons.dart` centralise le mapping sémantique afin
que l'app ne référence jamais Phosphor en dur :

| Usage | Icône Phosphor | Teinte |
|---|---|---|
| Ville/heure de départ | `airplaneTakeoff` / `clock` | départ (vert) |
| Ville/heure d'arrivée | `airplaneLanding` / `clock` | arrivée (terracotta) |
| Date de départ | `calendarBlank` | départ |
| Lieu de remise / récupération | `mapPin` | départ / arrivée |
| Position actuelle | `crosshair` | accent |
| Capacité valise | `suitcaseRolling` | accent |
| Capacité illimitée | `infinity` | accent |
| Prix « autre » | `pencilSimple` | neutre |
| Carte bancaire / espèces | `creditCard` / `money` | neutre |
| Escrow / virement / banque | `lockKey` / `lightning` / `bank` | accent |
| Conseil prix | `lightbulb` | warning |
| Modes transport | `airplaneTilt` `car` `train` `bus` `boat` `dotsThreeOutline` | neutre / actif |
| Fermer / retour / chevron | `x` / `caretLeft` / `caretRight` | neutre |
| Check / ajout / publication | `check` / `plus` / `rocketLaunch` | accent |
| Trajet confirmé (aperçu) | `sealCheck` | sur fond dégradé |

Graisse par défaut : `regular` ; `fill` pour les états sélectionnés/validés.
Migration limitée aux fichiers de ce chantier.

## 6. Modèle de données — Capacité

`CapacityUnit` passe de 3 à **4 valeurs** : ajout de `CapacityUnit.custom`.

| `capacityUnit` | Chip | `availableKg` | Slider |
|---|---|---|---|
| `suitcase23kg` | 1 valise · 23 kg | 23 | masqué |
| `suitcase32kg` | 1 valise · 32 kg | 32 | masqué |
| `kgFree` | Kg libre | `null` (illimité) | masqué |
| `custom` *(nouveau)* | Personnalisé | valeur du slider (1–30 kg) | **visible** |

Exactement un chip sélectionné en permanence (groupe single-select) — plus de
notion de désélection ni d'état vide ambigu. Sélectionner un preset fixe
`availableKg` ; sélectionner « Personnalisé » révèle le slider qui pilote
`availableKg`.

**Hypothèse — à confirmer côté backend :** `toWire()` n'a pas de valeur pour
`custom`. Hypothèse retenue : `custom` envoie un nouveau wire `KG_EXACT` avec le
`availableKg` précis. Si le backend ne peut pas l'accepter rapidement, repli :
`custom` envoie `KG_FREE` + `availableKg` précis (le back stocke déjà `availableKg`
séparément). **À trancher avant la Phase 2.**

## 7. Phase 1 — Bloquants

### B1 — Autocomplétion ville masquée
Les suggestions de ville s'affichent en **liste inline** juste sous le champ, dans
le flux scrollable de l'étape 1 — elles poussent le contenu, ne flottent pas en
overlay. Le footer sticky ne les recouvre jamais. ~4 suggestions visibles, le
reste scrolle. Sélection → remplit le champ, referme la liste, retire le focus.
Réf. maquette `15-34-01`.

### B2 — Keyboard avoidance
- Conteneur de contenu paddé par `MediaQuery.viewInsets.bottom`.
- Bottom sheet `isScrollControlled: true`.
- Au focus d'un champ : `Scrollable.ensureVisible` l'amène au-dessus du clavier.
- Footer sticky ancré au-dessus du clavier.

### B3 — Texte rogné « Compte bancaire connecté »
Écran `connect_onboarding`. Le paragraphe d'intro est contraint en largeur
(`width: double.infinity` dans la `Column`, padding de page 20 px) ; vérifier
qu'aucun parent n'impose une largeur > écran. Réf. maquette `15-35-05`.

**Livrable Phase 1 :** flux de saisie de nouveau utilisable. Touche 1 fichier hors
du dossier `create_announcement`.

## 8. Phase 2 — Structure & cohérence

### M1 — Vide blanc
Le bottom sheet se dimensionne à son contenu (hauteur = contenu, plafonnée à
~0,92 de l'écran). Aucun `Spacer` ni hauteur fixe.

### M2 — Contrôle de capacité
Nouveau `capacity_control.dart` : 4 chips (§6) + slider conditionnel + carte de
confirmation contextuelle (« Vous offrez 23 kg » / « Sans limite précise » /
slider « Vous offrez X kg »). Titre de section au-dessus, valeur en accent.
Réf. maquettes `15-34-08`, `15-34-21`, `15-34-27`.

### M3 — Marge du bouton
Zone du footer sticky : `padding horizontal 20 px` + `SafeArea`. Le bouton ne
touche jamais les bords.

### M4 — Champ unifié
`dony_text_field.dart` étendu : un seul habillage (conteneur rempli, radius 12,
icône de tête, label) pour ville (variante texte/clavier), heure et date
(variante tappable → picker). Réf. maquette `15-33-49`.

### M5 — Champs requis
Astérisque `*` sur tout champ obligatoire, partout (ville départ/arrivée, date,
lieux de remise/récupération).

**Livrable Phase 2 :** structure cohérente, capacité non ambiguë.

## 9. Phase 3 — Polish

| # | Correctif |
|---|---|
| P1 | Libellés de section en casse normale semi-gras (14 px, w600) — fini les MAJUSCULES |
| P2 | Libellés du stepper complets : « Lieux & capacité », « Prix & conditions » |
| P3 | Token sémantique `arrival` = terracotta calme (clair + sombre) au lieu de l'orange vif |
| P4 | Icône date dans la couleur « départ » |
| P5 | Hauteur de footer constante entre étapes (étape 1 = 1 bouton pleine largeur ; étapes 2-3 = Retour + Continuer), sans saut de mise en page |
| P6 | Flèches des boutons = widget `Icon` Phosphor séparé du `Text` |
| P7 | Hiérarchie capacité : titre au-dessus, valeur kg en accent secondaire |

Animations `flutter_animate` conservées. Aucune couleur hardcodée.

## 10. Tests & validation

**Automatisés** (cible ≥ 90 %, `dony_app/CLAUDE.md`) :
- `blocTest` sur `AnnouncementFormBloc` — transitions `CapacityUnit.custom`
  (sélection chip, valeur slider, `availableKg`, `toWire()`).
- Widget tests : `trajet_step`, `lieux_capacite_step`, `prix_conditions_step`,
  `capacity_control` (4 états), `dony_text_field` (3 variantes).
- Régression sur les états loading/error/success de chaque étape.

**Manuelle** (`flutter run`, émulateur) :
- Clavier ouvert sur les 3 étapes → aucun champ masqué, footer ancré.
- Autocomplétion ville → suggestions lisibles et cliquables.
- Bouton « Continuer » non rogné (écran à coins arrondis).
- Aucun débordement horizontal (« RIGHT OVERFLOWED »).
- Rendu correct en clair **et** en sombre.

**Gestion d'erreur :** les états d'erreur des appels (création d'annonce,
géocodage ville, Stripe) restent gérés par les `BlocConsumer`/snackbars existants
ancrés dans le bottom sheet — pas de régression attendue.

## 11. Hypothèses & points ouverts

1. **Wire `custom`** (§6) — à confirmer côté backend avant la Phase 2.
2. Le package `phosphor_flutter` est ajouté au `pubspec.yaml` (nouvelle dépendance).
3. Les maquettes `v6` sont la référence visuelle ; toute divergence de couleur
   est résolue en faveur des tokens sémantiques (support clair/sombre).
