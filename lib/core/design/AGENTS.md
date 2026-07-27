# AGENTS.md — Design system dony

Ce fichier ne s'applique qu'à `lib/core/design/`. Ce dossier est la source de vérité
des tokens, thèmes, composants et animations partagés.

```dart
import 'package:dony/core/design/design_system.dart';
```

Avant tout travail UI, charger et appliquer le skill Codex
`make-interfaces-feel-better`. Adapter ses principes à Flutter : rayons
concentriques, alignement optique, surfaces cohérentes, animations interruptibles,
zones tactiles suffisantes et coût de rendu maîtrisé.

## Tokens

Réutiliser les tokens; ne jamais introduire une valeur visuelle arbitraire lorsqu'un
token existe.

### Couleurs

| Token | Valeur light | Usage |
| --- | --- | --- |
| `DonyColors.primary` | `#0B5FFF` | CTA, liens, focus |
| `DonyColors.primaryHover` | `#0A4DD9` | hover primary |
| `DonyColors.primaryPress` | `#083CAB` | pressed/active |
| `DonyColors.primarySoft` | `#EDF2FF` | fond actif |
| `DonyColors.accent` | `#D96A3A` | accent chaud |
| `DonyColors.accentSoft` | `#FCF0E9` | fond accent |
| `DonyColors.bgApp` | `#FAFAF8` | fond d'écran light |
| `DonyColors.surface` | `#FFFFFF` | cards et champs light |
| `DonyColors.surfaceWarm` | `#F7F3ED` | sections communautaires |
| `DonyColors.textPrimary` | `#0A2540` | texte principal light |
| `DonyColors.textMuted` | `#54504A` | texte secondaire light |
| `DonyColors.textSubtle` | `#797367` | hints light |
| `DonyColors.borderDefault` | `#E8E5DF` | bordures light |
| `DonyColors.success` | `#0E8A5F` | succès |
| `DonyColors.warning` | `#E8A23B` | avertissement |
| `DonyColors.error` | `#D9342B` | erreur |

Les palettes primitives `blue`, `terra`, `neutral`, `sand` et `ink` sont réservées
aux contextes `const` ou usages volontairement non sémantiques.

### Espacement et rayons

```dart
DonySpacing.xs   = 4;
DonySpacing.sm   = 8;
DonySpacing.md   = 12;
DonySpacing.base = 16;
DonySpacing.lg   = 20;
DonySpacing.xl   = 24;
DonySpacing.xxl  = 32;
DonySpacing.huge = 48;

DonyRadius.sm    = 8;
DonyRadius.md    = 12;
DonyRadius.lg    = 14;
DonyRadius.card  = 16;
DonyRadius.xl    = 20;
DonyRadius.sheet = 24;
DonyRadius.full  = 999;
```

Pour des surfaces imbriquées proches, appliquer un rayon concentrique :
`rayon extérieur = rayon intérieur + padding`. Si l'écart dépasse 24 px, traiter les
surfaces indépendamment. Aligner les icônes optiquement lorsque le centrage
géométrique paraît faux.

## Dark mode

L'application suit `ThemeMode.system`.

Dans tout `build()`, lire les couleurs sémantiques depuis :

```dart
final cs = Theme.of(context).colorScheme;

cs.primary;
cs.onPrimary;
cs.secondary;
cs.surface;
cs.onSurface;
cs.onSurfaceVariant;
cs.outline;
cs.error;
cs.success;
cs.warning;
cs.info;
cs.errorLight;
cs.surfaceWarm;
```

Ne jamais utiliser directement dans un widget brightness-aware :
`DonyColors.surface`, `bgApp`, `textPrimary`, `textMuted`, `borderDefault`,
`primary` ou les couleurs de statut light-only. Utiliser `ColorScheme` et
`DonyStatusColors`.

Les primitives restent autorisées dans un contexte `const` ou un dégradé
intentionnel. Vérifier chaque nouveau composant en light et dark mode.

## Typographie

- Hanken Grotesk : displays, headlines et titres.
- Plus Jakarta Sans : corps, labels et boutons.
- Dans les widgets, utiliser `Theme.of(context).textTheme`; ne jamais appeler
  directement Google Fonts.
- `DonyTypography.caveat()` est réservé aux accents décoratifs courts, jamais au
  corps de texte.
- Taille minimale 12 px pour le contenu utilisateur.
- Utiliser des chiffres tabulaires pour prix, compteurs, durées et colonnes
  numériques qui changent, afin d'éviter les sauts de mise en page.
- Prévenir les orphelins dans les titres et textes courts avec une largeur ou des
  retours adaptés; ne pas forcer des coupures fragiles.

Références du thème :

```dart
final text = Theme.of(context).textTheme;

text.displayLarge;   // 32, w800
text.headlineLarge;  // 22, w700
text.headlineMedium; // 18, w700
text.titleLarge;     // 15, w700
text.titleMedium;    // 14, w600
text.bodyLarge;      // 16, w400
text.bodyMedium;     // 14, w400
text.bodySmall;      // 12, w400
text.labelLarge;     // 14, w700
text.labelMedium;    // 11, w600 — uniquement micro-labels accessibles
text.labelSmall;     // 10, w600 — uniquement navigation/mini-labels accessibles
```

Les tailles sous 12 px ne conviennent qu'aux labels système non essentiels déjà
prévus par le thème; ne pas en créer de nouveaux.

## Composants

- Utiliser `DonyButton`, `DonyTextField`, `DonyCard`, `DonyBadge`, `DonyAvatar`,
  `DonySnackbar`, `DonyEmptyState` et les composants exportés, plutôt que des
  variantes locales.
- `DonyButton` est pleine largeur, hauteur 52 et rayon `DonyRadius.lg`.
- `DonyTextField` utilise `DonyRadius.md`; conserver labels, validation et états
  focus/error accessibles.
- `DonyCard` utilise `DonyRadius.card` et les couleurs brightness-aware.
- `DonyMascotteAnimated` est le choix par défaut. `DonyMascotte` statique est réservé
  aux listes denses ou contextes où le mouvement distrait.
- Ne jamais charger une mascotte avec `Image.asset`; passer par les composants
  mascotte.
- `withGlow: true` est réservé aux succès et confirmations finales.
- Les images ont un séparateur neutre subtil adapté au thème, sans teinte de marque.
- Pour créer de la profondeur, préférer les surfaces et ombres légères cohérentes;
  conserver les bordures pour champs, focus, dividers et séparation structurelle.

Dans un `DonyBottomSheet`, tout `DonyButton` doit être dans `stickyBottom`, jamais
dans le `child` scrollable. Utiliser `wrapper` quand contenu et bouton partagent un
BLoC, et disposer les `ValueNotifier` créés par `show()`.

## Animations

- Utiliser `flutter_animate` et les primitives du design system.
- Entrée : 250–300 ms, `easeOutCubic`; découper en groupes sémantiques et stagger
  d'environ 60–100 ms quand cela améliore la lecture.
- Sortie : 150–200 ms, `easeInCubic`, plus discrète que l'entrée, avec déplacement
  court plutôt qu'une traversée complète.
- Les transitions interactives doivent pouvoir s'inverser sans saut si l'utilisateur
  change d'intention.
- Pour un changement d'icône, conserver la continuité avec opacity, scale et blur
  plutôt qu'une disparition instantanée.
- Un feedback de pression peut descendre à `0.96`, jamais sous `0.95`.
- Animer uniquement les propriétés nécessaires. Éviter les rebuilds globaux et les
  effets coûteux; isoler les zones animées avec parcimonie.
- Respecter les préférences de réduction des animations et fournir un état statique
  équivalent.
- Une animation d'entrée ne doit pas se rejouer inutilement à chaque rebuild.

## Accessibilité

- Zone tactile minimale 44×44; les zones de deux contrôles ne se chevauchent jamais.
- Ajouter `Semantics` aux icônes et contrôles sans label visible.
- Fournir un `tooltip` aux `IconButton`.
- Contraste texte/fond d'au moins 4.5:1.
- Ne jamais transmettre une information par la couleur seule; ajouter texte, icône
  ou forme.
- Gérer le text scaling sans troncature des actions importantes.
- Conserver un ordre de focus logique et des libellés compréhensibles hors contexte.
- Tester clavier/lecteur d'écran lorsque le composant est interactif.
- Vérifier light mode, dark mode, grandes polices, états loading/error/disabled et
  réduction des animations avant validation.
