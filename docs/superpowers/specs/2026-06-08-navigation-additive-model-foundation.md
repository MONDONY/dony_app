# Fondation — Modèle additif de navigation (fin du switch de rôle)

**Date :** 2026-06-08 | **Statut :** ✅ Modèle validé (brainstorming) — fondation des 4 specs de phase

> Ce document remplace l'ancienne approche « refonte du switch de rôle ». Le switch est **supprimé**, pas redessiné.

---

## Le pivot

L'ancienne idée (redessiner le switch voyageur/expéditeur en « intention ») est abandonnée. Nouvelle règle, **la plus importante de la refonte** :

> **On ne switche plus de rôle.** Tout le monde est **expéditeur** au départ. Devenir **voyageur** n'est pas un mode dans lequel on entre — c'est un **déblocage de capacités** qui **s'ajoutent par-dessus** l'expérience expéditeur, surface par surface.

Conséquence directe : plus aucun contrôle « quel mode suis-je ? ». L'utilisateur ne réfléchit jamais à son rôle ; il agit.

## North star (critères de succès non négociables)

1. **ZÉRO régression.** Tout ce qui fonctionne aujourd'hui — côté expéditeur **et** côté voyageur — doit continuer de fonctionner après chaque phase. Chaque spec de phase contient un **inventaire « ce qui doit encore marcher »**.
2. **UX améliorée.** Moins d'effort de réflexion pendant la navigation.

## Le modèle additif

- **Base (tout utilisateur) = expéditeur.** L'app entière est utilisable par un expéditeur sans qu'aucun concept « voyageur » ne soit visible.
- **Capacité voyageur = additive.** Quand `user.isTraveler == true`, des éléments **s'ajoutent** sur les surfaces existantes (pins, sections, onglets, filtres, actions). On n'enlève jamais le socle expéditeur.
- **Gating par capacité, pas par mode.** Le rendu dépend de `user.isTraveler` (déjà fourni par le backend dans `user.roles`), plus d'un état `active_role` que l'utilisateur bascule.
- **Pur expéditeur :** ne voit **aucun** élément voyageur, nulle part.

### Conséquence technique majeure : suppression de `ActiveRoleCubit`

Aujourd'hui un état global `active_role` (Hive + `ActiveRoleCubit`) pilote : le contenu de la carte Home, les libellés/icônes d'onglets, le dispatch de `MatchingManagementScreen`, le sous-onglet Activité du profil, et **deux** pills de switch (Home + Profil).

Dans le modèle cible, **rien n'a besoin de `active_role`** : chaque surface rend le socle expéditeur **+** (si `isTraveler`) le supplément voyageur. `ActiveRoleCubit` / `active_role` sont donc **supprimés** — mais progressivement (voir séquencement).

## Séquencement des phases (clé du zéro-régression)

Le risque : si on retire le switch trop tôt alors que des onglets dépendent encore de `active_role`, un voyageur perdrait l'accès à ses fonctions voyageur (régression en cours de route). Stratégie pour l'éviter :

| Phase | Surface | Migration | Switch |
|---|---|---|---|
| **1** | Home | Carte additive (isTraveler + filtre de focus local). Home ne lit plus `active_role`. | **Retrait du switch Home.** Le switch **Profil reste** (contrôle transitoire de `active_role` pour les onglets non encore migrés). |
| **2** | Annonces | Additive : « Mes envois » (socle) + « Mes trajets » (si voyageur). Ne lit plus `active_role`. | Switch Profil toujours présent (transitoire, n'impacte plus qu'Annonces résiduel/Suivi/Profil). |
| **3** | Suivi | Additive : recherche colis (socle) + scan QR trajets (si voyageur). Ne lit plus `active_role`. | Switch Profil toujours présent (transitoire). |
| **4** | Profil | Additive : socle + sections voyageur (si voyageur). | **Retrait du switch Profil + suppression de `ActiveRoleCubit`/`active_role`** (plus rien ne l'utilise). |

À chaque étape, l'app reste fonctionnelle pour expéditeur **et** voyageur. Le switch Profil sert de filet transitoire jusqu'à la dernière phase.

## Inventaire zéro-régression (global, par surface)

Tout ce qui suit doit rester atteignable après refonte (relocalisé, jamais supprimé). Chaque spec de phase reprend et précise sa part.

**Home (Phase 1)** — voyageur : pins colis (📦), filtres colis (date range, poids max, taille), carrousel near-me colis, action « faire une offre » sur un colis. Expéditeur : pins trajets, filtres trajets (date, note, poids, €/kg, KiloPro, corridors), carrousel near-me voyageurs, action « faire une offre/bid » sur un trajet.

**Annonces (Phase 2)** — voyageur : `AnnouncementListScreen` (Mes trajets : En cours / À venir / Historique / Annulés ; FAB créer trajet), colis sur mes trajets, négociations. Expéditeur : `EnvoyerHubScreen` (dashboard Demandes / Envois / Négos ; créer un envoi, KYC).

**Suivi (Phase 3)** — voyageur : `ScanHubScreen` (trip hero, étapes DÉPART/TRANSIT/ARRIVÉE, scan QR, identifier par numéro). Expéditeur : `TrackingSearchScreen` (recherche DON-XXXXXX, timeline). Offline queue QR conservée.

**Profil (Phase 4)** — voyageur : sous-onglet Activité (stats trajets, Mes trajets, Colis sur mes trajets, négos, Modèles de trajet, Mes adresses), Compte (Revenus & paiements, grille de prix, Compte PRO, parrainages). Expéditeur : Activité (envois), Carnet (destinataires, abonnements), « Devenir voyageur ». Commun : KYC, portefeuille, réglages, support, déconnexion, litiges.

**Messages** — hors scope, déjà role-agnostic. Aucun changement.

## Principes transverses (toutes phases)

- **Analytics (règles PostHog du projet) :** toute nouvelle action/écran tracké, event déclaré dans `AnalyticsEvents`, tiré dans le BLoC, `unawaited()`, aucune PII. Maj de la table d'events dans `CLAUDE.md`. Les events existants ne doivent pas régresser.
- **Tests :** BLoC + widget, couverture ≥ 90 %. Chaque phase ajoute ses tests, ne casse pas les existants.
- **Design :** HIG + Material 3, palette `lib/app/theme.dart`, `flutter_bloc` (no setState), GoRouter (no Navigator.push).
- **Capacité voyageur :** toujours gatée par `user.isTraveler` ; jamais d'élément voyageur pour un pur expéditeur.

## Carte des livrables

- `2026-06-08-navigation-additive-model-foundation.md` — ce document.
- `2026-06-08-phase-1-home-design.md` — spec Phase 1 (Home). **(rédigée)** + plan `docs/superpowers/plans/2026-06-08-phase-1-home.md`.
- `2026-06-09-phase-2-annonces-design.md` — spec Phase 2 (Annonces). **(rédigée)** + plan `docs/superpowers/plans/2026-06-09-phase-2-annonces.md`. Piloté par `isProAccount`.
- `2026-06-09-phase-3-suivi-design.md` — spec Phase 3 (Suivi). **(rédigée)** + plan `docs/superpowers/plans/2026-06-09-phase-3-suivi.md`. Additif + **ScanHub réel**.
- `2026-06-09-phase-4-profil-design.md` — spec Phase 4 (Profil). **(rédigée)** Additif par capacité + **suppression de `ActiveRoleCubit`** (fin de la migration).

Chaque phase : discussion → spec → plan d'implémentation → phase suivante.
