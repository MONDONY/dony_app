# Accessibilité lot 2 — audit mesuré des contrastes et des cibles

**Date :** 2026-07-25
**Portée :** lecture seule, aucun code modifié.
**Méthode :** calcul WCAG 2.1 des ratios de luminance sur les paires réellement
produites par `AppTheme._build`, et mesure des tailles rendues des composants
tappables du design system sous `flutter test`.

---

## 1. Ce que l'audit établit

**96 paires de couleurs testées, 39 échecs.** Les échecs ne sont pas répartis au
hasard : ils se concentrent sur les couleurs sémantiques (succès, avertissement,
accent), sur les placeholders de champs, et sur une poignée de couleurs figées
en clair qui sont réutilisées telles quelles en mode sombre.

**7 composants tappables mesurés, aucun n'échoue au critère AA applicable.**
C'est le résultat le plus contre-intuitif de l'audit, il est développé en
section 3.

La variante haut contraste livrée au lot 1 passe partout, **sauf une paire** qui
est une régression introduite par ce lot et qui doit être corrigée.

---

## 2. Contrastes

### 2.1 Priorité 0 — défauts fonctionnels, pas seulement d'accessibilité

> **Révisé après vérification des usages.** Le calcul seul suppose que chaque
> token sert de couleur de texte sur la surface du thème courant. La
> vérification file par file a invalidé une partie de ces échecs, et en a
> révélé un plus grave. Les entrées invalidées sont conservées en 2.5, pour
> que l'audit reste honnête sur ce qu'il a d'abord mal classé.

| Ratio | Paire | Où | Conséquence |
|---|---|---|---|
| **2.04:1** | blanc sur `primaryHcDark` #8FB6FF | libellé de tout bouton plein, haut contraste + sombre | régression du lot 1 : le mode censé aider rend les boutons illisibles |
| **3.28:1** | blanc sur `blueDark500` #4D8AFF | libellé des `FilledButton` en mode sombre | échoue 1.4.3 |
| **2.55 à 3.35:1** | blanc sur les dégradés de `DonyButton` | **les 4 variantes pleines, dans les deux thèmes** | voir 2.6 |

Le troisième point est le plus lourd de l'audit et n'apparaissait pas dans le
balayage initial : `DonyButton` ne lit pas `cs.primary`, il peint des dégradés
codés en dur. Aucune correction du `ColorScheme` ne l'atteint.

### 2.2 Priorité 1 — texte, échecs larges (critère 1.4.3, seuil 4.5:1)

| Ratio | Paire | Portée |
|---|---|---|
| 1.97:1 | `warning` #E8A23B sur `warningLight` #FCF3DF | **152 usages** de warning |
| 2.17:1 | `warning` sur blanc | idem |
| 2.54:1 | placeholder `neutral400` #A8A294 sur blanc | **tous** les `DonyTextField` (`hintStyle` du thème) |
| 3.45:1 | `warning700` sur `warningLight` | la variante « foncée » échoue aussi |
| 3.46:1 | `accent` terra500 #D96A3A en texte, et blanc sur accent | **73 usages** |
| 3.84:1 | `success` #0E8A5F sur `successLight` #E5F4EE | **148 usages** de success |
| 3.90:1 | `info` #1B7BC2 sur `infoLight` #E5F0FA | bandeaux d'information |
| 3.98:1 | `error` #D9342B sur `errorContainer` #FCE8E5 | messages d'erreur |
| 4.00:1 | placeholder `neutralDark400` sur surface sombre | tous les champs, mode sombre |
| 4.32:1 | `blueDark500` sur `blueDark50` | chips actives en mode sombre |
| 4.36:1 | `success` #0E8A5F sur blanc | à 0.14 du seuil |
| 3.70:1 | `threadStatusAmber` sur blanc | chips de statut |

Deux constats en découlent :

- **`warning` est le pire token de la palette.** L'amber #E8A23B ne peut pas
  porter du texte sur fond clair, quelle que soit la nuance de fond. Il faut
  soit un amber nettement assombri pour le texte, soit inverser (texte sombre
  sur pastille amber).
- **Les paires « couleur 500 sur fond 50 » échouent presque toutes.** Le motif
  « texte coloré sur son propre fond pâle » est le schéma dominant des badges et
  bandeaux de l'app, et c'est celui qui casse.

### 2.3 Priorité 2 — éléments non textuels (critère 1.4.11, seuil 3:1)

| Ratio | Élément | Statut |
|---|---|---|
| 1.26:1 | bordure de champ `outline` #E8E5DF sur remplissage blanc | **échec réel** : le champ est blanc sur un fond app #FAFAF8 (1.05:1), la bordure est le seul indice de sa présence |
| 1.20:1 | bordure sur fond app | idem |
| 1.36 / 1.52:1 | bordures en mode sombre | idem |
| 2.15:1 | `starGold` #F59E0B (étoiles de notation) | échec : l'étoile porte l'information de note |
| 1.67 – 2.80:1 | `urgencyAmber` / `urgencyGreen` / `urgencyOrange` sur blanc | échec : les pastilles d'urgence encodent une information |
| 1.81 / 2.41:1 | `kycBadgeGold` / `kycBadgeBlue` | échec : badges de statut de vérification |
| 1.13 / 1.18:1 | séparateurs `outlineVariant` | **hors critère** : purement décoratif |
| 1.58:1 | `borderStrong` sur blanc | à confirmer selon l'usage |

Le texte blanc posé sur les pastilles d'urgence échoue en plus le seuil 4.5:1
(de 1.67:1 à 3.76:1 selon la couleur).

### 2.4 Ce qui passe

Le socle typographique est sain : texte principal 15.3:1 en clair, 15.2:1 en
sombre ; texte secondaire 8.0:1 et 7.9:1 ; liens 5.1:1 et 5.3:1. Le mode sombre
est globalement **meilleur** que le mode clair sur les couleurs sémantiques :
succès 5.6:1, avertissement 9.6:1, info 6.1:1.

### 2.5 Échecs calculés puis invalidés à la vérification

Ces paires sortaient rouges du calcul. Aucune n'existe à l'écran.

| Ratio calculé | Token | Pourquoi c'est un faux positif |
|---|---|---|
| 1.00:1 | `threadStatusOpen` | **token mort** : aucune référence dans `lib/` |
| 3.57:1 | `threadStatusNeutral` | **token mort** : idem |
| 1.84:1 | `purple` en sombre | jamais du texte : fond d'avatar (initiales blanches, 9.39:1) et icône sur `violetLight` figé |
| 2.61:1 | `teal` en sombre | fond d'avatar uniquement, 6.61:1 avec les initiales |
| 3.03:1 | `violet` en sombre | fond de tuile ou icône sur son propre fond pâle figé, jamais posé sur `surface` |
| 3.45:1 | `threadStatusGreen` | chip à fond clair figé #DCFCE7, ratio réel 4.57:1 |
| 3.70:1 | `threadStatusAmber` sur blanc | même chose, le fond réel est #FEF3C7 ; ratio réel 3.33:1, donc réellement en échec mais pas pour la raison calculée |

Leçon de méthode : un ratio calculé sur des tokens ne prouve rien tant que la
paire n'a pas été retrouvée dans le code. Un token peut être mort, servir de
fond plutôt que de texte, ou reposer sur un fond figé que le thème ne change
pas.

### 2.6 `DonyButton` court-circuite le thème

Découvert en corrigeant, pas au balayage. `DonyButton` n'utilise ni `cs.primary`
ni `cs.onPrimary` : chaque variant pleine peint un dégradé de couleurs
littérales, avec un libellé blanc forcé. Contraste du blanc sur la partie la
plus claire de chaque dégradé :

| Variant | Clair | Sombre |
|---|---|---|
| primary | 3.35:1 | 2.78:1 |
| success | 3.14:1 | 2.55:1 |
| destructive | 3.19:1 | 3.55:1 |
| accent | 2.63:1 | 2.63:1 |

Au centre du bouton, là où le libellé est réellement posé, seuls `primary`
clair (5.51:1) et `destructive` sombre (4.89:1) passent. Les six autres
combinaisons échouent.

Deux conséquences. D'abord, c'est le bouton d'action principale de chaque
écran, donc c'est l'échec 1.4.3 le plus visible de l'application. Ensuite, le
mode haut contraste du lot 1 **n'atteignait pas ce bouton du tout** : le thème
basculait, le bouton gardait son dégradé de marque.

Le corriger hors haut contraste suppose d'assombrir nettement les dégradés,
en particulier le terracotta, qui devient un brun. C'est une décision de
marque, elle n'appartient pas à l'audit.

---

## 3. Cibles tactiles — le résultat qui change le périmètre

Mesures rendues, `flutter test`, thème clair :

| Composant | Taille | ≥ 24 (AA) | ≥ 44 (Apple) | ≥ 48 (Material) |
|---|---|---|---|---|
| `DonyChip` | 81 × **27** | oui | non | non |
| `FavoriteHeartButton` | **40 × 40** | oui | non | non |
| `DonyRadioGroup`, une option | 360 × **37** | oui | non | non |
| `DonyListTile` | 360 × **41** | oui | non | non |
| `DonyCheckbox` | pleine largeur | oui | oui | oui |
| `DonyAppBar`, bouton retour | 56 × 55 | oui | oui | oui |
| `IconButton` Material | 48 × 48 | oui | oui | oui |

**Aucun composant n'échoue le critère AA.** Le critère de taille de cible au
niveau AA est le 2.5.8 de WCAG 2.2, et son seuil est **24 × 24**, pas 44 × 44.
Le 44 × 44 est le critère 2.5.5, de niveau **AAA**. WCAG 2.1, sur lequel le RGAA
s'aligne, ne comporte aucun critère de taille de cible au niveau AA.

Conséquence directe : le volet « cibles » du lot 2 n'est **pas** une exigence de
conformité, c'est une exigence de qualité d'usage. Les quatre composants en
dessous de 44 restent inconfortables au pouce, en particulier `DonyChip` à 27 px
qui sert aux filtres de recherche, et `FavoriteHeartButton` à 40 px.

Point d'attention distinct et lui bien AA : `DonyBackCircle` (40 × 40) est
**du code mort**, défini et jamais appelé depuis l'uniformisation des boutons
retour. Il doit être supprimé, pas corrigé.

---

## 4. Périmètre proposé

L'audit invalide l'hypothèse de départ du lot 2, qui plaçait contrastes et
cibles sur le même plan. Les cibles ne posent pas de problème de conformité ;
les contrastes en posent 39, dont trois qui sont des bugs d'affichage.

**Lot 2a — corrections bloquantes.** Les trois cas de priorité 0, plus les six
couleurs figées réutilisées en sombre. Toutes se règlent dans les tokens et le
`ColorScheme`, sans toucher aux écrans. Petit, à faible risque visuel, et corrige
du texte aujourd'hui illisible.

**Lot 2b — couleurs sémantiques.** Recalibrer `warning`, `success`, `accent`,
`info`, `error` et leurs variantes `*Light`, plus le placeholder des champs et la
bordure des champs. C'est le gros morceau : environ 400 usages cumulés, et la
correction change l'apparence de l'app pour tout le monde. À faire d'un bloc,
avec une passe de relecture visuelle.

**Lot 2c — cibles tactiles à 44 px.** Qualité d'usage, pas conformité.
`DonyChip`, `FavoriteHeartButton`, `DonyRadioGroup`, `DonyListTile`, plus la
suppression de `DonyBackCircle`. Peut être reporté sans effet sur la conformité
AA.

**Non traité ici :** les débordements hors des cinq parcours couverts au lot 1,
et le seuil de bascule de la bannière Stripe, tous deux consignés au registre du
lot 1.

---

## 5. Lot 2a livré

Corrections faites sur `feature/accessibilite-lot2a`, chacune gardée par un test
qui vire au rouge si on l'annule (`test/a11y/contrast_tokens_test.dart`).

| Correction | Avant | Après |
|---|---|---|
| `onPrimary` passe au noir en haut contraste sombre | 2.04:1 | 10.30:1 |
| `DonyButton` bascule sur un aplat en haut contraste, 4 variantes × 2 thèmes | 2.55 à 3.35:1 | ≥ 7:1 |
| placeholder des champs, mode sombre (`neutralDark400`) | 4.00:1 | 5.12:1 |
| texte sur conteneur primaire sombre (`blueDark50`) | 4.32:1 | 4.85:1 |
| initiales d'avatar sur terracotta (`terra500` → `terra700`) | 3.46:1 | 6.92:1 |
| chip « ATT. TRAJET » | 3.33:1 | 5.31:1 |
| chip « TERMINÉ » | 4.39:1 | 5.44:1 |

Deux goldens sombres régénérés (`dony_chip_selected_dark`,
`dony_empty_state_dark`) : l'écart est confiné au fond `primaryContainer`,
vérifié à l'image, sans effet sur le texte ni la mise en page.

Reste ouvert, en attente d'une décision de marque : les dégradés de
`DonyButton` hors haut contraste (section 2.6).

---

## 6. Reproduire l'audit

Le calculateur de ratios et le test de mesure des cibles n'ont pas été ajoutés au
dépôt : ils appartiennent au lot 4, qui outille la non-régression. Les valeurs
ci-dessus sont reproductibles à partir des tokens de
`lib/core/design/tokens/color_tokens.dart` et des paires assemblées dans
`lib/core/design/theme/app_theme.dart`.
