# Centre d’aide communautaire et tutoriels vidéo — conception

## Objectif

Étendre le Centre d’aide Yadony existant pour permettre aux utilisateurs :

- de rejoindre les communautés officielles Yadony ;
- de découvrir les parcours critiques grâce à des tutoriels YouTube lus dans
  l’application ;
- de retrouver le bon tutoriel directement depuis l’écran où ils ont besoin
  d’aide ;
- de s’abonner à la chaîne YouTube Yadony.

Les vidéos restent hébergées par YouTube. Elles ne sont ni intégrées dans
l’APK/IPA ni téléchargées durablement par Yadony.

## Périmètre fonctionnel

### Centre d’aide

La route existante `/profile/help/faq` devient un hub composé de trois blocs :

1. **Trouver une réponse** conserve la recherche et les catégories de la FAQ.
2. **Tutoriels vidéo** présente le catalogue de vidéos configurées.
3. **Rejoindre la communauté** expose les destinations sociales actives.

Les destinations prévues sont :

- canal WhatsApp ;
- groupe Facebook ;
- compte Instagram ;
- compte TikTok ;
- chaîne YouTube.

Une destination sans URL valide ou marquée inactive n’est pas affichée.
L’entrée YouTube utilise le libellé d’action « S’abonner » ; les autres
utilisent « Rejoindre » ou « Suivre » selon le réseau.

### Catalogue initial

Le catalogue comprend neuf tutoriels :

1. découvrir Yadony et utiliser la recherche ;
2. comprendre l’espace Activités ;
3. publier un trajet ;
4. publier une demande d’envoi ;
5. négocier une offre ;
6. accepter une offre et payer ;
7. effectuer la remise et le retrait avec les QR codes ;
8. lire et suivre l’acheminement d’un colis ;
9. ouvrir et suivre un litige.

Chaque entrée comporte un identifiant stable, un titre, une description courte,
un identifiant vidéo YouTube, une miniature, un ordre, un statut actif et une
liste de contextes d’affichage.

### Aide contextuelle

Un composant compact « Besoin d’aide ? Voir le tutoriel » est ajouté aux
écrans correspondant aux neuf parcours. Il ne bloque jamais le parcours
métier et reste visuellement secondaire.

Le composant ouvre la route
`/profile/help/tutorial/:tutorialId`. Si le tutoriel est absent ou désactivé,
le composant n’est pas affiché. La navigation ne modifie aucune donnée métier ;
aucun rafraîchissement de l’écran appelant n’est nécessaire au retour.

## Configuration distante

### Source

Firebase Remote Config porte un paramètre JSON versionné
`help_center_config_v1`. Ce choix réutilise Firebase, déjà présent dans la
stack, et permet de modifier les liens, l’ordre et la visibilité sans publier
une nouvelle version de l’application.

Le document JSON contient :

- `schemaVersion` ;
- `socialLinks` ;
- `youtubeChannelUrl` ;
- `tutorials`.

Les modèles Dart valident strictement les identifiants, les URL HTTPS, les
identifiants vidéo, les doublons et les contextes connus. Un élément invalide
est ignoré sans rendre le reste du Centre d’aide indisponible.

### Valeurs par défaut et cache

L’application embarque une configuration par défaut vide mais valide. Au
démarrage du dépôt d’aide :

1. la dernière valeur Remote Config activée est lue immédiatement ;
2. un rafraîchissement distant est tenté avec un délai borné ;
3. une nouvelle valeur valide remplace le catalogue affiché ;
4. en cas d’échec, la dernière valeur activée reste utilisée ;
5. si aucune configuration exploitable n’existe, la FAQ et le contact restent
   disponibles, tandis que les sections sociales et vidéo sont masquées.

La fréquence minimale de récupération est configurable par environnement :
courte en développement et raisonnable en production. Une erreur de
configuration ne doit jamais bloquer le démarrage de Yadony.

## Architecture Flutter

La fonctionnalité reste dans `features/profile`, qui possède déjà le Centre
d’aide, et respecte ses trois sous-dossiers :

- `data/models` : `HelpCenterConfig`, `SocialLink`, `HelpTutorial` et enums ;
- `data/datasources` : lecture de Firebase Remote Config ;
- `data/repositories` : validation, valeur active et rafraîchissement ;
- `bloc` : chargement du catalogue et intentions analytics ;
- `presentation` : hub enrichi, cartes sociales, cartes tutoriels, aide
  contextuelle et écran lecteur.

`HelpCenterBloc` reçoit `HelpCenterRepository` et `AnalyticsService` par GetIt.
Il expose les états `initial`, `loading`, `success` et `error`. L’état `error`
peut conserver une configuration précédente afin que l’interface reste
utilisable.

Les écrans métiers consomment un sélecteur en lecture seule du catalogue. Ils
ne construisent pas de service et ne contiennent aucune URL codée en dur.

## Lecteur YouTube intégré

L’écran tutoriel utilise un lecteur YouTube Flutter compatible iOS et Android.
Il diffuse la vidéo depuis YouTube dans Yadony et respecte le ratio 16:9.

L’écran contient :

- une app bar Yadony avec retour adaptatif iOS/Android ;
- le lecteur ;
- le titre et la description ;
- une indication qu’une connexion Internet est nécessaire ;
- « Ouvrir dans YouTube » comme solution de repli ;
- « S’abonner à la chaîne » ouvrant l’URL de la chaîne.

Le lecteur gère chargement, lecture, pause, fin, vidéo indisponible et erreur
réseau. Une vidéo indisponible affiche « Réessayer » et « Ouvrir dans
YouTube ». L’ouverture externe passe par `url_launcher`.

La rotation et le plein écran sont autorisés par le lecteur, sans modifier
l’orientation globale des autres écrans.

## Interface et accessibilité

Le design reprend l’intention de la référence fournie sans la copier :

- fond `kBackground`, surfaces blanches et accent vert Yadony ;
- cartes de rayon 16, padding interne 16 et espacement horizontal 20 ;
- cibles tactiles d’au moins 44 × 44 ;
- Plus Jakarta Sans, aucun texte inférieur à 12 ;
- miniatures 16:9 avec bouton lecture et durée ;
- icônes colis, avion ou lecture appropriées, jamais d’icône camion ;
- animations d’entrée `flutter_animate` de 250 à 300 ms ;
- libellés et semantics explicites pour les lecteurs d’écran.

Le hub affiche d’abord les réponses, puis les tutoriels, puis la communauté.
Sur petit écran ou avec un grand facteur de texte, les cartes passent en liste
verticale sans troncature des actions.

## Analytics

Tous les noms sont déclarés dans `AnalyticsEvents`, tous les appels sont
`unawaited()` et aucune PII n’est envoyée.

Événements prévus :

- `help_center_opened` ;
- `help_tutorial_opened` avec `tutorial_id` et `source` ;
- `help_tutorial_play_started` avec `tutorial_id` ;
- `help_tutorial_completed` avec `tutorial_id` ;
- `help_tutorial_external_opened` avec `tutorial_id` ;
- `help_social_link_opened` avec `network` ;
- `help_youtube_subscribe_tapped` avec `source` ;
- `help_config_load_failed` avec un `reason` contrôlé.

`source` appartient à une liste fermée : `help_center`, `search`,
`activities`, `trip_publish`, `request_publish`, `negotiation`, `payment`,
`qr_handover`, `tracking` ou `dispute`.

## Gestion des erreurs

- Configuration distante indisponible : conserver la dernière valeur et la
  FAQ.
- JSON partiellement invalide : ignorer uniquement les entrées concernées.
- Aucun lien social actif : masquer la section Communauté.
- Aucun tutoriel actif : masquer la section Tutoriels et les aides
  contextuelles.
- Pas de réseau pendant la lecture : afficher l’état hors connexion et
  permettre de réessayer.
- Application sociale absente : ouvrir l’URL HTTPS dans le navigateur.
- YouTube indisponible dans le lecteur : proposer l’ouverture externe.

## Tests et vérification

- Tests modèles : parsing, versions, URL invalides, doublons et éléments
  partiellement invalides.
- Tests repository/BLoC : valeur activée, rafraîchissement, cache, erreur avec
  données précédentes et analytics.
- Tests widgets du hub : ordre des sections, éléments masqués et accessibilité.
- Tests lecteur : chargement, erreur, nouvelle tentative, ouverture YouTube et
  abonnement.
- Tests des neuf intégrations contextuelles : visibilité, bonne route et bonne
  source analytics.
- Tests de mise en page avec grand texte.
- `dart format`, tests ciblés, `flutter analyze`, puis suite Flutter complète
  avant toute déclaration de réussite.

## Déploiement du contenu

La première version peut être livrée avec la FAQ seule. Lorsque les liens sont
prêts, l’administrateur publie `help_center_config_v1` dans Firebase Remote
Config. Les nouvelles valeurs deviennent disponibles sans mise à jour des
stores après le prochain rafraîchissement autorisé.

Une procédure documentée fournira un exemple JSON, les identifiants de
contexte autorisés et une checklist de validation avant publication.

## Hors périmètre

- hébergement ou téléchargement hors ligne des vidéos ;
- upload de vidéos depuis l’application ;
- commentaires YouTube intégrés ;
- authentification YouTube dans Yadony ;
- tableau de bord CMS sur mesure ;
- notifications automatiques lors de la publication d’un tutoriel.
