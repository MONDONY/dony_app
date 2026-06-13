# Phase 2 — Annonces (additif, piloté par isProAccount) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire de l'onglet Annonces une surface additive sans switch : le primaire dépend du profil (pur expéditeur → Envoyer ; voyageur occasionnel → Envoyer + entrée « Mes trajets » ; voyageur pro → Mes trajets + entrée « Envoyer un colis »), en réutilisant les écrans existants tels quels.

**Architecture :** Le dispatcher `MatchingManagementScreen` ne lit plus `ActiveRoleCubit` mais `AuthBloc` (`user.isTraveler`, `user.isProAccount`). Une fonction pure `annoncesLayoutFor()` décide du layout (cœur testable). Les écrans `EnvoyerHubScreen` et `AnnouncementListScreen` reçoivent une **entrée secondaire optionnelle** (callback gaté). Les destinations secondaires sont des routes GoRouter dédiées.

**Tech Stack :** Flutter, flutter_bloc (AuthBloc, AnnouncementBloc, PackageRequestBloc…), GoRouter, GetIt, flutter_test.

**Référence spec :** `docs/superpowers/specs/2026-06-09-phase-2-annonces-design.md`
**Fondation :** `docs/superpowers/specs/2026-06-08-navigation-additive-model-foundation.md`

**Stratégie de test (réaliste) :** le dispatcher et les écrans Annonces instancient de nombreux BLoCs via GetIt (lourd à monter en widget test). On concentre le TDD sur (1) la fonction pure `annoncesLayoutFor()` et (2) le widget isolé `SecondaryActivityEntry`. La composition du dispatcher est validée par checklist QA manuelle (Task 9).

**Garantie zéro-régression (mapping) :**
- Pur expéditeur (`!isTraveler`) → `EnvoyerHubScreen` sans entrée secondaire → **strictement inchangé**.
- Voyageur occasionnel (`isTraveler && !isPro`) → `EnvoyerHubScreen` (défaut Envois) + entrée « Mes trajets » → l'écran trajets reste accessible (poussé), inchangé.
- Voyageur pro (`isProAccount`) → `AnnouncementListScreen` + entrée « Envoyer un colis » → l'écran envois reste accessible (poussé), inchangé.

---

## File Structure

| Fichier | Responsabilité |
|---|---|
| `lib/features/matching/presentation/annonces_layout.dart` | **Créé.** Enum `AnnoncesLayout` + fonction pure `annoncesLayoutFor()`. |
| `lib/features/matching/presentation/widgets/secondary_activity_entry.dart` | **Créé.** Widget d'entrée secondaire (icône + label + onTap). |
| `lib/features/matching/presentation/screens/matching_management_screen.dart` | **Modifié.** Composition par profil via `AuthBloc` (au lieu de `ActiveRoleCubit`). |
| `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart` | **Modifié.** Param optionnel `onShowTrips` → entrée « Mes trajets » dans le header (gatée). |
| `lib/features/matching/presentation/screens/announcement_list_screen.dart` | **Modifié.** Param optionnel `onSendParcel` → entrée « Envoyer un colis » (gatée). |
| `lib/app/router.dart` | **Modifié.** Routes `/announcements/trips` et `/announcements/send`. |
| `lib/app/main_shell.dart` | **Modifié.** Onglet 1 (Annonces) : label+icône figés. |
| `lib/core/services/analytics_events.dart` | **Modifié.** `annoncesTripsOpened`, `annoncesSendOpened`. |
| `CLAUDE.md` | **Modifié.** Table des events. |
| `test/features/matching/presentation/annonces_layout_test.dart` | **Créé.** Tests unitaires `annoncesLayoutFor()`. |
| `test/features/matching/presentation/widgets/secondary_activity_entry_test.dart` | **Créé.** Test widget. |

---

### Task 1 : Logique pure `AnnoncesLayout` + `annoncesLayoutFor()`

**Files:**
- Create: `lib/features/matching/presentation/annonces_layout.dart`
- Test: `test/features/matching/presentation/annonces_layout_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
// test/features/matching/presentation/annonces_layout_test.dart
import 'package:dony/features/matching/presentation/annonces_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('annoncesLayoutFor', () {
    test('non voyageur → senderOnly (quel que soit isPro)', () {
      expect(annoncesLayoutFor(isTraveler: false, isPro: false),
          AnnoncesLayout.senderOnly);
      expect(annoncesLayoutFor(isTraveler: false, isPro: true),
          AnnoncesLayout.senderOnly);
    });

    test('voyageur non pro → occasionalTraveler', () {
      expect(annoncesLayoutFor(isTraveler: true, isPro: false),
          AnnoncesLayout.occasionalTraveler);
    });

    test('voyageur pro → proTraveler', () {
      expect(annoncesLayoutFor(isTraveler: true, isPro: true),
          AnnoncesLayout.proTraveler);
    });
  });
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/matching/presentation/annonces_layout_test.dart`
Expected: FAIL — URI `annonces_layout.dart` introuvable.

- [ ] **Step 3 : Implémenter**

```dart
// lib/features/matching/presentation/annonces_layout.dart

/// Présentation de l'onglet Annonces selon le profil réel de l'utilisateur.
/// Déterministe : pas de switch, pas d'heuristique d'usage.
enum AnnoncesLayout {
  /// Pur expéditeur : Envoyer (Envois | Demandes), aucune entrée voyageur.
  senderOnly,

  /// Voyageur occasionnel : Envoyer en primaire + entrée « Mes trajets ».
  occasionalTraveler,

  /// Voyageur pro : Mes trajets en primaire + entrée « Envoyer un colis ».
  proTraveler,
}

AnnoncesLayout annoncesLayoutFor({
  required bool isTraveler,
  required bool isPro,
}) {
  if (!isTraveler) return AnnoncesLayout.senderOnly;
  if (isPro) return AnnoncesLayout.proTraveler;
  return AnnoncesLayout.occasionalTraveler;
}
```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

Run: `flutter test test/features/matching/presentation/annonces_layout_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/matching/presentation/annonces_layout.dart test/features/matching/presentation/annonces_layout_test.dart
git commit -m "feat(annonces): logique pure du layout par profil (AnnoncesLayout)"
```

---

### Task 2 : Widget `SecondaryActivityEntry`

**Files:**
- Create: `lib/features/matching/presentation/widgets/secondary_activity_entry.dart`
- Test: `test/features/matching/presentation/widgets/secondary_activity_entry_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
// test/features/matching/presentation/widgets/secondary_activity_entry_test.dart
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le label et notifie au tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SecondaryActivityEntry(
          icon: Icons.flight_takeoff_rounded,
          label: 'Mes trajets',
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Mes trajets'), findsOneWidget);
    await tester.tap(find.byType(SecondaryActivityEntry));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/matching/presentation/widgets/secondary_activity_entry_test.dart`
Expected: FAIL — URI introuvable.

- [ ] **Step 3 : Implémenter le widget**

```dart
// lib/features/matching/presentation/widgets/secondary_activity_entry.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Entrée additive vers l'autre activité (Mes trajets / Envoyer un colis).
/// Affichée seulement pour les profils qui en ont besoin (gatée par l'appelant).
class SecondaryActivityEntry extends StatelessWidget {
  const SecondaryActivityEntry({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

Run: `flutter test test/features/matching/presentation/widgets/secondary_activity_entry_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/matching/presentation/widgets/secondary_activity_entry.dart test/features/matching/presentation/widgets/secondary_activity_entry_test.dart
git commit -m "feat(annonces): widget SecondaryActivityEntry (entrée additive)"
```

---

### Task 3 : Routes des destinations secondaires

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1 : Localiser la route `/announcements`**

Run: `grep -n "'/announcements'\|/announcements/create\|MatchingManagementScreen\|AnnouncementBloc" lib/app/router.dart`
Repérer le bloc de routes `/announcements*` et le pattern de `BlocProvider`/`getIt`.

- [ ] **Step 2 : Ajouter les deux routes (siblings de `/announcements/create`)**

Ajouter dans la liste des routes (mêmes imports déjà présents : `AnnouncementListScreen`, `EnvoyerHubScreen`, `AnnouncementBloc`, `getIt`) :

```dart
GoRoute(
  path: '/announcements/trips',
  builder: (context, state) => BlocProvider(
    create: (_) => getIt<AnnouncementBloc>(),
    child: const AnnouncementListScreen(),
  ),
),
GoRoute(
  path: '/announcements/send',
  builder: (context, state) => const EnvoyerHubScreen(),
),
```

> Vérifier les imports en tête de `router.dart` ; ajouter ceux manquants :
> `import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';`
> `import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';`
> `import 'package:dony/features/matching/bloc/announcement_bloc.dart';`
> (la plupart sont sans doute déjà là.)

- [ ] **Step 3 : Vérifier compilation**

Run: `flutter analyze lib/app/router.dart`
Expected: aucune erreur.

- [ ] **Step 4 : Commit**

```bash
git add lib/app/router.dart
git commit -m "feat(annonces): routes /announcements/trips et /announcements/send"
```

---

### Task 4 : Entrée « Mes trajets » optionnelle sur `EnvoyerHubScreen`

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart`

- [ ] **Step 1 : Ajouter le param optionnel à `EnvoyerHubScreen`**

Remplacer la déclaration (l.24-25) :

```dart
class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({super.key});
```

par :

```dart
class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({super.key, this.onShowTrips});

  /// Entrée additive « Mes trajets » (voyageur occasionnel). Null = non affichée.
  final VoidCallback? onShowTrips;
```

- [ ] **Step 2 : Passer le callback au header**

Dans le `build` (l.340), remplacer `_EnvoyerHeader(onNew: _onNew),` par :

```dart
              _EnvoyerHeader(onNew: _onNew, onShowTrips: widget.onShowTrips),
```

- [ ] **Step 3 : Rendre l'entrée dans `_EnvoyerHeader`**

Ajouter le param à `_EnvoyerHeader` (l.365-368) :

```dart
class _EnvoyerHeader extends StatelessWidget {
  const _EnvoyerHeader({required this.onNew, this.onShowTrips});

  final VoidCallback onNew;
  final VoidCallback? onShowTrips;
```

Puis, dans son `build`, sous le `Row` du titre « Envoyer » (après le `Row(children: [Text('Envoyer'...), Spacer, onNew button])`), ajouter l'entrée quand `onShowTrips != null`. Envelopper le contenu existant dans une `Column` :

```dart
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg, DonySpacing.base, DonySpacing.lg, DonySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // … Text('Envoyer') + Spacer + bouton onNew existants, inchangés …
            ],
          ),
          if (onShowTrips != null) ...[
            const SizedBox(height: DonySpacing.sm),
            SecondaryActivityEntry(
              icon: Icons.flight_takeoff_rounded,
              label: 'Mes trajets',
              onTap: onShowTrips!,
            ),
          ],
        ],
      ),
    );
```

Ajouter l'import :
```dart
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
```

- [ ] **Step 4 : Vérifier compilation**

Run: `flutter analyze lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart`
Expected: aucune erreur. (Comportement inchangé tant que `onShowTrips` est null → pur expéditeur intact.)

- [ ] **Step 5 : Commit**

```bash
git add lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart
git commit -m "feat(annonces): entrée optionnelle 'Mes trajets' sur EnvoyerHubScreen"
```

---

### Task 5 : Entrée « Envoyer un colis » optionnelle sur `AnnouncementListScreen`

**Files:**
- Modify: `lib/features/matching/presentation/screens/announcement_list_screen.dart`

- [ ] **Step 1 : Ajouter le param optionnel**

Remplacer (l.17-18) :

```dart
class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});
```

par :

```dart
class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key, this.onSendParcel});

  /// Entrée additive « Envoyer un colis » (voyageur pro). Null = non affichée.
  final VoidCallback? onSendParcel;
```

- [ ] **Step 2 : Rendre l'entrée en haut du body**

Dans le `build` du state, le body retourne une `Column` (l.149). Insérer l'entrée tout en haut de cette `Column`, quand `widget.onSendParcel != null` :

```dart
          return Column(
            children: [
              if (widget.onSendParcel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg, DonySpacing.sm, DonySpacing.lg, 0,
                  ),
                  child: SecondaryActivityEntry(
                    icon: Icons.local_shipping_rounded,
                    label: 'Envoyer un colis',
                    onTap: widget.onSendParcel!,
                  ),
                ),
              // "En cours" section — pinned above tabs …
              if (inProgressList.isNotEmpty) ...[
                _InProgressSection(announcements: inProgressList, tt: tt, cs: cs),
              ],
              // … reste inchangé …
```

Ajouter l'import :
```dart
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
```

> Vérifier que `DonySpacing` est accessible (il l'est via `design_system.dart`, déjà importé l.7).

- [ ] **Step 3 : Vérifier compilation**

Run: `flutter analyze lib/features/matching/presentation/screens/announcement_list_screen.dart`
Expected: aucune erreur. (Comportement inchangé tant que `onSendParcel` est null.)

- [ ] **Step 4 : Commit**

```bash
git add lib/features/matching/presentation/screens/announcement_list_screen.dart
git commit -m "feat(annonces): entrée optionnelle 'Envoyer un colis' sur AnnouncementListScreen"
```

---

### Task 6 : Recâbler `MatchingManagementScreen` (composition par profil)

**Files:**
- Modify: `lib/features/matching/presentation/screens/matching_management_screen.dart`

- [ ] **Step 1 : Réécrire le dispatcher**

Remplacer tout le contenu du fichier par :

```dart
import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/presentation/annonces_layout.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Onglet Annonces — additif, piloté par le profil (capacité + statut pro).
/// Aucun switch de rôle : la présentation découle de `user.isTraveler` /
/// `user.isProAccount` (voir spec Phase 2).
class MatchingManagementScreen extends StatelessWidget {
  const MatchingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final UserModel? user = switch (authState) {
      AuthAuthenticated s => s.user,
      AuthProfileUpdated s => s.user,
      _ => null,
    };
    final layout = annoncesLayoutFor(
      isTraveler: user?.isTraveler ?? false,
      isPro: user?.isProAccount ?? false,
    );

    switch (layout) {
      case AnnoncesLayout.senderOnly:
        return const EnvoyerHubScreen(key: ValueKey('sender_view'));

      case AnnoncesLayout.occasionalTraveler:
        return EnvoyerHubScreen(
          key: const ValueKey('occasional_view'),
          onShowTrips: () {
            unawaited(getIt<AnalyticsService>()
                .logEvent(AnalyticsEvents.annoncesTripsOpened));
            context.push('/announcements/trips');
          },
        );

      case AnnoncesLayout.proTraveler:
        return BlocProvider(
          key: const ValueKey('pro_view'),
          create: (_) => getIt<AnnouncementBloc>(),
          child: AnnouncementListScreen(
            onSendParcel: () {
              unawaited(getIt<AnalyticsService>()
                  .logEvent(AnalyticsEvents.annoncesSendOpened));
              context.push('/announcements/send');
            },
          ),
        );
    }
  }
}
```

- [ ] **Step 2 : Vérifier compilation**

Run: `flutter analyze lib/features/matching/presentation/screens/matching_management_screen.dart`
Expected: erreurs uniquement sur `AnalyticsEvents.annoncesTripsOpened/annoncesSendOpened` (ajoutés en Task 8). On les ajoute juste après ; ou faire Task 8 avant ce step. Sinon : aucune erreur.

- [ ] **Step 3 : Commit**

```bash
git add lib/features/matching/presentation/screens/matching_management_screen.dart
git commit -m "feat(annonces): composition par profil via AuthBloc (fin du dispatch active_role)"
```

---

### Task 7 : Bottom-nav — onglet Annonces figé

**Files:**
- Modify: `lib/app/main_shell.dart`

- [ ] **Step 1 : Figer le label + l'icône du tab 1**

Le `_DonyBottomNav` reste enveloppé dans `BlocBuilder<ActiveRoleCubit>` (encore nécessaire pour le tab 2 Suivi, migré en Phase 3). On retire seulement la dépendance du tab 1. Remplacer (l.169-176) :

```dart
        // Tab 1 — Envoyer (sender) ou Trajets (traveler)
        final tab1Label = isTraveler ? 'Trajets' : 'Envoyer';
        final tab1Icon = isTraveler
            ? Icons.send_rounded
            : Icons.arrow_circle_right_rounded;
        final tab1IconOutlined = isTraveler
            ? Icons.send_outlined
            : Icons.arrow_circle_right_outlined;
```

par :

```dart
        // Tab 1 — Annonces (libellé + icône figés ; le contenu s'adapte au profil
        // dans MatchingManagementScreen — voir spec Phase 2)
        const tab1Label = 'Annonces';
        const tab1Icon = Icons.article_rounded;
        const tab1IconOutlined = Icons.article_outlined;
```

- [ ] **Step 2 : Vérifier compilation + analyze**

Run: `flutter analyze lib/app/main_shell.dart`
Expected: aucune erreur. (`isProAccount` à la l.163 reste utilisé ailleurs ; `isTraveler` reste utilisé par le tab 2 → pas de warning unused.)

- [ ] **Step 3 : Commit**

```bash
git add lib/app/main_shell.dart
git commit -m "feat(annonces): onglet bottom-nav Annonces figé (fin de la dépendance active_role pour le tab 1)"
```

---

### Task 8 : Analytics — events des entrées secondaires

**Files:**
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `CLAUDE.md`

- [ ] **Step 1 : Déclarer les events**

Dans `lib/core/services/analytics_events.dart`, sous une section Annonces (après les events « Envois » / `envoyerDemandesScreen`, l.75) :

```dart
  // Annonces (entrées additives)
  static const annoncesTripsOpened = 'annonces_trips_opened';
  static const annoncesSendOpened  = 'annonces_send_opened';
```

- [ ] **Step 2 : Mettre à jour la table d'events de `CLAUDE.md`**

Dans `dony_app-analytics/CLAUDE.md`, table « Events actuellement implémentés », ajouter :

```
| `annonces_trips_opened` | MatchingManagementScreen — entrée « Mes trajets » (voyageur occasionnel) |
| `annonces_send_opened`  | MatchingManagementScreen — entrée « Envoyer un colis » (voyageur pro) |
```

- [ ] **Step 3 : Vérifier compilation globale**

Run: `flutter analyze`
Expected: aucune erreur (le dispatcher de Task 6 résout maintenant ses constantes).

- [ ] **Step 4 : Commit**

```bash
git add lib/core/services/analytics_events.dart CLAUDE.md
git commit -m "feat(annonces): analytics des entrées additives (trips/send opened)"
```

---

### Task 9 : Vérification finale (format, analyze, suite, QA manuelle)

**Files:**
- (Aucune création — vérification.)

- [ ] **Step 1 : Format + analyze**

Run: `dart format lib/features/matching/ lib/features/package_request/presentation/screens/sender/ lib/app/ test/features/matching/ && flutter analyze`
Expected: « No issues found ».

- [ ] **Step 2 : Suite complète + couverture**

Run: `flutter test --coverage`
Expected: tous les tests PASS (aucune régression sur les suites Envoyer/Trajets existantes).

- [ ] **Step 3 : Checklist QA manuelle (composition non testable en widget test)**

Sur émulateur, avec 3 comptes (ou en simulant les flags `isTraveler`/`isProAccount`) :
- [ ] **Pur expéditeur** : onglet Annonces = écran « Envoyer » (Envois | Demandes), **aucune** entrée « Mes trajets ». Identique à avant.
- [ ] **Voyageur occasionnel** : écran « Envoyer » (défaut Envois) + entrée « 🧳 Mes trajets » → ouvre l'écran trajets (FAB créer, status tabs OK).
- [ ] **Voyageur pro** : écran « Mes trajets » + entrée « 📦 Envoyer un colis » → ouvre l'écran Envoyer (Envois | Demandes, « + nouvel envoi »).
- [ ] **Bottom-nav** : onglet « Annonces » label + icône identiques quel que soit le profil.
- [ ] **Création** : créer un trajet (FAB) et créer un envoi (+ nouvel envoi, KYC) fonctionnent dans les deux sens.
- [ ] **PostHog** : `annonces_trips_opened` / `annonces_send_opened` émis aux taps.
- [ ] **Bascule pro** pendant la session (via profil) → l'onglet Annonces recompose (AuthProfileUpdated).

- [ ] **Step 4 : Commit final**

```bash
git add -A
git commit -m "chore(annonces): vérification finale Phase 2 (composition par profil)"
```

---

## Self-review (effectuée)

- **Couverture spec :** composition par profil (T1, T6) · entrée secondaire gatée (T2, T4, T5) · routes secondaires (T3) · réutilisation des écrans existants (T4/T5/T6 sans toucher au contenu) · bottom-nav figé (T7) · analytics (T8) · zéro-régression (mapping + QA T9). ✅
- **Pas de placeholder :** le seul step « localiser » (T3) est un `grep` concret.
- **Cohérence des types :** `AnnoncesLayout{senderOnly,occasionalTraveler,proTraveler}`, `annoncesLayoutFor({isTraveler,isPro})`, `SecondaryActivityEntry{icon,label,onTap}`, `EnvoyerHubScreen.onShowTrips`, `AnnouncementListScreen.onSendParcel`, routes `/announcements/trips` & `/announcements/send`, events `annoncesTripsOpened`/`annoncesSendOpened` — cohérents entre tâches.
- **Note honnête :** dispatcher + écrans = lourds (GetIt/BLoCs) → TDD sur la fonction pure + le widget d'entrée ; composition validée en QA (T9). `EnvoyerHubScreen`/`AnnouncementListScreen` reçoivent un param **optionnel** → profil pur expéditeur strictement inchangé.
- **Ordre :** si l'exécutant veut éviter l'erreur transitoire de compilation au T6 Step 2, faire Task 8 avant Task 6.
