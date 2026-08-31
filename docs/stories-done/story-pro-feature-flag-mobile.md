# Story — Feature flag de l'offre PRO (Flutter)
**Date:** 2026-08-31 | **Status:** ✅ Complète

## Résumé
Tant que le backend ne confirme pas `pro_enabled=true` (réglage plateforme piloté depuis le back-office), l'application masque toute entrée PRO. Même mécanique que le flag SMS : chargé une fois au démarrage, repli sûr sur « masqué ».

## Fichiers créés / modifiés
- `lib/core/config/pro_flag.dart` — `proEnabledListenable`, `setProEnabled`, `kProEnabledDefault = false`.
- `lib/features/config/data/config_datasource.dart`, `config_repository.dart` — `getProEnabled()` sur `GET /config/pro-enabled`.
- `lib/main.dart` — `_loadProEnabled()` au boot, non bloquant.
- `lib/features/profile/presentation/widgets/profile_sections.dart` — la tuile « Passer en compte PRO / Mon profil PRO » n'est construite que si le flag est vrai (`ValueListenableBuilder`).
- `lib/features/billing/presentation/widgets/subscription_banner_host.dart` — même porte : flag faux ⇒ ni BLoC, ni appel réseau, ni bandeau.
- `lib/features/billing/presentation/pro_limit_dialog.dart` — **nouveau** `showProLimitReachedDialog` partagé par les quatre sites « limite atteinte » (création trajet ×2, détail trajet, wizard colis). Flag faux ⇒ un seul bouton « Compris », jamais d'invitation « Passer en PRO ».
- `lib/core/design/widgets/dony_dialog.dart` — `cancelLabel` nullable : `null` retire le bouton secondaire.
- `lib/app/router.dart` — `resolveProRouteRedirect` : `/profile/upgrade-to-pro` renvoie vers `/profile` quand l'offre est fermée (liens profonds, anciennes notifications).

## Comment ça fonctionne
### Flux utilisateur
1. Boot → `GET /config/pro-enabled` → `setProEnabled(value)` ; en cas d'erreur le flag reste `false`.
2. Profil : la section « Mes avantages » se reconstruit sur le flag ; sans PRO, elle commence à « Parrainages ».
3. Limite atteinte (le serveur ne renvoie plus `pro-limit-reached` quand l'offre est fermée, seulement `draft-limit-reached` au plafond PRO) : dialogue informatif, pas de navigation.
4. Effet au **prochain démarrage** de l'application après un changement côté admin (pas de polling), comme pour le flag SMS.

### Appels API
- `GET /config/pro-enabled` → `{"enabled": bool}`, public.

### Pièges et points d'attention
- Les tests qui cherchent « Passer en compte PRO », « Mon profil PRO » ou « Passer en PRO » doivent poser `setProEnabled(true)` dans leur `setUp` (fait dans `profile_screen_test`, `subscription_banner_host_test`, `package_request_create_screen_success_test`) et remettre `kProEnabledDefault` en `tearDown`.
- Dans une `SliverList`, une tuile hors écran n'est pas construite : un `findsNothing` ne prouve rien sans avoir d'abord défilé jusqu'à un voisin (« Parrainages »).
- `showProLimitReachedDialog` rend un `bool` et ne navigue pas : l'appelant garde le `context.push`, ce qui laisse le dialogue testable sans GoRouter.

## Critères d'acceptation couverts
- [x] Flag faux par défaut, chargé au boot — `test/core/config/pro_flag_test.dart`, `config_repository_test.dart`.
- [x] Tuile PRO masquée (compte standard et compte PRO) — `profile_screen_test.dart`.
- [x] Bandeau d'abonnement muet — `subscription_banner_host_test.dart`.
- [x] Dialogues « limite atteinte » sans CTA PRO — `pro_limit_dialog_test.dart`, `dony_dialog_test.dart`.
- [x] Route de vente redirigée — `test/app/router_pro_redirect_test.dart`.

## Décisions techniques
- `ValueNotifier` global plutôt qu'un BLoC : c'est le pattern déjà en place pour `sms_auth_flag` ; un flag lu à froid au boot n'a pas d'état à faire transiter.
- Un helper de dialogue plutôt que quatre `if` : la règle « pas de CTA si l'offre est fermée » vit à un seul endroit.
- Aucun nouvel événement analytics : aucune action utilisateur n'est ajoutée, seules des entrées disparaissent ; les événements PRO existants ne se déclenchent simplement plus.
