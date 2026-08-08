# Carousel de guidance evergreen — écran Recherche

## Problème

Sur l'écran Recherche (`home_screen.dart`), deux problèmes UX identifiés :

1. Les utilisateurs ne savent pas qu'ils peuvent publier un trajet (voyageur) ou publier une demande d'envoi (expéditeur) quand aucun résultat ne leur correspond. Le seul CTA existant, `RoleGuidanceBanner`, est **inerte** : instancié sans `onCtaTap` dans `home_screen.dart:1613`, son bouton ne fait rien. Il ne s'affiche en plus qu'une fois (avant la 1ère publication), donc invisible pour la majorité des sessions.
2. Le toggle Trajets/Colis (`SearchModeSelector`, pilule ✈️/📦) est mal compris — noyé dans la rangée de chips, aucune explication de son fonctionnement.

## Inspiration

Application Skilo (captures fournies) : carousel en haut de l'écran d'accueil, rotation automatique à intervalle régulier, indicateur à points, une carte plein-format par sujet (créer alerte, parrainage, envoyer colis, publier trajet, vérifier identité), CTA blanc sur fond couleur pleine.

## Solution

Remplacer `RoleGuidanceBanner` + `ContextualTutorialCard` (actuellement deux blocs statiques dans `_buildSheet()`, `home_screen.dart` ~1613-1631) par un unique composant **`EvergreenGuidanceCarousel`**, positionné au même endroit : dans le `CustomScrollView` de la bottom sheet, juste avant la liste de résultats (`TravelerCard`/`PackageRequestListCard`), visible dans les deux modes Trajets et Colis.

## Composant

`EvergreenGuidanceCarousel` — nouveau widget, `lib/features/home/presentation/widgets/evergreen_guidance_carousel.dart`.

- `PageView` horizontal + indicateur à points en haut (façon Skilo).
- Auto-rotation toutes les 4 secondes. Interrompue pendant un swipe manuel de l'utilisateur, reprend après quelques secondes d'inactivité.
- Chaque slide = `_GuidanceSlide` interne : icône, titre, sous-titre, bouton CTA blanc sur fond couleur pleine (réutilise le style visuel `Container` + `DonyRadius.full`/large déjà utilisé par `RoleGuidanceBanner`).
- 0 slide éligible → `SizedBox.shrink()` (carousel disparaît, pas de trou dans la sheet).
- 1 seule slide éligible → affichage statique, pas de dots, pas de rotation.
- Composant de présentation pur : reçoit ses booléens en entrée, aucune logique métier/réseau interne. Tap CTA → `context.push(route)` (GoRouter, jamais `Navigator.push`).

## Slides

Pas de filtrage par rôle : dans dony, un utilisateur a toujours les deux rôles (voyageur + expéditeur) simultanément.

| Slide | Couleur | CTA → route | Condition de masquage |
|---|---|---|---|
| Publier mon trajet | bleu primary | `/trips/publish-intro` | masquée si `HiveService.kHasPublishedAsTraveler` (flag existant, réutilisé) |
| Envoyer un colis | vert | `/parcels/send-intro` | masquée si `HiveService.kHasPublishedAsSender` (flag existant, réutilisé) |
| Créer une alerte corridor | orange/accent | `/corridor-alerts` | masquée si l'utilisateur a déjà ≥1 alerte active |
| Vérifier mon identité | teal | `/kyc/verify` | masquée si KYC déjà vérifié |
| Tuto — comprendre l'onglet Trajets/Colis | contenu actuel `ContextualTutorialCard` | pas de route, ouvre le tuto inline | **jamais masquée** — explique le fonctionnement du toggle, evergreen par nature |

Aucun dismiss manuel (pas de croix). La disparition d'une slide est 100% pilotée par l'état applicatif (action faite → slide disparaît à la prochaine visite de l'écran). Les clés Hive `kTravelerBannerDismissed`, `kSenderBannerDismissed`, `senderBannerLifetime` deviennent du dead code à supprimer avec `RoleGuidanceBanner`.

## Flux de données

- `home_screen.dart` calcule les booléens d'entrée et les passe au widget :
  - `hasPublishedTrip` / `hasPublishedParcel` : flags Hive déjà lus ailleurs dans le fichier.
  - `isKycVerified` : déjà disponible via le bloc auth/profil chargé au shell.
  - `hasActiveCorridorAlert` : nouveau champ simple — flag Hive local mis à jour à la création d'une alerte, ou lecture du state déjà chargé par le bloc/repo alertes existant si disponible en mémoire. Pas de nouvel appel réseau bloquant pour l'affichage de la sheet.
- Filtrage des slides une seule fois au `build()` → `List<_GuidanceSlide> visibleSlides`.

## Gestion des erreurs

- Composant purement présentation : pas d'état d'erreur réseau dédié.
- Si `hasActiveCorridorAlert` dépend d'un bloc pas encore chargé au moment du build : la slide "Créer une alerte" reste **visible par défaut** (fail-open). Au pire une slide affichée en trop une fois, jamais de crash ni d'exception avalée.
- `visibleSlides` vide → carousel disparaît complet sans logique conditionnelle supplémentaire côté parent.

## Tests

- Widget test `EvergreenGuidanceCarousel` : chaque combinaison de flags d'entrée → bon sous-ensemble de slides rendu (une `Key` dédiée par slide).
- Tap CTA → vérifie que la bonne route est poussée via GoRouter (mock `context.push`).
- Cas 0 slide → `SizedBox.shrink()`. Cas 1 slide → pas de `PageView` rotatif, pas de dots.
- Auto-rotation : `tester.pump(Duration(seconds: 4))` → changement de page attendu. Un swipe manuel juste avant interrompt le timer (pas de changement de page inattendu juste après un drag).
- Suppression de `RoleGuidanceBanner` + `ContextualTutorialCard` de `home_screen.dart` → adapter/supprimer les tests qui les référencent en conséquence (suppression volontaire assumée par ce design, pas une régression à restaurer).
- Couverture ≥ 90% conforme CLAUDE.md.

## Hors scope

- Pas de retouche au `SearchModeSelector` lui-même (toggle ✈️/📦) — le problème de compréhension du toggle est traité via la slide tuto, pas via une refonte du composant.
- Pas de changement du contenu du tuto existant (`ContextualTutorialCard`), seulement son déplacement en slide.
- Pas de personnalisation du carousel par rôle actif ou par mode (Trajets/Colis) — mêmes slides dans les deux modes.
