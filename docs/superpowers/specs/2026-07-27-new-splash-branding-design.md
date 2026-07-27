# Nouveau branding des splash screens

## Objectif

Remplacer l'identité visuelle des deux écrans de démarrage de dony en utilisant
les nouveaux assets, sans modifier le flux d'authentification ni la logique de
vérification du backend.

Les deux écrans doivent fonctionner sur les téléphones et tablettes iOS et
Android, y compris les petits écrans, les écrans très allongés et les appareils
utilisant une grande taille de texte.

## Assets

Les fichiers sources restent inchangés dans `assets/new_assets/`.

- `app-icon.png` : visuel central du splash natif.
- `logo-name.png` : logo horizontal du splash Flutter.
- Les mascottes sont conservées pour les futurs écrans, mais ne sont pas
  affichées dans les deux splash screens concernés.

Des dérivés recadrés et redimensionnés peuvent être générés dans les dossiers
d'assets existants. Ils doivent préserver les proportions et la qualité des
sources. Les variantes Android 12 doivent respecter la zone de sécurité imposée
par le masque système.

## Splash natif

Le splash natif utilise un fond clair uniforme et affiche `app-icon.png` centré.
Le fond et le premier frame Flutter utilisent exactement la même couleur afin
d'éviter un flash pendant la transition.

Le visuel reste statique. Sa taille est définie par les mécanismes natifs générés
par `flutter_native_splash`, avec une variante spécifique Android 12. Il ne doit
être ni étiré, ni rogné par les masques Android, ni entouré d'un rectangle dont
la couleur diffère du fond.

## Splash Flutter

Le splash Flutter conserve la logique de l'écran actuel :

- contrôle de disponibilité du backend ;
- résolution de la session et de la prochaine route ;
- indicateur de chargement ;
- message de connexion impossible ;
- action `Réessayer`.

La composition visuelle devient, de haut en bas :

1. `logo-name.png`, recadré sur son contenu utile ;
2. le texte `Livrez vos colis en confiance` ;
3. la version `v1.0.0` ;
4. l'indicateur de chargement ou l'état d'erreur.

Le logo apparaît avec un fondu et un léger déplacement vertical. Les inscriptions
apparaissent ensuite avec un fondu court. L'animation ne bloque jamais la
navigation lorsque l'initialisation est terminée.

## Responsive et accessibilité

La mise en page repose sur les contraintes disponibles, pas sur une taille
d'écran fixe.

- Le contenu respecte `SafeArea` et les encoches système.
- La largeur du logo est bornée par un minimum adapté aux petits écrans et un
  maximum adapté aux tablettes.
- La hauteur disponible limite également la taille du logo afin de préserver
  l'indicateur et l'état d'erreur.
- Les proportions originales des images sont toujours conservées.
- Un défilement de secours empêche tout débordement sur un écran court ou avec
  une grande taille de texte.
- Les textes peuvent revenir à la ligne et restent centrés.
- L'indicateur et le bouton de nouvelle tentative respectent une cible tactile
  minimale de 44 points.
- `MediaQuery.disableAnimations` supprime les animations décoratives lorsque
  l'utilisateur demande une réduction des animations.

## Tracking

La route `/splash` reste inchangée et continue à bénéficier du suivi automatique
des écrans. Aucun nouvel événement métier n'est nécessaire : la modification
est uniquement visuelle et n'ajoute aucune nouvelle action utilisateur.

## Vérification

La livraison est validée avec :

- génération réussie des ressources `flutter_native_splash` et des icônes ;
- analyse statique Flutter ciblée ;
- tests existants du splash, complétés si nécessaire pour la composition et
  l'état d'erreur ;
- inspection visuelle sur un petit téléphone, un téléphone standard et une
  tablette ;
- inspection Android 12 pour confirmer la zone de sécurité du masque ;
- vérification de l'absence de débordement avec une grande taille de texte et
  avec les animations désactivées.
