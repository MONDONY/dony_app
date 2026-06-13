# Phase 2 — Annonces (envois + trajets, additif, piloté par le statut pro)

**Date :** 2026-06-09 | **Statut :** ✅ Design validé (brainstorming) — en attente du plan d'implémentation
**Fondation :** `2026-06-08-navigation-additive-model-foundation.md`

---

## Objectif & gain UX

Faire de l'onglet **Annonces** une surface **additive** : l'expéditeur gère ses envois, le voyageur **ajoute** la gestion de ses trajets — sans switch de rôle. Et surtout : un **voyageur pro** ne doit jamais atterrir sur les Envois (inutiles pour lui), tandis qu'un expéditeur (pur ou occasionnel) reste sur ses envois. La présentation s'adapte au **profil réel** via un signal déterministe.

## État actuel (pour mémoire)

`MatchingManagementScreen` (`lib/features/matching/presentation/screens/matching_management_screen.dart`) dispatche selon `ActiveRoleCubit` :
- expéditeur → `EnvoyerHubScreen` : header « Envoyer » + « + nouvel envoi » (KYC) + segmented **Envois** (`ShipmentListBody`) | **Demandes** (`MyPackageRequestsBody`).
- voyageur → `AnnouncementListScreen` : « Mes trajets » (En cours + onglets À venir / Historique / Annulés) + FAB « créer un trajet ».

Problème : c'est un switch (active_role) qui montre l'un OU l'autre ; et le « voyageur » est traité uniformément, qu'il soit occasionnel ou professionnel.

## Insight clé : le signal déterministe = `isProAccount`

Plutôt qu'une heuristique d'usage fragile, on s'appuie sur un flag réel du `UserModel` : `user.isProAccount` (`lib/features/auth/data/models/user_model.dart:16`). Il distingue le **voyageur professionnel** (transporteur, les envois lui sont quasi inutiles) du **voyageur occasionnel** (qui reste surtout un expéditeur). Trois profils, trois présentations — **toutes déterministes, sans switch, sans heuristique.**

## Design cible — composition par profil

Principe : **un écran primaire + une entrée secondaire vers l'autre activité.** Les deux écrans riches existants (`EnvoyerHubScreen`, `AnnouncementListScreen`) sont **réutilisés tels quels** comme primaire OU comme destination poussée. Aucune card n'est redessinée.

| Profil | Signal | Écran primaire (Annonces) | Entrée secondaire |
|---|---|---|---|
| Pur expéditeur | `!isTraveler` | `EnvoyerHubScreen` (Envois \| Demandes) | **aucune** (identique à aujourd'hui) |
| Voyageur occasionnel | `isTraveler && !isProAccount` | `EnvoyerHubScreen` (défaut = Envois, il reste surtout expéditeur) | **« 🧳 Mes trajets »** → pousse `AnnouncementListScreen` |
| Voyageur pro | `isProAccount` | `AnnouncementListScreen` (« Mes trajets ») | **« 📦 Envoyer un colis »** → pousse `EnvoyerHubScreen` |

- **L'entrée secondaire** est une affordance claire (bouton/section), placée dans le header / haut de l'écran primaire, **gatée par le profil**. Le pur expéditeur n'en voit aucune → écran strictement inchangé.
- **Création :** chaque écran garde son action de création existante — `EnvoyerHubScreen` « + nouvel envoi » (wizard `PackageRequestCreateWizard`, KYC) ; `AnnouncementListScreen` FAB « créer un trajet » (flux existant). Pas de menu « + » unifié (inutile : chaque activité crée depuis son écran ; le pro envoie via l'entrée secondaire → écran Envoyer qui porte son propre « + »).
- **La capacité d'envoyer n'est jamais supprimée** pour le pro : elle est rangée derrière « Envoyer un colis » (+ reste atteignable via la Home, Phase 1). On relègue, on ne retire pas.

## Bottom-nav

- L'onglet Annonces ne dépend plus de `active_role` : **label + icône figés** (neutre, ex. « Annonces 📑 »), identiques pour tous. (`lib/app/main_shell.dart` : retirer la dépendance `ActiveRoleCubit` pour cet onglet.)
- Le **titre interne** de l'écran reste adapté (« Envoyer » / « Mes trajets ») — c'est le contenu, pas la nav.

## Cohérence avec le séquencement (fondation)

- Après Phase 2, **Annonces ne lit plus `active_role`** : il est piloté par `user.isTraveler` / `user.isProAccount`.
- Le **switch du Profil reste** (transitoire) — il n'impacte plus ni la Home (Phase 1) ni Annonces (Phase 2) ; il ne sert plus qu'à Suivi jusqu'à la Phase 3. Suppression finale de `ActiveRoleCubit` en Phase 4.

## Cards & composants

- **Réutilisés tels quels** (zéro régression) : `ShipmentListBody`, `MyPackageRequestsBody`, `AnnouncementListScreen` et ses cards de trajet, `EnvoyerHubScreen` et son segmented, `PackageRequestCreateWizard`, le flux de création de trajet.
- **Nouveau (petit)** : le widget d'**entrée secondaire** (bouton/section « Mes trajets » / « Envoyer un colis »), conforme aux règles design (HIG/M3, `theme.dart`).

## Périmètre

### Dans le scope (Phase 2)
- `MatchingManagementScreen` : composition par profil (primaire + entrée secondaire), fin de la dépendance `ActiveRoleCubit`.
- Affordance d'entrée secondaire dans `EnvoyerHubScreen` (occasionnel) et `AnnouncementListScreen` (pro), gatée par profil.
- Bottom-nav : label+icône Annonces figés.
- Analytics des entrées secondaires + maj `CLAUDE.md`.
- Tests (composition par profil) + couverture ≥ 90 %.

### Hors scope
- Redesign des cards / des écrans Envois/Demandes/Trajets (réutilisés tels quels).
- Fusion du contenu Envois et Trajets dans un même flux.
- « Colis sur mes trajets » et négociations : restent accessibles comme aujourd'hui (depuis l'écran trajets / le profil) ; pas de relocalisation en Phase 2.
- Menu « + » de création unifié (écarté : chaque écran crée depuis son action existante).

## Inventaire zéro-régression (Annonces)

- **Pur expéditeur :** `EnvoyerHubScreen` (Envois | Demandes, « + nouvel envoi » KYC) → **strictement inchangé**.
- **Voyageur (occasionnel & pro) :** accès conservé à **toute** la gestion de trajets (`AnnouncementListScreen` : En cours, À venir/Historique/Annulés, créer un trajet) **et** à toute la gestion d'envois (Envois | Demandes, créer un envoi). Seul le point d'entrée change (primaire vs secondaire selon le profil) — rien n'est retiré.
- **Création trajet & création envoi :** flux existants préservés.

## Fichiers touchés (prévisionnel)

| Fichier | Changement |
|---|---|
| `lib/features/matching/presentation/screens/matching_management_screen.dart` | Composition par profil (`isTraveler`/`isProAccount` via `AuthBloc`) au lieu du dispatch `ActiveRoleCubit` ; choisit l'écran primaire + fournit l'entrée secondaire |
| `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart` | Affordance optionnelle « Mes trajets » (gatée), additive dans le header ; aucun changement pour le pur expéditeur |
| `lib/features/matching/presentation/screens/announcement_list_screen.dart` | Affordance optionnelle « Envoyer un colis » (gatée pro), additive dans le header |
| `lib/app/main_shell.dart` | Onglet Annonces : label+icône figés, fin de la dépendance `ActiveRoleCubit` |
| `lib/core/services/analytics_events.dart` | Events des entrées secondaires |
| `CLAUDE.md` | Maj table des events |

*(Affiné dans le plan d'implémentation.)*

## Analytics

- Events pour l'ouverture des activités secondaires (ex. `annonces_trips_opened`, `annonces_send_opened`), déclarés dans `AnalyticsEvents`, tirés au tap (action de navigation secondaire), `unawaited`, sans PII.
- `logScreen` existants des sections Envois/Demandes (`envoyerEnvoisScreen`, `envoyerDemandesScreen`) **préservés**.

## Tests

- `MatchingManagementScreen` : rend le bon primaire + la bonne entrée secondaire selon `{!isTraveler}`, `{isTraveler && !isPro}`, `{isPro}` (widget tests avec `AuthBloc` mocké).
- Pur expéditeur : aucune affordance voyageur, écran identique.
- Pro : écran Trajets primaire + entrée « Envoyer un colis » présente et fonctionnelle.
- Occasionnel : écran Envois primaire (défaut) + entrée « Mes trajets ».
- Non-régression : suites existantes Envoyer/Trajets passent.
- Couverture ≥ 90 %.

## Cas limites

- **Voyageur pro qui envoie ponctuellement :** « Envoyer un colis » → `EnvoyerHubScreen` (Envois | Demandes, « + nouvel envoi »). Capacité intacte.
- **Perte du rôle voyageur** (`isTraveler` → false) : Annonces redevient `EnvoyerHubScreen` pur, aucune entrée trajets. (Plus de dépendance `syncWithRoles` pour Annonces.)
- **Perte du statut pro** (`isProAccount` → false, reste voyageur) : repasse en présentation « occasionnel » (Envois primaire + entrée Mes trajets). Déterministe.
- **Bascule pro pendant la session :** `AuthBloc` (`AuthProfileUpdated`) → la composition se recalcule.

## Décisions ouvertes (mineures)
- Placement exact de l'entrée secondaire (header trailing vs bandeau sous le header).
- Wording du label d'onglet figé (« Annonces » vs autre).
- Noms précis des events analytics.
