# Blocage d'un utilisateur — points d'entrée et rafraîchissement (Flutter)

**Date:** 2026-09-01 | **Status:** ✅ Complète

## Résumé

L'écran « Utilisateurs bloqués » et le dialog de blocage existaient déjà, mais le blocage n'était accessible que depuis trois écrans, ne rafraîchissait rien une fois confirmé, et le compteur de la page Confidentialité affichait toujours zéro. Cette passe ajoute les points d'entrée manquants, fait réagir l'application au blocage, et branche le compteur sur la vraie liste.

## Fichiers créés

- `lib/core/services/block_events_service.dart` — diffusion des blocages et déblocages à travers l'application
- `test/features/matching/presentation/screens/traveler_profile_screen_block_test.dart`

## Fichiers modifiés

- `lib/features/settings/bloc/blocked_users_bloc.dart` (+ event, + state) — le blocage devient une action du BLoC ; jusque-là le dialog appelait le repository directement depuis le widget
- `lib/features/matching/presentation/widgets/block_user_action.dart` — le dialog passe par le BLoC, dont il fournit lui-même l'instance ; branche d'erreur 409 supprimée (le serveur ne refuse plus de bloquer pendant une transaction)
- `lib/features/matching/presentation/screens/traveler_profile_screen.dart`, `lib/features/profile/presentation/screens/profile_public_screen.dart`, `lib/features/package_request/presentation/widgets/sender_public_profile_sheet.dart` — point d'entrée « Bloquer » ajouté
- `lib/features/messaging/presentation/chat_screen.dart` — sortie du fil quand l'interlocuteur est bloqué
- `lib/features/messaging/bloc/conversation_list/conversation_list_bloc.dart` — rechargement de la liste
- `lib/features/home/presentation/home_screen.dart` — relance de la recherche
- `lib/features/settings/presentation/screens/privacy_settings_screen.dart` — compteur réel
- `lib/core/di/injection.dart`, `lib/core/services/analytics_events.dart`

## Comment ça fonctionne

### Flux utilisateur

1. Depuis une fiche profil, un profil public ou une conversation, l'utilisateur ouvre le menu ⋯ et choisit « Bloquer ».
2. Le dialog de confirmation rappelle ce que le blocage implique et reste ouvert en cas d'erreur serveur, pour laisser réessayer.
3. À la confirmation, `BlockedUsersBloc` appelle `POST /users/me/blocks`, émet `user_blocked` vers l'analytics, puis diffuse l'événement.
4. Les écrans abonnés réagissent : la conversation se ferme, la liste des conversations et la recherche se rechargent, le compteur de la page Confidentialité se met à jour.

### Pourquoi un service d'événements

Chaque route construit son propre BLoC (`registerFactory`), donc l'écran qui déclenche le blocage n'a aucun moyen de prévenir les autres. `BlockEventsService` est ce moyen : un `StreamController` broadcast, enregistré en singleton. Il est volontairement sans état — il ne mémorise pas qui est bloqué, la liste reste au serveur, il ne transporte qu'un signal.

Le déblocage est diffusé aussi : dans les deux sens, ce qui est affiché est périmé.

### Où l'abonnement est posé

Dans le BLoC quand la réaction est un rechargement de données (`ConversationListBloc`), dans le widget quand la réaction est une navigation (`ChatScreen`) ou qu'elle dépend d'un état porté par le widget (les filtres courants de `HomeScreen`).

### Pièges et points d'attention

- Le dialog résout son propre `BlockedUsersBloc` via `getIt` : tout test qui ouvre le menu de blocage doit enregistrer une fabrique, sinon la résolution lève.
- La sortie du chat ne se déclenche que sur un blocage concernant l'interlocuteur du fil ouvert, jamais sur un déblocage.
- L'action de blocage est masquée sur son propre profil, et dégrade en silence si `AuthBloc` est absent de l'arbre (l'écran est monté sans lui dans certains tests et via le deep link d'affiche partagée).

## Analytics

| Event | Déclencheur |
|---|---|
| `user_blocked` | `BlockedUsersBloc._onBlock` — blocage confirmé par le serveur |
| `user_unblocked` | `BlockedUsersBloc._onUnblock` — déblocage confirmé |

Aucune propriété : l'identité de la personne bloquée est une donnée sensible.

## Tests

- `flutter analyze` → 0 issue
- `flutter test` → 7147 tests passés, 0 échec
- Tests ajoutés : blocage dans `blocked_users_bloc_test` (succès, échec, diffusion), widget tests du dialog dans `block_user_action_test` (qui ne testait auparavant que le mock lui-même), points d'entrée sur les trois écrans, réactions au blocage dans `conversation_list_bloc_test`, `chat_screen_test`, `home_screen_test`, compteur dans `privacy_settings_screen_test`
