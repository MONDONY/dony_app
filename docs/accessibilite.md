# Accessibilité — ce qu'il faut vérifier avant de merger

Guide court, à lire quand on ajoute ou modifie de l'interface. Il ne remplace
pas les tests : `test/a11y/` échoue tout seul sur la plupart des points
ci-dessous. Il sert aux cas que les tests ne peuvent pas voir.

## Les cinq questions

**1. Une couleur nouvelle ?** Elle va dans `color_tokens.dart`, jamais posée
directement dans un écran. Le test `theme_contrast_audit_test.dart` balaie les
paires du thème dans ses quatre variantes ; s'il ne couvre pas votre cas,
ajoutez la paire plutôt que de contourner.

Seuils : **4.5:1** pour du texte, **3:1** pour un élément d'interface porteur
d'information (bordure de champ, icône de statut, pastille). Un fond décoratif
n'a aucune exigence.

**2. Un élément tappable ?** S'il ne contient **que** des icônes, il lui faut
un nom : `tooltip:` sur un `IconButton`, sinon
`Semantics(button: true, label: '...')`. Deux tests balaient les sources et
échouent sur toute omission.

Le nom décrit **l'action**, jamais le dessin. Une croix qui vide un champ de
recherche s'appelle « Effacer la recherche », pas « Fermer ». Un nom faux est
pire qu'un nom absent : il fait agir à contresens.

**3. Un message qui apparaît après coup ?** Erreur de validation, confirmation,
échec : il doit être une région live, sinon un lecteur d'écran ne le dit
jamais. `DonyFieldError`, `DonyStatusBanner` et `DonySnackbar` le font déjà.
Un message écrit à la main ne le fait pas.

**4. Une information portée par la couleur seule ?** Elle doit exister
autrement : icône, mot, ou état sémantique. C'est le critère 1.4.1, et c'est
celui qu'on oublie le plus souvent, parce qu'à l'écran tout paraît clair.

**5. Un formulaire de plusieurs champs ?** Chaînez-les :
`textInputAction: TextInputAction.next` sur les intermédiaires, `done` sur le
dernier. Jamais sur un champ multiligne, la touche entrée doit y insérer un
saut de ligne.

## Ce que les tests ne voient pas

À vérifier sur appareil, parce qu'aucun test ne le fera :

- Le rendu à **200 %** de taille de texte. Les tests vérifient l'absence de
  débordement sur cinq parcours seulement.
- Le **haut contraste**, en clair et en sombre.
- Le comportement réel de **VoiceOver et TalkBack**. Les tests prouvent que les
  annotations sont posées, pas que le système les lit comme prévu.
- Si le résultat est **beau**. Un ratio conforme peut être laid.

## Les pièges rencontrés

Consignés parce qu'ils ont chacun coûté un aller-retour.

- Un `Semantics(label:)` sur un bouton à icône seule **ne crée aucun nœud**
  sans `container: true`. Le libellé disparaît en silence.
- `VisualDensity.compact` retranche 4 points sur chaque axe et écrase une
  contrainte de taille minimale.
- Une troncature `maxLines: 1` **ne lève aucune exception**. Il faut mesurer la
  hauteur rendue pour la détecter.
- Un `Wrap` ne remplace pas un `Row` + `Expanded` : `Wrap` dimensionne chaque
  enfant indépendamment contre toute la largeur.
- En mode sombre, un aplat de marque ne peut pas à la fois porter un libellé
  blanc et rester distinct du fond. Les deux critères tirent en sens inverse :
  on garde l'aplat vif et on assombrit le libellé.
- Un ratio calculé sur un token ne prouve rien tant que la paire n'a pas été
  retrouvée dans le code. Un token peut être mort, servir de fond plutôt que de
  texte, ou reposer sur un fond figé que le thème ne change pas.

## Repères de conformité

La cible est **WCAG 2.1 niveau AA**, ce que vise le RGAA et ce qu'exige
l'European Accessibility Act pour le commerce en ligne.

Un point contre-intuitif : le critère de **taille de cible** au niveau AA est
le 2.5.8 de WCAG 2.2, et son seuil est **24 × 24**, pas 44 × 44. Le 44 × 44
relève du 2.5.5, de niveau AAA, et WCAG 2.1 n'impose aucun seuil. Les 44 points
appliqués dans le design system sont donc un choix de confort, pas une
obligation.
