# Phase 4 — Profil (additif par capacité + fin de ActiveRoleCubit) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre le Profil additif par capacité (base commune + sections voyageur ajoutées via `user.isTraveler`/`isProAccount`), retirer le switch pill, harmoniser la parité, et **supprimer `ActiveRoleCubit`** ainsi que tout son câblage — clôturant la migration.

**Architecture :** Le profil ne lit plus `active_role` : il dérive tout de `user` (déjà disponible via `AuthBloc`, flags `isTraveler`/`isSender`/`isProAccount` calculés l.100-102). Les sections passent de **XOR** (`if traveler … else sender`) à **additif** (sender = base toujours + traveler ajouté). La suppression du type `ActiveRole`/`ActiveRoleCubit` sert de **filet de vérification** : la compilation échoue sur tout usage oublié.

**Tech Stack :** Flutter, flutter_bloc, GoRouter, GetIt, flutter_test, bloc_test, mocktail.

**Réf spec :** `docs/superpowers/specs/2026-06-09-phase-4-profil-design.md` · **Fondation :** `2026-06-08-navigation-additive-model-foundation.md`

> ⛔ **SÉQUENCEMENT OBLIGATOIRE :** ce plan **supprime `ActiveRoleCubit`**, encore utilisé par Home/Annonces/Suivi tant qu'elles ne sont pas migrées. Il doit être implémenté **APRÈS les Phases 1, 2 et 3**. La Task 6 (suppression) ne peut compiler que si plus aucune autre surface ne lit `active_role`.

**Stratégie de test (réaliste) :** pas de logique pure significative ici (gating UI). On s'appuie sur : (1) des widget tests ciblés du profil (présence/absence de sections selon le profil, absence du switch), (2) le **compilateur** après suppression du type (zéro usage résiduel), (3) la checklist QA. Honnête : la majeure partie est un refactor structurel validé par compilation + QA.

**Garantie zéro-régression :** aucune fonctionnalité retirée — seul le *mode* disparaît. Pur expéditeur : profil identique (le switch ne lui apparaissait pas). Voyageur : toutes ses sections deviennent **permanentes** (plus besoin de basculer).

---

## File Structure

| Fichier | Changement |
|---|---|
| `lib/features/profile/presentation/widgets/profile_header.dart` | Suppression `_RolePill` + params `activeRole`/`onRoleSwitch`. |
| `lib/features/profile/presentation/profile_screen.dart` | Retrait `BlocBuilder<ActiveRoleCubit>` ; sections XOR → additif ; parité ; stats adaptatives. |
| `lib/features/profile/presentation/screens/become_traveler_screen.dart` | Retrait `switchToSender()` (l.51). |
| `lib/app/app.dart` | Retrait provider `ActiveRoleCubit` (l.136-137), `syncWithRoles` (l.170, 181), import (l.8). |
| `lib/core/di/injection.dart` | Retrait registration (l.152-153) + import (l.69). |
| `lib/app/main_shell.dart` | Retrait de toute `BlocBuilder<ActiveRoleCubit>` résiduelle. |
| `lib/features/auth/bloc/active_role_cubit.dart` | **Supprimé.** |
| `lib/core/widgets/role_mode_pill.dart` | **Supprimé** (inutilisé depuis Phase 1). |
| `test/features/profile/presentation/profile_screen_test.dart` | **Créé/мaj.** Widget tests profils. |

---

### Task 1 : `ProfileHeader` — retirer le switch pill

**Files:** Modify `lib/features/profile/presentation/widgets/profile_header.dart`

- [ ] **Step 1 : Repérer les usages**

Run: `grep -n "activeRole\|onRoleSwitch\|_RolePill\|ActiveRole" lib/features/profile/presentation/widgets/profile_header.dart`
Attendu : champ `activeRole` (~l.9/23), `onRoleSwitch` (~l.33), rendu `_RolePill(...)` (~l.131), classe `_RolePill` (~l.285-315), import `active_role_cubit.dart`.

- [ ] **Step 2 : Supprimer le pill et ses params**

- Retirer le rendu `_RolePill(activeRole: activeRole, onRoleSwitch: onRoleSwitch)` (~l.131) et l'espacement éventuel autour.
- Supprimer la classe `_RolePill` (et ses sous-widgets `_RolePillTab` si présents).
- Retirer les champs `final ActiveRole activeRole;` et `final ValueChanged<ActiveRole>? onRoleSwitch;` du constructeur de `ProfileHeader`.
- Retirer l'import `package:dony/features/auth/bloc/active_role_cubit.dart`.

- [ ] **Step 3 : Vérifier (échec attendu chez l'appelant)**

Run: `flutter analyze lib/features/profile/presentation/widgets/profile_header.dart`
Attendu : OK pour ce fichier. `profile_screen.dart` ne compilera plus (il passe encore `activeRole`/`onRoleSwitch`) → corrigé Task 2.

- [ ] **Step 4 : Commit**

```bash
git add lib/features/profile/presentation/widgets/profile_header.dart
git commit -m "feat(profil): retrait du switch pill du header"
```

---

### Task 2 : `profile_screen.dart` — retirer le wrap ActiveRoleCubit + délier les tabs

**Files:** Modify `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Step 1 : Retirer le `BlocBuilder<ActiveRoleCubit>`**

Supprimer le wrap (l.105-106) et sa fermeture correspondante (la `}` + `);` du builder, vers l.334). Le contenu interne (les `BlocBuilder<BidBloc>` / `BlocBuilder<AnnouncementBloc>`) est conservé, simplement dé-indenté. Retirer la variable `activeRole`. Les flags `isTraveler`, `isSender`, `isProAccount` (déjà calculés l.100-102 depuis `user`) restent la source de vérité.

- [ ] **Step 2 : Nettoyer l'appel `ProfileHeader`**

Dans le `ProfileHeader(...)` (l.225-253), retirer `activeRole: activeRole,` (l.227) et tout le bloc `onRoleSwitch: (isTraveler && isSender) ? (role) { … } : null,` (l.239-252).

- [ ] **Step 3 : Délier `_ActivityTab` et `_AccountTab`**

- `_ActivityTab(...)` (l.311) : retirer `activeRole: activeRole,` (l.313). Lui passer plutôt `isTraveler: isTraveler,` et `isProAccount: isProAccount,`.
- `_AccountTab(...)` (l.320) : retirer `activeRole: activeRole,` (l.322). Lui passer `isTraveler: isTraveler,` (il a déjà `isProAccount`).
- Adapter les constructeurs de `_ActivityTab` / `_AccountTab` : remplacer le champ `final ActiveRole activeRole;` par `final bool isTraveler;` (+ `isProAccount` pour `_ActivityTab` si besoin).

- [ ] **Step 4 : Retirer l'import si plus utilisé dans ce fichier (sauf usages restants en Task 3/4)**

Garder l'import `active_role_cubit.dart` tant que `_ActivityTab`/`_AccountTab` y réfèrent encore ; il sera retiré une fois Task 3 & 4 faites.

- [ ] **Step 5 : Vérifier**

Run: `flutter analyze lib/features/profile/presentation/profile_screen.dart`
Attendu : erreurs résiduelles uniquement dans `_ActivityTab`/`_AccountTab` (usages `activeRole`) → Tasks 3 & 4.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(profil): retrait du wrap ActiveRoleCubit + capacités passées aux tabs"
```

---

### Task 3 : `_ActivityTab` — XOR → additif

**Files:** Modify `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Step 1 : Stats adaptatives (label + section)**

Le label stats (l.453-457) et `_ActivitySection(activeRole: …)` (l.459-460) dépendent de `activeRole`. Remplacer par la capacité :

```dart
        _SectionLabel(
          label: isTraveler ? 'ACTIVITÉ · VOYAGEUR' : 'ACTIVITÉ · EXPÉDITEUR',
          cs: cs,
        ),
        _ActivitySection(
          isTraveler: isTraveler,
          totalTrips: user?.totalTrips ?? 0,
          totalShipments: user?.totalShipments ?? 0,
          isLoading: isLoading,
        )…
```

Adapter `_ActivitySection` : remplacer son champ `activeRole` par `bool isTraveler` et sa logique d'affichage de la 3ᵉ colonne en conséquence.

- [ ] **Step 2 : XOR → additif pour les sections**

Le bloc `if (activeRole == ActiveRole.traveler) ...[ sections voyageur ] else ...[ sections expéditeur ]` (à partir de l.470) devient **additif** :

```dart
        // Base commune (expéditeur) — toujours visible
        _SectionLabel(label: 'MON ACTIVITÉ', cs: cs),
        DonyListSection(tiles: [
          // … tuiles expéditeur existantes : Mes envois en cours, Mon carnet,
          //   Mes négociations, Mes litiges (déplacées hors du `else`) …
        ]),
        const SizedBox(height: DonySpacing.xl),

        // Ajout voyageur
        if (isTraveler) ...[
          _SectionLabel(label: 'MES TRAJETS', cs: cs),
          DonyListSection(tiles: [
            // … tuiles voyageur existantes : Mes trajets, Colis sur mes trajets,
            //   Modèles de trajet, Mes adresses (issues de l'ancien bloc traveler) …
          ]),
          const SizedBox(height: DonySpacing.xl),
        ],
```

> Conserver **exactement** les tuiles existantes (icônes, labels, `onTap`/routes). On ne fait que (a) sortir les tuiles expéditeur du `else` pour les rendre toujours visibles, (b) gater les tuiles voyageur par `if (isTraveler)`. Pour un voyageur, ordonner « voyageur d'abord » si `isProAccount` (optionnel — sinon ordre base puis voyageur).

- [ ] **Step 3 : Vérifier**

Run: `flutter analyze lib/features/profile/presentation/profile_screen.dart` → plus aucune référence `activeRole` dans `_ActivityTab`.

- [ ] **Step 4 : Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(profil): onglet Activité additif (base + sections voyageur)"
```

---

### Task 4 : `_AccountTab` — additif + parité (parrainage, paiements)

**Files:** Modify `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Step 1 : Repérer toutes les sections gatées + le parrainage dupliqué**

Run:
```bash
grep -n "activeRole\|isTraveler\|Parrainage\|parrain\|code parrain\|Fidélité\|Moyens de paiement\|Factures\|Devenir voyageur\|Compte PRO\|RedeemCode" lib/features/profile/presentation/profile_screen.dart
```
Identifier : (a) le `if (activeRole == traveler) … else …` de `_AccountTab` (~l.717) ; (b) les **deux** emplacements du parrainage (Fidélité voyageur / Paiements expéditeur) ; (c) la **double** entrée « J'ai un code parrain » ; (d) la section « Devenir voyageur » (expéditeur).

- [ ] **Step 2 : Sections compte → additif**

Transformer le XOR en additif, gaté par capacité :

```dart
        // Commun à tous
        // … Contact & sécurité, Identité & confiance, Portefeuille …

        // Fidélité — UNE seule section pour tous (dé-dupliquée)
        _SectionLabel(label: 'FIDÉLITÉ', cs: cs),
        DonyListSection(tiles: [
          DonyListTile(/* Parrainages → '/profile/referral' */),
          if (!hasBeenReferred)
            DonyListTile(/* "J'ai un code parrain" → RedeemCodeBottomSheet */),
        ]),

        // Paiements — commun
        // … Moyens de paiement & factures (rangés ici pour tous) …

        // Ajout voyageur
        if (isTraveler) ...[
          _SectionLabel(label: 'REVENUS & PAIEMENTS', cs: cs),
          DonyListSection(tiles: [ /* Recevoir mes paiements, Grille de prix, Commission cash */ ]),
          // Compte PRO (état via isProAccount)
          DonyListTile(/* "Passer en compte PRO" / "Mon profil PRO" */),
        ],

        // Uniquement non-voyageur
        if (!isTraveler)
          DonyListTile(/* "Devenir voyageur dony" → '/profile/become-traveler' */),
```

> Réutiliser les tuiles existantes (mêmes routes/sheets). Supprimer la **2ᵉ** occurrence du parrainage et la 2ᵉ entrée « code parrain » (consolidées dans FIDÉLITÉ). `hasBeenReferred` provient du `ReferralBloc` déjà branché (cf. usage existant) — conserver ce gating.

- [ ] **Step 3 : Retirer le champ `activeRole` de `_AccountTab`** (remplacé par `isTraveler` passé en Task 2).

- [ ] **Step 4 : Retirer l'import `active_role_cubit.dart` de `profile_screen.dart`** (plus aucun usage).

- [ ] **Step 5 : Vérifier**

Run: `flutter analyze lib/features/profile/presentation/profile_screen.dart` → « No issues found » ; `grep -n "activeRole\|ActiveRole" lib/features/profile/presentation/profile_screen.dart` → vide.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(profil): onglet Compte additif + parité (Fidélité unique, paiements alignés)"
```

---

### Task 5 : `become_traveler_screen` — retirer `switchToSender()`

**Files:** Modify `lib/features/profile/presentation/screens/become_traveler_screen.dart`

- [ ] **Step 1 : Retirer l'appel**

Dans le handler `TravelerUpgradeDeactivated` (l.49-51), supprimer la ligne :

```dart
          context.read<ActiveRoleCubit>().switchToSender();
```

Le `AuthUserSynced(state.user)` juste au-dessus met déjà à jour les rôles → la perte du rôle voyageur est reflétée par `user.isTraveler == false` (profil recompose). Retirer aussi l'import `active_role_cubit.dart` s'il n'est plus utilisé dans ce fichier.

- [ ] **Step 2 : Vérifier**

Run: `flutter analyze lib/features/profile/presentation/screens/become_traveler_screen.dart` → OK.

- [ ] **Step 3 : Commit**

```bash
git add lib/features/profile/presentation/screens/become_traveler_screen.dart
git commit -m "feat(profil): become-traveler ne touche plus active_role"
```

---

### Task 6 : Supprimer `ActiveRoleCubit` et tout son câblage

**Files:** Modify `lib/app/app.dart`, `lib/core/di/injection.dart`, `lib/app/main_shell.dart` · Delete `active_role_cubit.dart`, `role_mode_pill.dart`

> Pré-requis : Phases 1-3 implémentées (sinon erreurs de compilation = consommateurs non migrés — c'est le filet de sécurité, voir Step 1).

- [ ] **Step 1 : Vérifier qu'il ne reste que les usages attendus**

Run: `grep -rn "ActiveRoleCubit\|active_role_cubit\|ActiveRole\b" lib --include="*.dart"`
Attendu APRÈS Phases 1-4 (Tasks 1-5) : uniquement `app.dart`, `injection.dart`, `main_shell.dart` (résiduel éventuel), `active_role_cubit.dart`, `role_mode_pill.dart`. **Si d'autres fichiers apparaissent → une phase précédente n'est pas terminée : la traiter avant de continuer.**

- [ ] **Step 2 : `app.dart`**

Retirer le `BlocProvider<ActiveRoleCubit>(create: (_) => getIt<ActiveRoleCubit>())` (l.136-137), les deux appels `context.read<ActiveRoleCubit>().syncWithRoles(state.user.roles)` (l.170, 181), et l'import (l.8).

- [ ] **Step 3 : `injection.dart`**

Retirer `getIt.registerLazySingleton<ActiveRoleCubit>(() => ActiveRoleCubit(hiveService: getIt<HiveService>()))` (l.152-153) et l'import (l.69).

- [ ] **Step 4 : `main_shell.dart`**

Si une `BlocBuilder<ActiveRoleCubit>` subsiste (résidu post-Phases 1-3), la retirer ; lire les capacités nécessaires via `AuthBloc` (`user.isTraveler`/`isProAccount`) si encore requis, sinon supprimer. Vérifier : `grep -n "ActiveRole" lib/app/main_shell.dart` → vide.

- [ ] **Step 5 : Supprimer les fichiers morts**

```bash
git rm lib/features/auth/bloc/active_role_cubit.dart
git rm lib/core/widgets/role_mode_pill.dart
```

(`role_mode_pill.dart` n'est plus référencé depuis la Phase 1 ; confirmer via `grep -rn "RoleModePill" lib`.)

- [ ] **Step 6 : Compiler — le filet de sécurité**

Run: `flutter analyze`
Attendu : « No issues found ». **Toute erreur ici = un usage de `ActiveRole` oublié quelque part → le corriger** (c'est précisément le rôle de la suppression du type).

- [ ] **Step 7 : Commit**

```bash
git add -A
git commit -m "chore(role): suppression de ActiveRoleCubit et de tout son câblage (fin de la migration)"
```

---

### Task 7 : Tests profil + vérification finale

**Files:** Create/modify `test/features/profile/presentation/profile_screen_test.dart`

- [ ] **Step 1 : Widget tests ciblés (AuthBloc mocké)**

Écrire des tests qui pompent `ProfileScreen` (ou le sous-arbre testable) avec un `user` mocké et vérifient :

```dart
// Pseudo-structure — adapter aux providers réels (AuthBloc, BidBloc, AnnouncementBloc, ReferralBloc).
// Pur expéditeur (isTraveler=false) :
//   expect(find.text('Mes trajets'), findsNothing);
//   expect(find.text('Devenir voyageur dony'), findsOneWidget);
//   expect(find.byType(/* ancien _RolePill */), findsNothing);
// Voyageur (isTraveler=true) :
//   expect(find.text('Mes trajets'), findsWidgets);
//   expect(find.text('Devenir voyageur dony'), findsNothing);
// Voyageur pro (isProAccount=true) :
//   expect(find.text('Mon profil PRO'), findsOneWidget);
// Parité : une seule section 'FIDÉLITÉ' ; pas de double "J'ai un code parrain".
```

> Si le pompage complet de `ProfileScreen` est trop lourd (multiples BLoCs/getIt), extraire `_ActivityTab`/`_AccountTab` en widgets publics testables prenant `isTraveler`/`isProAccount` en paramètres, et tester ceux-là isolément.

- [ ] **Step 2 : Vérifier les tests** → `flutter test test/features/profile/` → PASS.

- [ ] **Step 3 : Grep final + format + analyze + suite**

```bash
grep -rn "ActiveRole\|active_role" lib --include="*.dart"   # → vide
dart format lib/features/profile/ lib/app/ lib/core/di/ test/features/profile/
flutter analyze
flutter test --coverage
```
Attendu : aucun résultat grep, « No issues found », tous les tests PASS, couverture ≥ 90 %.

- [ ] **Step 4 : Checklist QA manuelle**

- [ ] **Pur expéditeur** : profil = Activité (envois, carnet, litiges) + Compte (contact, KYC, portefeuille, Fidélité, paiements, **Devenir voyageur**) + Réglages. **Aucun switch**, aucune section voyageur.
- [ ] **Voyageur** : voit en plus Mes trajets / Colis sur mes trajets / Modèles / Adresses (Activité) et Revenus & paiements / Grille de prix (Compte) — **en permanence**, sans bascule. « Devenir voyageur » absent.
- [ ] **Voyageur pro** : « Mon profil PRO » visible.
- [ ] **Parité** : une seule section Fidélité ; pas de doublon « J'ai un code parrain ».
- [ ] **become-traveler** : activer/désactiver le rôle voyageur → le profil recompose (sections apparaissent/disparaissent) sans erreur.
- [ ] Aucune référence `active_role` nulle part ; l'app démarre et navigue normalement sur les 4 onglets.

- [ ] **Step 5 : Commit final**

```bash
git add -A
git commit -m "test(profil): widget tests profils + vérification finale Phase 4"
```

---

## Self-review (effectuée)

- **Couverture spec :** additif par capacité (T2, T3, T4) · retrait switch pill (T1) · parité parrainage/paiements (T4) · doublon Activité↔Annonces gardé (aucune suppression de tuile) · suppression `ActiveRoleCubit` + câblage (T5, T6) · stats adaptatives (T3) · tests (T7). ✅
- **Pas de placeholder :** les steps « repérer » (T4 S1, T6 S1) sont des `grep` concrets ; les blocs de code montrent la transformation XOR→additif réelle (ancrée sur l.453-470 lues).
- **Cohérence des types :** params `isTraveler`/`isProAccount` substitués à `activeRole` partout (`ProfileHeader`, `_ActivityTab`, `_ActivitySection`, `_AccountTab`) ; suppression du type `ActiveRole` = vérification par compilation (T6 S6).
- **Séquencement :** ⛔ Phase 4 après Phases 1-3 (la suppression du cubit ne compile qu'une fois toutes les surfaces migrées) — rappelé en tête + filet T6 S1.
- **Note honnête :** refactor structurel à dominante non-pure → validé par widget tests ciblés + compilateur + QA (pas de fonction pure à TDD ici).
