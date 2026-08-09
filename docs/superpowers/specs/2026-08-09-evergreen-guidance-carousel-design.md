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
- Le composant reçoit en entrée uniquement `HiveService hiveService` et `bool isKycVerified` (KYC vient du backend via `AuthBloc`, pas de Hive) ; il lit lui-même les 3 flags Hive (réactif via `ValueListenableBuilder`, même pattern que `RoleGuidanceBanner`) et l'état du tuto via `HelpCenterBloc` (même pattern que `ContextualTutorialCard`). Tap CTA → `context.push(route)` (GoRouter, jamais `Navigator.push`).

## Slides

Pas de filtrage par rôle : dans dony, un utilisateur a toujours les deux rôles (voyageur + expéditeur) simultanément.

| Slide | Couleur | CTA → route | Condition de masquage |
|---|---|---|---|
| Publier mon trajet | bleu primary | `/trips/publish-intro` | masquée si `HiveService.kHasPublishedAsTraveler` (flag existant, réutilisé) |
| Envoyer un colis | vert | `/parcels/send-intro` | masquée si `HiveService.kHasPublishedAsSender` (flag existant, réutilisé) |
| Créer une alerte corridor | orange/accent | `/corridor-alerts` | masquée si l'utilisateur a déjà ≥1 alerte active |
| Vérifier mon identité | teal | `/kyc/verify` | masquée si KYC déjà vérifié |
| Tuto — comprendre l'onglet Trajets/Colis | contenu actuel `ContextualTutorialCard` | pas de route, ouvre `/profile/help/tutorial/{id}` | masquée si aucun tutoriel `TutorialContext.search` n'est configuré côté remote config (`HelpCenterConfig.tutorialFor`), ou si l'utilisateur l'a déjà fermé via la croix historique de `ContextualTutorialCard` (`kContextualTutorialDismissedPrefix`, respectée pour ne pas re-imposer un contenu déjà explicitement écarté) |

Aucun dismiss manuel (pas de croix). La disparition d'une slide est 100% pilotée par l'état applicatif (action faite → slide disparaît à la prochaine visite de l'écran). Les clés Hive `kTravelerBannerDismissed`, `kSenderBannerDismissed`, `senderBannerLifetime` deviennent du dead code à supprimer avec `RoleGuidanceBanner`.

## Flux de données

- `home_screen.dart` passe seulement `hiveService: getIt<HiveService>()` et `isKycVerified: context.watch<AuthBloc>().state.currentUser?.isKycVerified ?? false` au widget — aucun autre calcul côté parent.
- `hasPublishedTrip` / `hasPublishedParcel` : flags Hive existants (`kHasPublishedAsTraveler`/`kHasPublishedAsSender`), lus en interne par le widget.
- `hasActiveCorridorAlert` : **nouveau flag Hive** `kHasActiveCorridorAlert`, posé par `CorridorAlertFormCubit.submit()` à la première création/édition réussie d'une alerte — jamais réinitialisé, même précédent que `kHasPublishedAsTraveler`/`Sender`. Pas de nouvel appel réseau : le carousel ne dépend d'aucun bloc alertes chargé ailleurs.
- Filtrage des slides au `build()`, à l'intérieur d'un `ValueListenableBuilder<Box>` (réactif aux 3 flags) combiné à `context.select<HelpCenterBloc, HelpCenterConfig>` (réactif au tuto) → `List<_GuidanceSlideData> slides`.

## Gestion des erreurs

- Composant purement présentation : pas d'état d'erreur réseau dédié — les flags Hive sont toujours disponibles de façon synchrone (pas d'état de chargement à gérer, contrairement à un bloc réseau).
- `slides` vide → carousel disparaît complet (`SizedBox.shrink()`) sans logique conditionnelle supplémentaire côté parent.

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

---

## Addendum — Task 6 (post-device feedback)

Après test sur device réel, le design "grande carte pleine couleur + CTA" a été
remplacé par des cartes compactes (taille `ContextualTutorialCard`), toute la
carte cliquable, plus de bouton CTA séparé. Voir
`lib/features/home/presentation/widgets/evergreen_guidance_carousel.dart` pour
l'implémentation actuelle — ce document décrit l'état pré-Task-6, gardé pour
l'historique de conception.
