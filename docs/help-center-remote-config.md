# Centre d'aide — configuration Firebase Remote Config

Le Centre d'aide communautaire et tutoriels vidéo (réseaux sociaux + tutoriels
YouTube contextuels) est piloté par un unique paramètre Firebase Remote
Config : **`help_center_config_v1`**.

- Modèle Dart : `lib/features/profile/data/models/help_center_config.dart`
- Datasource : `lib/features/profile/data/datasources/help_center_remote_config_datasource.dart`
- Repository : `lib/features/profile/data/repositories/help_center_repository.dart`
- Fallback embarqué (asset) : `assets/config/help_center_config.default.json`

## 1. Exemple de JSON complet

À coller tel quel comme valeur du paramètre `help_center_config_v1` dans la
console Firebase Remote Config (type de valeur : **String**, contenu JSON).

Tous les réseaux sociaux et tous les tutoriels sont volontairement
**`"active": false`** dans cet exemple : il ne doit rien afficher tant qu'il
n'a pas été revu et activé délibérément (voir §4 activation progressive).
Les identifiants vidéo YouTube (`youtubeVideoId`) sont des chaînes factices
qui respectent seulement le format attendu (11 caractères
`[A-Za-z0-9_-]`) — ce ne sont pas de vrais identifiants de vidéo, à
remplacer par de vraies vidéos avant activation.

```json
{
  "schemaVersion": 1,
  "youtubeChannelUrl": "https://youtube.com/@yadony",
  "socialLinks": [
    {
      "network": "whatsapp",
      "url": "https://wa.me/33600000000",
      "active": false
    },
    {
      "network": "facebook",
      "url": "https://facebook.com/yadony",
      "active": false
    },
    {
      "network": "instagram",
      "url": "https://instagram.com/yadony",
      "active": false
    },
    {
      "network": "tiktok",
      "url": "https://tiktok.com/@yadony",
      "active": false
    },
    {
      "network": "youtube",
      "url": "https://youtube.com/@yadony",
      "active": false
    }
  ],
  "tutorials": [
    {
      "id": "tuto_recherche",
      "title": "Rechercher un trajet ou un colis",
      "description": "Comment utiliser la recherche pour trouver un trajet ou une demande compatible.",
      "youtubeVideoId": "PLACEHOLD01",
      "order": 1,
      "active": false,
      "contexts": ["search"],
      "durationLabel": "1:30"
    },
    {
      "id": "tuto_activites",
      "title": "Suivre mes activités",
      "description": "Vue d'ensemble du hub Activités : trajets, envois, demandes, négociations.",
      "youtubeVideoId": "PLACEHOLD02",
      "order": 2,
      "active": false,
      "contexts": ["activities"]
    },
    {
      "id": "tuto_publier_trajet",
      "title": "Publier un trajet",
      "description": "Étapes pour publier un trajet et déclarer l'espace bagage disponible.",
      "youtubeVideoId": "PLACEHOLD03",
      "order": 3,
      "active": false,
      "contexts": ["tripPublish"],
      "durationLabel": "2:10"
    },
    {
      "id": "tuto_publier_demande",
      "title": "Envoyer une demande de colis",
      "description": "Comment décrire un colis et publier une demande d'envoi.",
      "youtubeVideoId": "PLACEHOLD04",
      "order": 4,
      "active": false,
      "contexts": ["requestPublish"]
    },
    {
      "id": "tuto_negociation",
      "title": "Négocier une offre",
      "description": "Comprendre les contre-offres et accepter un prix.",
      "youtubeVideoId": "PLACEHOLD05",
      "order": 5,
      "active": false,
      "contexts": ["negotiation"]
    },
    {
      "id": "tuto_paiement",
      "title": "Payer en toute sécurité",
      "description": "Le paiement sécurisé (séquestre) et son déblocage à la livraison.",
      "youtubeVideoId": "PLACEHOLD06",
      "order": 6,
      "active": false,
      "contexts": ["payment"],
      "durationLabel": "1:45"
    },
    {
      "id": "tuto_remise_qr",
      "title": "Remettre le colis (QR code)",
      "description": "Scanner le QR code de remise et confirmer la prise en charge du colis.",
      "youtubeVideoId": "PLACEHOLD07",
      "order": 7,
      "active": false,
      "contexts": ["qrHandover"]
    },
    {
      "id": "tuto_suivi",
      "title": "Suivre mon colis",
      "description": "Lire la timeline de suivi et comprendre chaque étape.",
      "youtubeVideoId": "PLACEHOLD08",
      "order": 8,
      "active": false,
      "contexts": ["tracking"]
    },
    {
      "id": "tuto_litige",
      "title": "Ouvrir un litige",
      "description": "Quand et comment ouvrir un litige en cas de problème.",
      "youtubeVideoId": "PLACEHOLD09",
      "order": 9,
      "active": false,
      "contexts": ["dispute"]
    }
  ]
}
```

Les 9 tutoriels correspondent chacun à une valeur de l'enum
`TutorialContext` (`search`, `activities`, `tripPublish`, `requestPublish`,
`negotiation`, `payment`, `qrHandover`, `tracking`, `dispute`), c'est-à-dire
aux 9 points d'intégration de la `ContextualTutorialCard` (accueil,
activités, publication trajet, publication demande, thread de négociation,
paiement, remise QR, timeline de suivi, liste des litiges). Un tutoriel peut
lister plusieurs contextes dans son tableau `contexts` s'il est pertinent
pour plusieurs écrans ; l'exemple ci-dessus reste 1:1 par simplicité.

## 2. Validation locale avant publication

`HelpCenterConfig.fromJson` (voir
`lib/features/profile/data/models/help_center_config.dart`) applique les
règles suivantes — à vérifier avant de coller un JSON dans la console :

- **`schemaVersion`** doit valoir exactement l'entier `1`. Toute autre
  valeur lève une `FormatException('unsupported_schema')` qui fait
  échouer **tout le parsing** : le repository retombe alors sur la
  dernière configuration valide connue, ou sur le fallback embarqué
  (`assets/config/help_center_config.default.json`, qui est un catalogue
  vide et inoffensif). C'est la seule erreur qui invalide l'ensemble du
  document.
- **`socialLinks`** et **`tutorials`** sont tolérants entrée par entrée :
  si une entrée individuelle échoue à sa validation (champ manquant, type
  incorrect, URL non https, `youtubeVideoId` qui ne respecte pas le format
  11 caractères `^[A-Za-z0-9_-]{11}$`, `contexts` vide ou invalide…), cette
  entrée est simplement ignorée et les autres entrées valides restent
  disponibles. Une seule ligne cassée ne casse jamais tout le catalogue.
- **Doublons** : si deux réseaux sociaux partagent le même `network`, ou
  si deux tutoriels partagent le même `id`, seule la première occurrence
  rencontrée est conservée, les suivantes sont ignorées silencieusement.
- **`youtubeChannelUrl`** est optionnel. S'il est présent mais invalide
  (pas de schéma `https`, hôte vide), il est simplement ignoré : cela
  n'affecte ni les tutoriels ni les réseaux sociaux.
- Chaque tutoriel exige : `id`, `title`, `description` (chaînes non
  vides), `youtubeVideoId` (11 caractères `[A-Za-z0-9_-]`), `order`
  (entier, sert au tri croissant final), `active` (booléen), `contexts`
  (liste non vide de noms d'enum `TutorialContext` valides, sans doublon
  interne). `durationLabel` est une chaîne optionnelle (`null` accepté).
- Chaque réseau social exige : `network` (un des 5 noms d'enum
  `SocialNetwork` : `whatsapp`, `facebook`, `instagram`, `tiktok`,
  `youtube`), `url` (https, hôte non vide), `active` (booléen).

**Avant de publier**, valider localement le JSON (par exemple en le collant
dans `HelpCenterConfig.fromJson(jsonDecode(monJson))` via un test rapide, ou
en relisant la liste des règles ci-dessus) pour éviter de publier une
configuration où un tutoriel ou un réseau attendu serait silencieusement
absent à cause d'une faute de frappe.

## 3. Publier sur Firebase Remote Config

1. Console Firebase → projet `dony-dev` (ou projet de prod) → **Remote
   Config**.
2. Créer ou éditer le paramètre `help_center_config_v1` (respecter la
   casse et le suffixe `_v1` exactement — c'est la clé lue par
   `HelpCenterRemoteConfigDatasource.configKey`).
3. Type de données : **String**. Coller le JSON minifié ou formaté (les
   deux fonctionnent, `jsonDecode` ne se soucie pas de l'indentation).
4. **Publier les modifications** (bouton *Publish changes*). Chaque
   publication crée une nouvelle version dans l'historique Remote Config.

## 4. Tester en développement

- L'application configure `minimumFetchInterval` à **5 minutes en debug**
  (`kDebugMode`) contre **12 heures en production**
  (`HelpCenterRemoteConfigDatasource._configure`), et un `fetchTimeout` de
  10 secondes dans les deux cas.
- En dev, après une publication côté console, il suffit donc de relancer
  le hub d'aide (tirer pour rafraîchir, ou rouvrir l'écran) au bout de 5
  minutes maximum depuis le dernier fetch pour voir la nouvelle version
  activée. Pour forcer un test immédiat sans attendre les 5 minutes,
  redémarrer l'application (`_isConfigured` et le cache de fetch redémarrent
  à zéro à froid).
- Si le fetch échoue (pas de réseau, config malformée après fetch), le
  repository conserve la dernière configuration valide déjà activée
  (`_lastValid`) plutôt que de vider le hub — voir
  `HelpCenterRepository._refresh`.

## 5. Activation progressive (rollout)

Pour limiter le risque, activer les nouveaux tutoriels ou réseaux
progressivement plutôt que tous d'un coup :

1. Publier d'abord la configuration avec les nouvelles entrées à
   `"active": false` (comme dans l'exemple du §1) — elles sont alors
   présentes côté client mais invisibles pour les utilisateurs
   (`tutorialFor`/`tutorialById` et l'affichage des réseaux filtrent sur
   `active`).
2. Vérifier que le déploiement ne casse rien (l'app affiche toujours le
   hub, aucune régression de FAQ/résilience — voir contrôle manuel §6 du
   brief de tâche).
3. Utiliser les **conditions Remote Config** (pourcentage d'utilisateurs,
   version d'app, plateforme) pour publier une variante à `"active": true`
   ciblant d'abord une fraction du trafic, puis étendre progressivement la
   condition à 100 % une fois la confiance acquise.
4. Un tutoriel ou un réseau peut être désactivé individuellement à tout
   moment en repassant son `active` à `false` et en republiant — pas
   besoin de retirer l'entrée du JSON.

## 6. Retour arrière (rollback)

Firebase Remote Config conserve un historique de versions publiées.

1. Console Firebase → Remote Config → menu **History** (icône historique
   en haut de la page du paramètre).
2. Sélectionner la version précédente à restaurer.
3. **Restore** (ou "Revert to this version") : la version choisie
   redevient la version active, sans avoir à retaper le JSON.
4. Publier. Les clients récupéreront la version restaurée au prochain
   fetch réussi (jusqu'à 5 minutes en dev, 12 heures en prod, ou
   immédiatement si l'app est relancée à froid).

Comme le parsing est tolérant entrée par entrée (§2), même en cas d'erreur
partielle après une mauvaise publication, seules les entrées invalides
disparaissent le temps du rollback — le hub reste utilisable avec les
entrées restantes valides pendant l'intervalle.
