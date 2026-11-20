# Cartes trajet : j'aime, partage et favori en pied de carte

Date : 2026-11-20 · Taille : petit changement (app + back jumeau)
Maquette validée : https://claude.ai/artifact/F3vHoJp8G57zg2aRRqX4v5

## Intention
Permettre à n'importe quel utilisateur d'aimer un trajet sans le commander, et de le partager sans ouvrir le détail. Plus de signaux d'intérêt visibles, plus de partages hors de l'app.

## À faire
- Carte `TripCard` (accueil, vue carte, favoris) : le dessin actuel ne change pas. On ajoute **une ligne d'icônes en pied de carte**, sous un filet comme les autres sections, sans barre ni cadre : ♡ (avec compteur) et partage (flèche courbe) à gauche, signet favoris à droite. Icônes seules (nom en `Semantics`/tooltip), zones de 44 px. **Sélectionné = bleu Yadony** (`DonyColors.primary`, icône pleine) pour le ♡ et le signet ; le partage est une action sans état, bleu seulement pendant l'appui.
- Le ♡ est un **j'aime public** (nouveau, avec compteur). Le signet reste le **favori privé** existant (`FavoriteIdsCubit`), déplacé dans la barre. Les deux gestes sont indépendants.
- Le partage ouvre l'affiche du trajet (`TripPosterScreen`), comme le détail.
- Icône de partage : **flèche courbe** (nouvel asset SVG) à la place de `share-2`, aussi dans l'en-tête du détail (`_SharePosterButton`, `trip_owner_detail_screen`).
- Le voyageur sur son propre trajet : compteur de j'aime visible, pas de bouton j'aime ni signet.
- Back (PR jumelle, fusionnée et déployée avant l'app) : table des j'aime (un par utilisateur et trajet, pas sur son propre trajet), routes aimer et ne plus aimer, `likeCount` et `likedByMe` dans la réponse des annonces. Migration V(n+1). Compteur 0 tant que le back n'est pas déployé : champs optionnels côté app.

## Décisions validées (20/11)
- Visiteur sans compte : peut mettre un favori (inchangé), mais le ♡ ouvre une invitation à se connecter (pas de j'aime anonyme).
- Voyageur sur son propre trajet : la carte garde la ligne, avec compteur de j'aime en lecture seule + partage, sans signet.
- Fiche du trajet (billet) : pas de ♡ dans l'en-tête, seule l'icône de partage change.
- Compteur : affiché seulement à partir de 1 j'aime ; à 0, le ♡ s'affiche seul.
- Détail propriétaire : la ligne d'audience de la tuile « Affiche » ajoute les j'aime (« 128 personnes ont vu votre trajet · 24 j'aime »), visible par le voyageur seul.

- Classement : les j'aime comptent dans le score de la recherche (nouveau poids `likes`, 10 sur 110 par défaut, réglable par `YADONY_RANKING_WEIGHT_LIKES`). Le bonus sature à 20 j'aime et ignore les j'aime des comptes supprimés, pour limiter le gonflage. Sans j'aime, l'ordre reste celui d'avant.

## Hors périmètre
- Vues : restent privées (`/insights`, propriétaire seulement). Aucun changement.
- Demandes de colis, cartes « Mes trajets », autres écrans : inchangés.
- Pas de liste de « qui a aimé ».

## Contraintes du projet
- BLoC (pas de `setState`), GoRouter, textes par l10n FR + EN, zones de toucher ≥ 44 px, aucun dégradé.
- Analytics : événements dans `AnalyticsEvents` (j'aime, annulation, partage depuis la carte), tirés dans le BLoC, table de `CLAUDE.md` mise à jour.
- Fiches de l'assistant IA du back : à vérifier (parcours visible modifié).
- Tests : BLoC, widget (barre, états), back (service + contrôleur), couverture ≥ 90 %.

## Approches considérées
1. **Barre en pied à trois boutons (retenue)** : prix et en-tête inchangés, actions à portée du pouce.
2. Icônes dans l'en-tête : en-tête déjà chargé, loin du pouce.
3. Actions dans la ligne de date : déplace le prix, rejetée par le propriétaire.

## Laissé au constructeur
- Animation du ♡ (pop court, désactivée avec « réduire les animations »).
- Mise à jour optimiste du compteur et retour arrière en cas d'échec.
- Choix du nom de la table et des routes côté back, en suivant les favoris existants.
