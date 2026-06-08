# Phase 4 — Profil (additif par capacité + fin de ActiveRoleCubit)

**Date :** 2026-06-09 | **Statut :** ✅ Design validé (brainstorming) — en attente du plan d'implémentation
**Fondation :** `2026-06-08-navigation-additive-model-foundation.md`

---

## Objectif & gain UX

Rendre le Profil **additif par capacité** : une base commune à tous + des sections **ajoutées** selon `user.isTraveler` / `user.isProAccount`. Plus aucun switch. Et **clôturer la migration** : suppression du switch pill du profil **et** de `ActiveRoleCubit` (dernier consommateur de `active_role`).

Le profil est un **hub** (pas une surface de travail) → contrairement à Annonces/Suivi, **pas de logique primaire/secondaire** : juste de l'additif.

## État actuel (pour mémoire)

- `profile_screen.dart` enveloppe tout le profil dans `BlocBuilder<ActiveRoleCubit, ActiveRole>` (l.105) et propage `activeRole` aux sous-onglets.
- **Switch pill** : `profile_header.dart` → `_RolePill` (l.285+), branché via `onRoleSwitch` → `switchToTraveler()`/`switchToSender()` (profile_screen l.241-248). Visible si double rôle.
- **Sections Activité & Compte gatées en XOR par `activeRole`** (l.454, 470, 717, 1293…) : soit voyageur, soit expéditeur.
- `become_traveler_screen.dart:51` appelle `switchToSender()`.
- `ActiveRoleCubit` est aussi câblé dans `app.dart` (`syncWithRoles` au login) et la DI (`injection.dart`).

## Insight clé : XOR → additif par capacité

Aujourd'hui le profil montre **soit** les sections voyageur **soit** les sections expéditeur (selon `active_role`). Demain : la **base commune** (toujours) **+** les sections voyageur **ajoutées** si `isTraveler`. Un voyageur voit donc base + voyageur ; un pur expéditeur ne voit aucune section voyageur. Gating par **capacité** (`user.isTraveler`, `user.isProAccount`), plus par `active_role`.

## Design cible — commun vs ajouté

### Sous-onglet ACTIVITÉ
| Commun (tous) | + Voyageur (`isTraveler`) |
|---|---|
| Mes envois en cours · Mon carnet (destinataires, abonnements) · Mes négociations · Mes litiges · carte de stats | Mes trajets · Colis sur mes trajets · Mes modèles de trajet · Mes adresses |

- **Stats** : carte adaptative — pour un voyageur, montrer les métriques voyageur en priorité (livraison %, revenus) ; sinon métriques expéditeur (économisés). Ordre des sections : sections voyageur en tête pour un voyageur.

### Sous-onglet COMPTE
| Commun (tous) | + Voyageur | + Pro / autre |
|---|---|---|
| Contact & sécurité · Identité & confiance (KYC, profil public, avis) · Portefeuille · **Fidélité (parrainage + code parrain)** · Moyens de paiement & factures | Revenus & paiements (Stripe) · Grille de prix · Commission cash | **Compte PRO** (si voyageur, état via `isProAccount`) · **« Devenir voyageur »** (uniquement si **pas** voyageur) |

### Sous-onglet RÉGLAGES
- **100 % commun** : préférences (paramètres, notifications, langue) · sécurité & confidentialité · support (contact, FAQ) · déconnexion · footer version. Inchangé.

### Décisions de design retenues
1. **Retrait du switch pill** (header) + **suppression de `ActiveRoleCubit`** et de tout son câblage (DI, `app.dart` `syncWithRoles`, provider, `switchToSender()` dans become-traveler).
2. **Parrainage → une seule section « Fidélité »** pour tous (parrainage + « J'ai un code parrain »), **dé-dupliquée**. Fin du rangement différent voyageur/expéditeur.
3. **Paiements** : « Moyens de paiement & factures » + « Portefeuille » = **commun** ; « Revenus & paiements » (encaisser via Stripe) = **ajout voyageur**. *(Tout le monde paie ; seul le voyageur encaisse.)*
4. **Doublon Activité ↔ Annonces : conservé** (Option 1) — le profil reste un hub d'accès secondaire vers les mêmes écrans (découvrable).

## Cards & composants
- **Réutilisés tels quels** : toutes les tuiles/sections existantes du profil, `ProfileHeader` (moins le `_RolePill`), les écrans liés (KYC, portefeuille, parrainage, become-traveler, upgrade-pro, adresses, modèles…).
- **Retirés** : `_RolePill` (et son usage), `ActiveRoleCubit`.
- Aucune card redessinée.

## Cohérence avec le séquencement (fondation)
- Phase 4 = **dernière**. Après elle, **plus aucune lecture de `active_role`** dans l'app (Home, Annonces, Suivi déjà migrés en Phases 1-3) → `ActiveRoleCubit` et la clé Hive `active_role` sont **supprimés**.
- Vérifier qu'aucun consommateur résiduel ne subsiste avant suppression (grep `ActiveRoleCubit`/`active_role`).

## Périmètre

### Dans le scope (Phase 4)
- Profil additif par capacité : sections Activité & Compte gatées par `isTraveler`/`isProAccount` (fin du XOR `active_role`).
- Retrait du switch pill + suppression de `ActiveRoleCubit` et de tout son câblage.
- Parité : section « Fidélité » unique (parrainage), dé-duplication « J'ai un code parrain », paiements alignés (commun + revenus voyageur).
- Stats adaptatives (ordre/métriques selon capacité).
- Tests + couverture ≥ 90 %.

### Hors scope
- Complétion des features paiement « bientôt disponible » (moyens/factures/crédits) — juste rangées au même endroit pour tous.
- Allègement du doublon Activité↔Annonces (Option 2 écartée).
- Redesign des écrans/tuiles existants.

## Inventaire zéro-régression (Profil)

- **Pur expéditeur** : header, Activité (envois, carnet, litiges, stats), Compte (contact, KYC, portefeuille, parrainage, paiements, **Devenir voyageur**), Réglages → **conservés** ; le switch pill (qui n'apparaissait de toute façon pas pour lui) disparaît.
- **Voyageur** : accès conservé à **toutes** ses sections (trajets, colis sur trajets, modèles, adresses, revenus/paiements Stripe, grille de prix, Compte PRO, parrainage) **et** aux sections communes — désormais **toujours visibles** (plus besoin de basculer en mode voyageur).
- **Aucune fonctionnalité retirée** : seul le switch (et le mode) disparaît ; tout devient additif/permanent.
- `become_traveler` : après upgrade, le rôle est ajouté via `AuthBloc` (`AuthUserSynced`) ; le `switchToSender()` retiré n'a plus d'objet.

## Fichiers touchés (prévisionnel)

| Fichier | Changement |
|---|---|
| `lib/features/profile/presentation/profile_screen.dart` | Retrait du `BlocBuilder<ActiveRoleCubit>` ; lecture `user.isTraveler`/`isProAccount` via `AuthBloc` ; sections XOR → additives ; retrait du câblage `_RolePill` ; parité parrainage/paiements ; stats adaptatives |
| `lib/features/profile/presentation/widgets/profile_header.dart` | Suppression de `_RolePill` et des params `activeRole`/`onRoleSwitch` |
| `lib/features/profile/presentation/screens/become_traveler_screen.dart` | Retrait de l'appel `switchToSender()` |
| `lib/features/auth/bloc/active_role_cubit.dart` | **Supprimé** |
| `lib/core/di/injection.dart` | Retrait de l'enregistrement `ActiveRoleCubit` |
| `lib/app/app.dart` | Retrait du provider `ActiveRoleCubit` + des appels `syncWithRoles` |
| `lib/app/main_shell.dart` | Retrait de la `BlocBuilder<ActiveRoleCubit>` résiduelle (si plus utilisée après Phases 1-3) ; lire les capacités via `AuthBloc` |
| `lib/core/services/analytics_events.dart` + `CLAUDE.md` | Events éventuels (ouverture sections) + maj table |

*(Affiné dans le plan d'implémentation.)*

## Analytics
- Events existants du profil (`becomeTravelerStarted`, `upgradeToProStarted`, `referralShared`, `accountDeletionRequested`, `analyticsConsentChanged`) **préservés**.
- Pas de nouvel event structurel requis (hub). Optionnel : event d'ouverture d'une section voyageur ajoutée — à décider au plan.

## Tests
- Profil widget : pur expéditeur → aucune section voyageur, aucun switch ; voyageur → base + sections voyageur ; pro → Compte PRO visible ; non-voyageur → « Devenir voyageur » visible.
- Parité : une seule section parrainage, pas de doublon « code parrain ».
- Non-régression : suites profil existantes passent ; aucun import cassé après suppression de `ActiveRoleCubit` (grep de vérification).
- Couverture ≥ 90 %.

## Cas limites
- **Double rôle (sender+traveler) :** voit base + sections voyageur (plus de bascule nécessaire).
- **Devient voyageur en session :** `AuthProfileUpdated` → le profil recompose et fait apparaître les sections voyageur ; « Devenir voyageur » disparaît.
- **Devient pro :** « Compte PRO » passe à « Mon profil PRO » (via `isProAccount`).
- **Perte du rôle voyageur :** sections voyageur disparaissent ; « Devenir voyageur » réapparaît. (Plus de `syncWithRoles` nécessaire — tout dérive de `user`.)

## Décisions ouvertes (mineures)
- Métriques exactes de la carte de stats adaptative.
- Emplacement final de la section « Fidélité » (Compte vs section dédiée).
- Faut-il un event analytics à l'ouverture d'une section voyageur ajoutée.
