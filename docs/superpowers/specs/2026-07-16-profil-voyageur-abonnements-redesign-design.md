# Redesign profil voyageur + Mes abonnements — Design

## Contexte

Deux écrans existants (`TravelerProfileHubScreen` et `MesAbonnementsScreen`) souffrent de deux défauts identifiés par l'utilisateur :
- **Densité/lisibilité** : sur le profil, badges (pills) et stats (3 box séparées) forment 2 blocs visuellement distincts qui se disputent l'espace du header.
- **Incohérence entre écrans** : le profil (header hero riche) et Mes abonnements (liste plate texte) ne partagent aucun langage visuel commun alors qu'ils décrivent le même concept (un voyageur).

Direction retenue après 3 rounds de mockups comparés dans le compagnon visuel (options A/B/C puis D/E/F, incluant le traitement du CTA sticky bottom et un zoom dédié aux cards trajet) : **Direction D — "Hero immersif + boarding pass"**.

## Scope

**Dans le scope :**
- `lib/features/subscriptions/presentation/traveler_profile_hub_screen.dart` (header, stats, CTA)
- `lib/features/subscriptions/presentation/widgets/traveler_announcement_card.dart` (card trajet)
- `lib/features/subscriptions/presentation/mes_abonnements_screen.dart` (rangée "stories" pour les nouveautés)
- `lib/features/subscriptions/presentation/widgets/subscription_tile.dart` (alignement visuel mineur, pas de refonte)

**Hors scope :**
- `SubscriptionsBloc`, `TravelerHubBloc`, `ProfilePublicBloc` et leurs states/events — aucun changement, c'est un redesign de présentation pure.
- `ProfilePublicModel`, `SubscriptionItem`, `RatingSummary` — aucun nouveau champ requis, tout ce dont les nouveaux widgets ont besoin existe déjà.
- Aucun autre écran ne consomme `TravelerAnnouncementCard` (vérifié par grep) — la refonte de ce composant est confinée à cette feature.

## Architecture visuelle

### 1. Hero immersif (remplace `_ProfileHeader` / `_LoadedProfileHeader`)

Dégradé radial nuit fixe (choix de marque assumé, identique en light/dark mode — comme un header de carte de fidélité) :
- Couleurs : réutilise les constantes existantes `DonyColors.proBg1` (#1A2744), `DonyColors.proBg2` (#0D1B35), `DonyColors.proBg3` (#1A3A6B) — déjà présentes dans `color_tokens.dart` pour d'autres cartes stats voyageur, pas de nouvelle constante.
- Halo diffus terracotta (`DonyColors.terra500` à faible opacité) positionné en haut-droite via un second `RadialGradient` superposé (`Stack` + `BoxDecoration` empilées, ou `ShaderMask` — implémentation la plus simple : deux `Container` empilés en `Stack`, le second avec `BlendMode.plus` ou simplement une opacité réduite).
- Contenu en overlay (nom + badges) ancré en bas-gauche du hero, texte blanc/quasi-blanc (`Colors.white`, `Colors.white70` pour les badges) — hors système `cs.*` car le fond est fixe, pas theme-aware par choix.
- Badges (`Compte PRO`, `Kilo Pro`, `Identité vérifiée`) : pills semi-transparentes (`Colors.white.withValues(alpha: 0.15)`), texte coloré par badge (or pour PRO via `DonyColors.kycBadgeGold`, bleu clair pour vérifié via `DonyColors.kycBadgeBlue` — ces tokens existent déjà, prévus pour les badges KYC).

### 2. Stat pills flottantes (remplace la row de `_StatCard`)

3 pills blanches (`cs.surface`, pas de `BackdropFilter`/blur — coût de perf inutile, l'effet visuel recherché tient très bien avec un fond opaque + ombre) positionnées pour chevaucher le bas du hero :
- Container `Transform.translate(offset: Offset(0, -22))` par pill, ou plus simplement un `Padding` négatif via `Stack` avec le hero en dessous — trancher au moment du plan selon ce qui rend le mieux avec `SliverAppBar`/`FlexibleSpaceBar` existant (contrainte : le hero est actuellement dans un `FlexibleSpaceBar.background`, les pills doivent rester dans la zone `bottom:` du `SliverAppBar` comme aujourd'hui — `_StatsAndTabBar` — pour garder le comportement pin/scroll).
- Chaque pill garde exactement les 3 mêmes stats qu'aujourd'hui (Note, Livraisons, Réponse), même logique d'affichage (`–` si absent, `<Xh` pour la réponse).
- Border radius `DonyRadius.card` (16), ombre `cs.shadow` (déjà un token existant) ou `DonyColors.shadow`.

### 3. `BoardingPassTripCard` (remplace le rendu interne de `TravelerAnnouncementCard`)

- Barre latérale gauche (4-5px) en dégradé linéaire `cs.primary → DonyColors.accent` (bleu→terracotta), coins arrondis à gauche uniquement.
- Contenu : ville départ (gros, `titleLarge`/Hanken Grotesk) + date en dessous (petit, muted) — séparateur pointillé vertical — ville arrivée + `kg dispo` (ou `Complet` en rouge/`cs.error` si `availableKg == 0`) — prix à droite en `cs.primary`, gros et gras.
- Séparateur pointillé : nouveau `_DashedDivider` (petit `CustomPainter`, orientation verticale, ~15 lignes) — pas de nouvelle dépendance pub (aucun package dashed/dotted déjà présent dans `pubspec.yaml`).
- État "complet" (`availableKg <= 0`) : prix et libellé "Complet" (au lieu de "X kg dispo") passent en `cs.onSurfaceVariant`/`cs.error` — **purement cosmétique**. Vérifié dans le code actuel (`TravelerAnnouncementCard`, `traveler_announcement_card.dart:161-175`) : il n'existe aujourd'hui aucune désactivation du bouton "Réserver" basée sur `availableKg` — le bouton reste toujours actif (`onReserve` toujours appelable). Le redesign ne doit pas introduire de désactivation : ce serait un changement de comportement, hors scope (voir section Scope).
- Toutes les couleurs de ce composant (hors la barre dégradée, décorative) passent par `cs.*` pour le dark mode.

### 4. `_SubscriptionStoryRow` (nouveau, en tête de `MesAbonnementsScreen`)

- Rangée horizontale scrollable (`ListView` `scrollDirection: Axis.horizontal`) affichée uniquement si `recent.isNotEmpty` (même condition que la section "Ont publié récemment" actuelle) — **remplace** cette section, ne s'ajoute pas en plus.
- Chaque item : avatar cerclé d'un anneau dégradé bleu→terracotta (`Container` avec `gradient: LinearGradient` en `BoxDecoration.shape: circle`, padding de 2px pour laisser apparaître l'anneau, avatar `DonyAvatar` à l'intérieur), nom en dessous (`bodySmall`, tronqué).
- Tap → identique au comportement actuel (`context.push('/travelers/${item.travelerId}')`).
- La section "Tous mes abonnements" (`others`) garde le rendu `SubscriptionTile` actuel tel quel, sans story-ring (réservé aux nouveautés) — seul ajustement : aligner son padding/radius sur les nouveaux tokens si un écart existe (mineur, à vérifier au moment du plan).

### 5. CTA sticky bottom (`_SubscriptionBar` / `_SubscribedRow`)

- **Aucun changement.** Vérifié dans `dony_button.dart` : `DonyButtonVariant.primary` (le variant déjà utilisé par défaut pour "S'abonner") rend déjà un `_GlowButton` — dégradé diagonal bleu + ombre colorée (glow). C'est exactement le traitement visuel que la direction D visait pour ce bouton ; introduire un dégradé navy custom romprait la cohérence avec tous les autres CTA `primary` de l'app (paiement, réservation, etc.) pour un gain visuel marginal. Le bouton "S'abonner" et l'état "Abonné ✓" (`DonyButtonVariant.secondary`, contour) restent tels quels, avec leur `IconButton` cloche existant.

## Dark mode

Le hero (fond nuit + halo) reste **identique en light et dark mode** — décision de marque assumée (un fond déjà sombre n'a pas besoin d'inversion). Tout le reste du contenu (pills, boarding pass, story-ring, CTA, `SubscriptionTile`) lit exclusivement `Theme.of(context).colorScheme` pour s'adapter automatiquement, conformément à la règle d'or du design system (`lib/core/design/CLAUDE.md`).

## Erreurs / états vides / loading

Aucun changement de flux : les branches `ProfilePublicError`, `TravelerHubStatus.error`/`.loading`, `SubscriptionsStatus.error` et les `DonyEmptyState` existants sont conservés à l'identique, seul le habillage visuel autour (hero, pills) change. La section "Ont publié récemment" vide (`recent.isEmpty`) masque simplement la story-row, comme la section actuelle est masquée aujourd'hui.

## Tests

- `test/features/subscriptions/traveler_profile_hub_screen_test.dart`, `traveler_announcement_card_test.dart`, `mes_abonnements_screen_test.dart` : à auditer et adapter au moment du plan — les finders ciblant l'ancien markup (ex. `find.byType` sur les anciens widgets `_StatCard`/`_ProfileBadge`, ou du texte spécifique à l'ancien layout) devront être mis à jour vers les nouveaux widgets, sans affaiblir les assertions (même règle que pour tout refactor de widget).
- Nouveau composant `_DashedDivider` : test unitaire simple si sa logique de dessin a une branche conditionnelle (sinon, couvert indirectement par les golden/widget tests du `BoardingPassTripCard`).
- Aucun nouveau cas métier à tester (pas de nouvelle donnée, pas de nouvel événement BLoC).

## Risques / points d'attention pour le plan

1. Le hero fixe (non theme-aware) contredit la règle générale "toujours `cs.*`" du design system — c'est un choix assumé et documenté ici, à rappeler explicitement dans le plan pour qu'un futur reviewer ne le signale pas comme un bug.
2. Le positionnement des stat-pills qui chevauchent le hero doit composer avec le `SliverAppBar` + `FlexibleSpaceBar` + `PreferredSizeWidget` (`_StatsAndTabBar`) existants — l'implémentation exacte (Transform vs Stack vs marge négative) est un détail d'implémentation à trancher pendant le plan, pas une question de design.
