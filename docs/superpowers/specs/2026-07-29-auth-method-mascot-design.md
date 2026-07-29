# Mascotte de l’écran de connexion

## Contexte

L’écran `AuthMethodScreen` affiche actuellement un papillon générique dans un
`DonyHeroAvatar`. Ce visuel ne représente pas l’identité de Yadony alors que la
mascotte officielle est déjà disponible dans le design system.

## Design validé

- Remplacer uniquement le `DonyHeroAvatar(emoji: '🦋')` par
  `DonyMascotteAnimated`.
- Utiliser le preset `DonyMascotteType.joyeux`, dont la pose accueillante
  correspond au titre « Connecte-toi ».
- Utiliser `DonyMascotteSize.md` (96 pt) afin de conserver la hiérarchie et
  l’encombrement visuel actuels.
- Conserver le centrage, les espacements et le reste de l’écran inchangés.
- S’appuyer sur l’animation et le libellé sémantique fournis par
  `DonyMascotteAnimated`, sans animation supplémentaire autour du widget.

## Hors scope

- Aucun nouvel asset.
- Aucun changement de texte, de méthode d’authentification, de BLoC, de route
  ou de tracking.
- Aucun changement des autres usages de `DonyHeroAvatar`.

## Tests

Le test widget de l’écran vérifiera que :

- la mascotte animée est affichée avec le type `joyeux` et la taille `md` ;
- le papillon et `DonyHeroAvatar` ne sont plus rendus ;
- les actions d’authentification existantes restent disponibles.
