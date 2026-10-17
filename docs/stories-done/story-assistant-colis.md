# Assistant IA : les colis de l'utilisateur (Flutter)
**Date:** 2026-10-17 | **Status:** ✅ Complète

## Résumé
L'écran de l'assistant affiche les colis proposés par le back quand une question porte sur l'un d'eux, repose la question pour le colis touché, et garde ce colis comme contexte de la conversation. Back : yadony-back #559.

## Fichiers créés / modifiés
- `data/assistant_models.dart` : `AssistantParcelChoice` ; `AssistantAnswer.parcelId` et `parcels` (absents d'un back antérieur, colis incomplet écarté).
- `data/assistant_repository.dart` : `parcelId` envoyé seulement s'il existe.
- `bloc/` : `AssistantState.parcelId`, `AssistantMessage.parcels`, événement `AssistantParcelChosen`.
- `presentation/widgets/assistant_message_bubble.dart` : `AssistantParcelButton`, `assistantParcelStatusLabel`.
- `presentation/screens/assistant_screen.dart` : boutons sur la dernière réponse seulement, cinquième suggestion « Où est mon colis ? ».
- ARB FR/EN, `AnalyticsEvents` (`assistant_parcel_choices_shown`, `assistant_parcel_chosen`), table du `CLAUDE.md`.

## Comment ça fonctionne
### Flux utilisateur
1. « Où est mon colis ? » : le back répond « aucun colis en cours », ou propose ses colis (`parcels`).
2. Toucher un colis : son libellé devient un message de l'utilisateur, la question d'avant est reposée avec `parcelId`.
3. La réponse renvoie `parcelId` : il part avec les questions suivantes. Une réponse sans `parcelId` met fin au suivi ; « Nouvelle conversation » et la fin de session l'oublient.
### BLoC
`_ask` garde le `parcelId` dès l'envoi : « Réessayer » le renvoie après une panne. `_onParcelChosen` ignore un colis qu'aucune réponse ne propose.
### Écran
Bouton : numéro (ou trajet, ou « Colis »), puis trajet, étape (libellés des filtres d'envois) et rôle. Cible ≥ 44 pt. Masqués sur les réponses plus anciennes et pendant un envoi.
### Appels API
`POST /assistant/ask` avec `parcelId` facultatif. Un back antérieur ignore le champ et ne renvoie ni `parcels` ni `parcelId` : rien ne change pour l'utilisateur.
### Pièges
- Le back revérifie l'accès à chaque question : l'app ne décide jamais qu'un colis est accessible.
- La liste de la conversation est paresseuse : un test qui saute à `maxScrollExtent` doit sauter de nouveau une fois l'étendue corrigée.

## Critères d'acceptation couverts
- Colis proposés directement, choix en un toucher, réponses selon l'état du colis, aucun code affiché par l'assistant (le back n'en donne jamais).

## Décisions techniques
- Le libellé du bouton (pas un identifiant) sert de message utilisateur : lisible dans l'historique et dans le ticket d'escalade.
- Boutons seulement sur la dernière réponse : pas de choix périmé plus haut dans la conversation.
