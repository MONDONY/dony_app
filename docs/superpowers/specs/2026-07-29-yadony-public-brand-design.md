# Harmonisation de la marque publique Yadony

## Objectif

Uniformiser l'identité publique des trois interfaces :

- l'application mobile Flutter `dony_app` ;
- l'espace voyageurs `dony-pro` ;
- le back-office `dony-admin`.

Le nom affiché doit être **Yadony**, avec les déclinaisons **Yadony PRO** et
**Yadony ADMIN**. Le mot-logo officiel et les mascottes existantes de
`dony_app` deviennent les sources visuelles communes.

## Périmètre

### Application mobile

- Vérifier et corriger le nom affiché par Flutter, Android et iOS.
- Remplacer toute ancienne mention publique résiduelle de Dony par Yadony.
- Conserver le mot-logo `assets/logos/logo-yadony.png`.
- Conserver les icônes, écrans de lancement et mascottes Yadony déjà installés.

### Yadony PRO

- Copier le mot-logo officiel depuis `dony_app`.
- Remplacer les anciens logos et marques textuelles visibles par Yadony PRO.
- Copier la mascotte `travel.png` depuis `dony_app` et l'intégrer au panneau de
  connexion.
- Corriger les titres de pages, métadonnées sociales, textes éditoriaux,
  libellés, liens nommés et attributs d'accessibilité exposés à l'utilisateur.

### Yadony ADMIN

- Copier le mot-logo officiel depuis `dony_app`.
- Remplacer les marques textuelles visibles par Yadony ADMIN.
- Conserver la mascotte de sécurité `securise.png`, déjà adaptée au contexte
  administratif.
- Corriger les titres de pages, métadonnées, libellés et attributs
  d'accessibilité exposés à l'utilisateur.

## Identifiants techniques préservés

Le changement ne constitue pas une migration technique. Les éléments suivants
restent inchangés :

- noms des dépôts et packages (`dony_app`, `dony-pro`, `dony-admin`) ;
- classes et widgets `Dony*` ;
- clés de stockage telles que `dony-theme` et `dony-admin-session` ;
- variables de test comme `__donyAuthSeed` ;
- classes CSS internes et noms d'événements ;
- schémas, identifiants Firebase et autres contrats externes existants.

Les URLs historiques sont conservées lorsqu'aucune destination Yadony active et
vérifiée n'est disponible. Leur libellé visible doit néanmoins employer Yadony.

## Intégration visuelle

Le mot-logo conserve son ratio et n'est jamais recréé en texte lorsque l'espace
permet d'utiliser l'asset officiel. Les badges PRO et ADMIN restent des éléments
distincts accolés au logo.

Sur Yadony PRO, `travel.png` rejoint le panneau gauche de connexion sans
supprimer l'accroche ni les éléments de réassurance. Sa taille doit rester
responsive, sans déplacement de mise en page ni débordement sur les petits
écrans pris en charge.

Sur Yadony ADMIN, `securise.png` reste la mascotte de la connexion. Seuls son
contexte de marque, son texte alternatif et le logo adjacent sont harmonisés.

Les images reçoivent un texte alternatif descriptif et les interactions
existantes conservent leurs zones tactiles et leurs transitions ciblées.

## Tests et vérifications

### Flutter

- Mettre à jour ou ajouter les tests couvrant les noms publics modifiés.
- Exécuter `flutter analyze`.
- Exécuter `flutter test --coverage`.
- Vérifier que la couverture globale reste au moins égale à 90 %.

### Yadony PRO et Yadony ADMIN

- Mettre à jour les tests de composants affectés par le logo, la mascotte ou les
  libellés.
- Exécuter `pnpm lint`, `pnpm test`, `pnpm test:coverage` et `pnpm build` dans
  chaque projet.
- Conserver les seuils de couverture configurés.

### Contrôle final de marque

Une recherche finale distingue :

- les occurrences visibles, qui doivent toutes employer Yadony ;
- les occurrences techniques explicitement préservées ;
- les archives, documents historiques et sorties de build, qui ne déterminent
  pas l'identité publique active.

## Critères d'acceptation

- Le nom public de l'application mobile est Yadony sur Android et iOS.
- Aucun écran actif des trois interfaces ne présente Dony comme nom de marque.
- Yadony PRO et Yadony ADMIN utilisent le mot-logo officiel de `dony_app`.
- Yadony PRO affiche `travel.png` sur sa connexion.
- Yadony ADMIN affiche `securise.png` avec un contexte et un texte alternatif
  Yadony.
- Les badges PRO et ADMIN restent lisibles dans les thèmes clair et sombre.
- Les identifiants techniques internes restent compatibles.
- Les analyses, tests, couvertures et builds requis réussissent.
