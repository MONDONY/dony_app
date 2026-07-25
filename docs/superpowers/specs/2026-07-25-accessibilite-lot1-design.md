# Accessibilité, lot 1 : fondations réglages

**Date :** 2026-07-25
**Projet :** dony_app (Flutter)
**Statut :** spec validée, à implémenter

---

## Contexte et constat

L'écran Réglages › Accessibilité expose trois options : taille du texte, contraste élevé,
réduction des animations. **Aucune des trois ne produit d'effet.**

Preuves relevées au moment de l'audit :

- `lib/features/settings/bloc/accessibility_bloc.dart:22-35` : les trois handlers écrivent
  dans Hive et émettent un nouvel état. Rien d'autre.
- Recherche de `textScale`, `highContrast`, `reduceAnimations` dans tout `lib/` : les seuls
  consommateurs sont l'écran de réglages lui-même et `user_preferences_model.dart`, qui
  relit ces clés pour les réécrire et n'est référencé nulle part ailleurs.
- `lib/app/app.dart:224-247` : `MaterialApp.router` applique `themeMode` et `locale`
  (alimentés par `AppPreferencesBloc`, singleton fourni à la racine) mais n'a aucun
  `builder` qui injecterait un `MediaQuery.textScaler`.
- `AppTheme` ne produit que deux thèmes, `light` et `dark`. Aucune variante contrastée
  n'existe.
- `flutter_animate` n'est jamais neutralisé globalement.

Cause racine : `AccessibilityBloc` est enregistré en `registerFactory`
(`lib/core/di/injection.dart:551`) et fourni uniquement au niveau de la route
(`lib/app/router.dart:1082`). L'écran de réglages possède donc sa propre instance, et
aucun autre écran n'observe cet état.

Symptôme visuel secondaire : le `SegmentedButton` de la taille de texte n'est pas thémé.
Il utilise la couleur de sélection Material par défaut, hors palette dony, et le libellé
« Normale » se coupe en trois lignes parce que quatre segments plus une icône de coche ne
tiennent pas dans la largeur disponible.

## Cible réglementaire

dony est un service de commerce électronique. L'European Accessibility Act, applicable
depuis juin 2025, renvoie à la norme EN 301 549, qui reprend **WCAG 2.1 niveau AA**. Le
RGAA est la déclinaison française du même socle. La cible est donc unique.

## Découpage du chantier

Le passage en AA est trop vaste pour une seule spec. Découpage retenu, chaque lot ayant
sa propre spec et son propre plan :

| Lot | Contenu | Dépend de |
|---|---|---|
| **1. Fondations réglages** (cette spec) | Câbler réellement les réglages, thème haut contraste, refonte de l'écran, nouvelles options | — |
| 2. Contrastes et cibles | Audit mesuré des tokens et composants du design system, corrections à la source | Lot 1 |
| 3. Lecteur d'écran | `Semantics`, ordre de focus, régions live sur les parcours critiques | Lot 2 |
| 4. Non-régression | Tests d'accessibilité automatisés, checklist de PR, lint | Lots 1 à 3 |

Cette spec ne couvre que le lot 1.

---

## Architecture

### Source de vérité unique

`AccessibilityBloc` passe de `registerFactory` à `registerLazySingleton` dans
`lib/core/di/injection.dart`. Il est fourni dans `lib/app/app.dart` au même niveau
qu'`AppPreferencesBloc`, via `BlocProvider.value`. Le provider de `lib/app/router.dart`
devient lui aussi un `.value` pointant sur le singleton.

Les trois champs `textScale`, `highContrast` et `reduceAnimations` sont retirés de
`lib/features/settings/data/models/user_preferences_model.dart`. Ce modèle n'est utilisé
nulle part ailleurs et constituait une seconde source de vérité destinée à diverger.

Conformément à la règle projet, `AccessibilityBloc` reçoit `AnalyticsService` en
paramètre de constructeur.

### État

Trois réglages sont tri-états : suivre le téléphone, forcer à activé, forcer à désactivé.
Ils sont stockés en `String` parce que Hive gère mal les `bool?`.

```dart
class AccessibilityState extends Equatable {
  final bool   followSystemTextScale;   // défaut true
  final double textScaleFactor;         // 0.85 à 2.0, défaut 1.0, ignoré si followSystem
  final String highContrast;            // 'system' | 'on' | 'off', défaut 'system'
  final String reduceMotion;            // 'system' | 'on' | 'off', défaut 'system'
  final bool   boldText;                // défaut false
  final bool   underlineLinks;          // défaut false
  final bool   reinforceLabels;         // défaut false
  final bool   persistentMessages;      // défaut false
  final bool   confirmImportantActions; // défaut false
}
```

Clés Hive, dans `HiveService` :

```
a11y_follow_system_text_scale : bool
a11y_text_scale_factor        : double
a11y_high_contrast            : String
a11y_reduce_motion            : String
a11y_bold_text                : bool
a11y_underline_links          : bool
a11y_reinforce_labels         : bool
a11y_persistent_messages      : bool
a11y_confirm_important        : bool
```

Les anciennes clés `text_scale`, `high_contrast` et `reduce_animations` sont lues une
dernière fois pour la migration, puis supprimées du box.

### Résolution des modes « system »

`MediaQuery.of(context)` fournit `highContrast`, `disableAnimations` et `textScaler`.
Le mode `'system'` suit ces valeurs, `'on'` et `'off'` les écrasent. La résolution se fait
dans `app.dart`, au point d'application, pas dans le bloc, qui n'a pas de `BuildContext`.

### Application des réglages

Un `BlocBuilder<AccessibilityBloc, AccessibilityState>` enveloppe `MaterialApp.router`
dans `app.dart`, à l'intérieur du `BlocBuilder<AppPreferencesBloc>` existant. Trois
leviers :

**1. Thème.** `AppTheme._build` prend un paramètre nommé supplémentaire :

```dart
static ThemeData light({bool highContrast = false, bool reduceMotion = false});
static ThemeData dark({bool highContrast = false, bool reduceMotion = false});
static ThemeData _build(
  Brightness brightness, {
  required bool highContrast,
  required bool reduceMotion,
});
```

`reduceMotion` ne sert qu'à choisir le `pageTransitionsTheme`, décrit au levier 3.

`theme:` et `darkTheme:` reçoivent la variante correspondant au contraste effectif.

**2. `MediaQuery` réinjecté** dans le `builder:` de `MaterialApp.router`, en composition
avec l'`AnalyticsConsentGate` déjà présent :

```dart
builder: (context, child) {
  final mq = MediaQuery.of(context);
  final scaler = state.followSystemTextScale
      ? mq.textScaler.clamp(maxScaleFactor: 2.0)
      : TextScaler.linear(state.textScaleFactor);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: scaler,
      boldText: state.boldText,
      disableAnimations: reduceMotionEffective,
    ),
    child: AccessibilityScope(
      underlineLinks: state.underlineLinks,
      reinforceLabels: state.reinforceLabels,
      persistentMessages: state.persistentMessages,
      confirmImportantActions: state.confirmImportantActions,
      child: AnalyticsConsentGate(child: child ?? const SizedBox.shrink()),
    ),
  );
}
```

Le plafond à 2.0 s'applique aussi en mode système : c'est le seuil demandé par WCAG 1.4.4,
et au-delà les écrans ne sont pas tenables.

`boldText` n'exige aucune modification de widget. Flutter le lit nativement dans
`Text.build` et fusionne `FontWeight.bold` dans le style effectif.

**3. Mouvement.** Quand la réduction est effective :

- `Animate.defaultDuration = Duration.zero`, posé dans un `BlocListener` sur
  `AccessibilityBloc`, jamais dans un `build`.
- `pageTransitionsTheme` bascule sur une variante sans transition, appliquée dans
  `AppTheme._build` en fonction d'un paramètre `reduceMotion`.

### Lecture dans les widgets

Les leviers 1 à 3 sont transparents pour le code applicatif. Les quatre flags restants ne
passent pas par `MediaQuery` et sont exposés par un `InheritedWidget` :

```dart
// lib/core/design/accessibility_scope.dart
class AccessibilityScope extends InheritedWidget {
  final bool underlineLinks;
  final bool reinforceLabels;
  final bool persistentMessages;
  final bool confirmImportantActions;

  static AccessibilityScope of(BuildContext context);
}

extension AccessibilityContext on BuildContext {
  AccessibilityScope get a11y => AccessibilityScope.of(this);
}
```

Motif : imposer un `BlocProvider<AccessibilityBloc>` à chaque widget du design system
créerait un couplage entre le design system et une feature. Un `InheritedWidget` posé une
fois à la racine évite ça, et `AccessibilityScope.of` renvoie des valeurs par défaut
sûres si le scope est absent, ce qui garde les widgets testables isolément.

---

## Écran de réglages

### Structure

```
Accessibilite

  +--------------------------------------+
  |  Apercu                              |
  |  +--------------------------------+  |
  |  |  Paris  ->  Dakar    [URGENT]  |  |
  |  |  12 kg disponibles             |  |
  |  |  [ Faire une offre ]           |  |
  |  +--------------------------------+  |
  +--------------------------------------+

  TEXTE
  +--------------------------------------+
  | Suivre les reglages du telephone [o] |
  |--------------------------------------|
  | Taille du texte              125 %   |
  |   85 % ------O------------- 200 %    |
  |--------------------------------------|
  | Texte en gras                    [ ] |
  +--------------------------------------+

  AFFICHAGE
  +--------------------------------------+
  | Contraste eleve      Suivre le tel > |
  |--------------------------------------|
  | Souligner les liens              [ ] |
  |--------------------------------------|
  | Renforcer les etiquettes         [ ] |
  +--------------------------------------+

  MOUVEMENT
  +--------------------------------------+
  | Reduire les animations  Suivre le t> |
  +--------------------------------------+

  MESSAGES ET ACTIONS
  +--------------------------------------+
  | Garder les messages affiches     [ ] |
  |--------------------------------------|
  | Confirmer les actions importantes[ ] |
  +--------------------------------------+

  Ouvrir les reglages du telephone   >
  Tout reinitialiser
```

### Aperçu vivant

Une `DonyTripCard` réduite, alimentée par des données factices, placée en tête de l'écran.
Elle subit immédiatement chaque réglage : taille, gras, contraste, soulignement, étiquette
renforcée. C'est le cœur de la refonte. Dans la version actuelle, l'utilisateur bascule un
réglage et ne perçoit aucun retour, ce qui rend l'écran invérifiable de l'extérieur.

L'aperçu applique les réglages localement, via un `MediaQuery` et un `Theme` locaux
dérivés de l'état, sans attendre la reconstruction globale.

### Contrôles

- **`SegmentedButton` supprimé.** C'est la source du libellé coupé en trois lignes et de
  la couleur de sélection hors palette. Un `Slider` ne peut pas déborder et offre une
  granularité utile, par pas de 5 % entre 85 % et 200 %.
- **Le curseur est désactivé** (opacité 0,4, `onChanged: null`) quand « Suivre les réglages
  du téléphone » est actif. Le pourcentage affiché devient alors celui du système.
- **Les tri-états n'utilisent pas de segments.** « Contraste élevé » et « Réduire les
  animations » sont des `DonyListTile` affichant la valeur courante à droite, qui ouvrent
  un `DonyBottomSheet` contenant un `DonyRadioGroup` à trois entrées : « Suivre le
  téléphone », « Toujours activé », « Toujours désactivé ». Motif : trois pastilles côte à
  côte déborderaient à 200 %, soit exactement le défaut que cette spec corrige.
- **Chaque ligne porte un `subtitle`** décrivant l'effet en une phrase. `DonyListTile`
  supporte déjà ce paramètre.
- **« Ouvrir les réglages du téléphone »** ouvre les réglages système d'accessibilité, pour
  l'utilisateur qui ne sait pas où ils se trouvent.
- **« Tout réinitialiser »** remet les neuf valeurs par défaut, précédé d'un `DonyDialog`
  de confirmation.

Les libellés affichés n'utilisent pas de tiret cadratin, conformément à la convention du
projet.

### Périmètre de chaque nouvelle option

| Option | Ce qu'elle touche |
|---|---|
| Texte en gras | `MediaQueryData.boldText`, appliqué nativement par Flutter à tous les `Text` |
| Souligner les liens | `textButtonTheme` dans `AppTheme`, donc tous les `TextButton` inline |
| Renforcer les étiquettes | `DonyBadge`, `DonyUrgentBadge`, `DonyStatusBanner` et les puces de statut d'envoi : ajout d'une icône et d'un mot là où seule la couleur porte l'information (WCAG 1.4.1) |
| Garder les messages affichés | `DonySnackbar.show` passe en durée longue avec une action de fermeture explicite (WCAG 2.2.1) |
| Confirmer les actions importantes | Étape de confirmation `DonyDialog` avant paiement, avant annulation de trajet ou d'envoi, et avant suppression de compte. Cette liste est fermée (WCAG 3.3.4) |

### Thème haut contraste

`color_tokens.dart` reçoit un jeu de tokens suffixés `Hc`, en clair et en sombre. Ils sont
**ajoutés**, jamais substitués aux tokens existants, donc le rendu normal ne change pas.

Principes de la variante contrastée :

- Texte principal poussé au maximum, `ink900` sur blanc pur en clair, blanc pur sur noir
  quasi pur en sombre, cible 7:1.
- Texte secondaire remonté pour dépasser 4.5:1, alors qu'il échoue aujourd'hui à ce seuil.
- Bordures à 1,5 px et couleur nettement visible, au lieu de `neutral200` très pâle.
- Fonds doux (`primarySoft`, `accentSoft`, `sand`) remplacés par des fonds pleins avec
  texte inversé.
- Anneau de focus épaissi et contrasté.

---

## Migration des données

Lecture unique au démarrage du bloc, puis réécriture au nouveau format et suppression des
anciennes clés.

| Ancienne valeur | Nouvelle valeur |
|---|---|
| `text_scale: 'small'` | `followSystemTextScale: false`, `textScaleFactor: 0.85` |
| `text_scale: 'normal'` ou absent | `followSystemTextScale: true`, `textScaleFactor: 1.0` |
| `text_scale: 'large'` | `followSystemTextScale: false`, `textScaleFactor: 1.3` |
| `text_scale: 'xlarge'` | `followSystemTextScale: false`, `textScaleFactor: 1.6` |
| `high_contrast: false` ou absent | `'system'` |
| `high_contrast: true` | `'on'` |
| `reduce_animations: false` ou absent | `'system'` |
| `reduce_animations: true` | `'on'` |

`'normal'` devient « suivre le téléphone » parce que c'était la valeur par défaut, donc un
choix que l'utilisateur n'a jamais posé. Un `false` sur les deux booléens se traduit par
`'system'` pour la même raison.

---

## Analytics

Nouvel event, à déclarer dans `AnalyticsEvents` et à ajouter au tableau de
`dony_app/CLAUDE.md` :

| Event | Déclencheur | Propriétés |
|---|---|---|
| `accessibility_setting_changed` | `AccessibilityBloc`, à chaque handler | `setting` (nom du réglage), `value` (valeur retenue, sérialisée) |

Aucune donnée personnelle. Appel via `unawaited`.

---

## Tests

Couverture cible 90 %, conformément à la politique du projet.

**Unitaires, `AccessibilityBloc` :**
- les neuf réglages émettent le bon état et persistent la bonne clé Hive ;
- migration depuis chacune des huit combinaisons de l'ancien format ;
- suppression effective des anciennes clés après migration ;
- réinitialisation complète ;
- émission de l'event analytics avec les bonnes propriétés.

**Widget, écran de réglages :**
- rendu des quatre sections ;
- le curseur est désactivé quand « suivre le téléphone » est actif ;
- ouverture des deux sheets tri-états et sélection d'une valeur ;
- l'aperçu réagit à un changement de taille et au gras ;
- réinitialisation avec sa confirmation.

**Propagation, le test qui manquait :**
- monter `DonyApp` avec un état donné et vérifier que `MediaQuery.textScalerOf`,
  `MediaQuery.boldTextOf` et `MediaQuery.disableAnimationsOf` reflètent cet état ;
- vérifier que le thème actif est bien la variante contrastée quand le contraste est forcé.

C'est l'absence de ce test qui a permis à trois réglages morts de rester en production.

**Garde-fous WCAG :**
- `meetsGuideline(textContrastGuideline)` et `meetsGuideline(androidTapTargetGuideline)`
  sur l'écran d'accessibilité, dans les quatre variantes de thème.

**Non-régression à 200 % :**
- test de fumée avec `textScaler` à 2.0 sur accueil, publication de trajet, création
  d'offre, paiement et scan, vérifiant l'absence d'exception d'overflow.

---

## Risques

1. **Le test à 200 % va révéler des débordements.** C'est certain, l'application n'a jamais
   été soumise à ce facteur. Les corrections sur les cinq parcours listés font partie du
   lot 1. Les débordements constatés ailleurs sont consignés et renvoyés au lot 2, faute de
   quoi le lot 1 ne se termine pas.
2. **`Animate.defaultDuration` est un statique global.** Il est posé dans un `BlocListener`
   et restauré dans le `tearDown` des tests, sinon un test activant la réduction de
   mouvement contamine tous les suivants.
3. **Quatre variantes de thème élargissent la surface visuelle.** Les tokens haut contraste
   sont ajoutés et non substitués, donc le rendu normal reste inchangé.
4. **`persistentMessages` et `confirmImportantActions` touchent du code hors réglages.**
   Leur périmètre est volontairement fermé aux composants et parcours listés plus haut.

---

## Fichiers concernés

**Réécrits :**
- `lib/features/settings/bloc/accessibility_bloc.dart`
- `lib/features/settings/bloc/accessibility_event.dart`
- `lib/features/settings/bloc/accessibility_state.dart`
- `lib/features/settings/presentation/screens/accessibility_settings_screen.dart`

**Créés :**
- `lib/core/design/accessibility_scope.dart`
- widgets d'écran : ligne curseur, ligne tri-état, carte d'aperçu

**Modifiés :**
- `lib/app/app.dart`
- `lib/app/router.dart`
- `lib/core/di/injection.dart`
- `lib/core/storage/hive_service.dart`
- `lib/core/design/theme/app_theme.dart`
- `lib/core/design/tokens/color_tokens.dart`
- `lib/core/design/widgets/dony_snackbar.dart`
- `lib/core/design/widgets/dony_badge.dart`
- `lib/core/design/widgets/dony_urgent_badge.dart`
- `lib/core/design/widgets/dony_status_banner.dart`
- `lib/core/services/analytics_events.dart`
- `lib/features/settings/data/models/user_preferences_model.dart` (retrait des 3 champs morts)
- `dony_app/CLAUDE.md` (tableau des events)

---

## Critères d'acceptation

- [ ] Changer la taille du texte modifie visiblement toute l'application, pas seulement
      l'écran de réglages.
- [ ] « Suivre les réglages du téléphone » fait suivre le Dynamic Type iOS et la taille de
      police Android, plafonnés à 200 %.
- [ ] Activer le contraste élevé bascule l'application sur la variante de thème contrastée,
      en clair comme en sombre.
- [ ] Le mode `'system'` du contraste suit `MediaQuery.highContrast` tant que l'utilisateur
      n'a pas tranché.
- [ ] Réduire les animations neutralise `flutter_animate`, les transitions de page et les
      animations implicites.
- [ ] Le texte en gras s'applique à toute l'application.
- [ ] Le soulignement des liens s'applique à tous les `TextButton`.
- [ ] Les étiquettes renforcées ajoutent une icône et un mot aux statuts aujourd'hui
      distingués par la seule couleur.
- [ ] Les messages temporaires restent affichés jusqu'à fermeture manuelle quand l'option
      est active.
- [ ] Les actions importantes demandent une confirmation quand l'option est active.
- [ ] Les préférences existantes sont migrées sans perte au premier lancement.
- [ ] Aucun `SegmentedButton` ne subsiste sur cet écran, et aucun libellé ne se coupe à
      200 %.
- [ ] Tous les tests passent, couverture au moins 90 %.
