# Profil Voyageur — Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructurer la section voyageur du ProfileScreen en 6 sections logiques, ajouter une icône settings dans le ProfileHeader, et enrichir le collapsed AppBar title avec avatar + badge doré — sans régression sur la section sender ni sur le header existant.

**Architecture:** Modifications dans deux fichiers seulement. `profile_header.dart` reçoit un paramètre `onSettingsTap` optionnel et un nouveau `Positioned`. `profile_screen.dart` remplace la liste plate traveler par 6 `_SectionLabel` + `DonyListSection`, et enrichit le `title:` du `SliverAppBar` d'une `Row` animée (avatar + nom + badge). Aucune nouvelle route, aucun nouveau BLoC, aucun nouveau composant.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, flutter_animate, design_system (DonyAvatar · DonyAvatarSize · DonyColors · DonySpacing · DonyRadius)

---

## Fichiers touchés

| Action | Fichier |
|--------|---------|
| Modify | `lib/features/profile/presentation/widgets/profile_header.dart` |
| Modify | `lib/features/profile/presentation/profile_screen.dart` |
| Modify (tests) | `test/features/profile/presentation/profile_header_test.dart` |
| Modify (tests) | `test/features/profile/presentation/profile_screen_test.dart` |

---

## Task 1 : Tests failing — ProfileHeader settings icon

**Files:**
- Modify: `test/features/profile/presentation/profile_header_test.dart`

- [ ] **Ajouter le paramètre `onSettingsTap` au helper `_buildHeader`**

Ouvrir `test/features/profile/presentation/profile_header_test.dart` et modifier la signature de `_buildHeader` :

```dart
Widget _buildHeader({
  ActiveRole role = ActiveRole.sender,
  bool isTraveler = false,
  bool isSender = true,
  bool isKycVerified = false,
  int totalTrips = 0,
  int totalShipments = 0,
  bool isLoadingStats = false,
  bool isProAccount = false,
  VoidCallback? onNotificationTap,
  VoidCallback? onSettingsTap,        // ← nouveau
  ValueChanged<ActiveRole>? onRoleSwitch,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ProfileHeader(
        displayName: 'Ibrahima Diallo',
        activeRole: role,
        isTraveler: isTraveler,
        isSender: isSender,
        isKycVerified: isKycVerified,
        isProAccount: isProAccount,
        totalTrips: totalTrips,
        totalShipments: totalShipments,
        isLoadingStats: isLoadingStats,
        onNotificationTap: onNotificationTap,
        onSettingsTap: onSettingsTap,   // ← nouveau
        onRoleSwitch: onRoleSwitch,
      ),
    ),
  );
}
```

- [ ] **Ajouter les deux tests settings à la fin du groupe `ProfileHeader`**

```dart
testWidgets('settings icon absent when onSettingsTap is null', (tester) async {
  await tester.pumpWidget(_buildHeader());
  await tester.pump();
  expect(find.byTooltip('Paramètres'), findsNothing);
});

testWidgets('calls onSettingsTap when settings button tapped', (tester) async {
  var tapped = false;
  await tester.pumpWidget(_buildHeader(onSettingsTap: () => tapped = true));
  await tester.pump();
  await tester.tap(find.byTooltip('Paramètres'));
  expect(tapped, isTrue);
});
```

- [ ] **Vérifier que les tests échouent**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/profile/presentation/profile_header_test.dart
```

Expected : les 2 nouveaux tests FAIL avec `The named parameter 'onSettingsTap' isn't defined`.

---

## Task 2 : Ajouter `onSettingsTap` dans ProfileHeader

**Files:**
- Modify: `lib/features/profile/presentation/widgets/profile_header.dart`

- [ ] **Ajouter le paramètre dans la classe**

Après `final VoidCallback? onNotificationTap;` (ligne 20), insérer :

```dart
final VoidCallback? onSettingsTap;
```

- [ ] **Ajouter au constructeur**

Après `this.onNotificationTap,`, insérer :

```dart
this.onSettingsTap,
```

- [ ] **Ajouter le Positioned dans le Stack**

Dans le `Stack`, juste après le bloc `if (onNotificationTap != null)`, ajouter :

```dart
if (onSettingsTap != null)
  Positioned(
    top: 0,
    right: 0,
    child: IconButton(
      icon: const Icon(
        Icons.settings_outlined,
        color: DonyColors.textOnBrand,
      ),
      onPressed: onSettingsTap,
      tooltip: 'Paramètres',
    ),
  ),
```

- [ ] **Vérifier que les tests passent**

```bash
flutter test test/features/profile/presentation/profile_header_test.dart
```

Expected : tous les tests PASS, dont les 2 nouveaux.

- [ ] **Commit**

```bash
git add lib/features/profile/presentation/widgets/profile_header.dart \
        test/features/profile/presentation/profile_header_test.dart
git commit -m "$(cat <<'EOF'
feat(profile): ajouter icône settings dans ProfileHeader

Paramètre onSettingsTap optionnel positionné en haut à droite,
même niveau que la photo de profil.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Tests failing — sections voyageur

**Files:**
- Modify: `test/features/profile/presentation/profile_screen_test.dart`

- [ ] **Ajouter le fixture `_travelerUser`** après `_pendingDeletionUser` :

```dart
final _travelerUser = UserModel(
  id: 'user-3',
  firstName: 'Amadou',
  lastName: 'Diallo',
  roles: const ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  totalTrips: 3,
);
```

- [ ] **Ajouter les routes manquantes** dans `_buildTestHarness` (dans la liste `routes`) :

```dart
GoRoute(
  path: '/announcements',
  builder: (_, __) => const Scaffold(body: Text('Announcements')),
),
GoRoute(
  path: '/package-requests/search',
  builder: (_, __) => const Scaffold(body: Text('PackageRequestsSearch')),
),
GoRoute(
  path: '/negotiations',
  builder: (_, __) => const Scaffold(body: Text('Negotiations')),
),
GoRoute(
  path: '/profile/public',
  builder: (_, __) => const Scaffold(body: Text('PublicProfile')),
),
GoRoute(
  path: '/profile/reviews',
  builder: (_, __) => const Scaffold(body: Text('Reviews')),
),
GoRoute(
  path: '/disputes',
  builder: (_, __) => const Scaffold(body: Text('Disputes')),
),
GoRoute(
  path: '/profile/help/contact',
  builder: (_, __) => const Scaffold(body: Text('Contact')),
),
GoRoute(
  path: '/profile/help/faq',
  builder: (_, __) => const Scaffold(body: Text('FAQ')),
),
```

- [ ] **Ajouter le groupe de tests traveler** à la fin du `main()` :

```dart
group('Section voyageur', () {
  setUp(() {
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_travelerUser),
    );
    whenListen<AccountDeletionState>(
      deletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );
    when(() => activeRoleCubit.state).thenReturn(ActiveRole.traveler);
  });

  testWidgets('affiche les 6 section labels voyageur', (tester) async {
    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    for (final label in [
      'MON ACTIVITÉ',
      'REVENUS & PAIEMENTS',
      'COMPTE PRO',
      'IDENTITÉ & CONFIANCE',
      'FIDÉLITÉ',
      'SUPPORT',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget, reason: 'Section "$label" manquante');
    }
  });

  testWidgets('affiche "Colis sur mes trajets" et pas "Demandes d\'envoi à transporter"',
      (tester) async {
    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('Colis sur mes trajets'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Colis sur mes trajets'), findsOneWidget);
    expect(find.text("Demandes d'envoi à transporter"), findsNothing);
  });

  testWidgets('affiche "Mon profil public" dans IDENTITÉ & CONFIANCE', (tester) async {
    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('Mon profil public'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mon profil public'), findsOneWidget);
  });

  testWidgets('affiche "Mes avis reçus" dans IDENTITÉ & CONFIANCE', (tester) async {
    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('Mes avis reçus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mes avis reçus'), findsOneWidget);
  });

  testWidgets('affiche les 3 tiles SUPPORT', (tester) async {
    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    for (final tile in ['Mes litiges', 'Contacter le support', 'FAQ & aide']) {
      await tester.scrollUntilVisible(
        find.text(tile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(tile), findsOneWidget, reason: '$tile manquant dans SUPPORT');
    }
  });

  testWidgets('badge "2 matchs" visible quand 2 annonces ACTIVE', (tester) async {
    final now = DateTime(2026, 6, 1);
    whenListen<AnnouncementState>(
      announcementBloc,
      const Stream.empty(),
      initialState: AnnouncementListLoaded(
        announcements: List.generate(
          2,
          (i) => AnnouncementModel(
            id: 'ann-$i',
            travelerId: 'user-3',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: now,
            availableKg: 10,
            totalKg: 10,
            pricePerKg: 5,
            status: 'ACTIVE',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.scrollUntilVisible(
      find.text('2 matchs'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 matchs'), findsOneWidget);
  });

  testWidgets('pas de badge matchs quand 0 annonces ACTIVE', (tester) async {
    whenListen<AnnouncementState>(
      announcementBloc,
      const Stream.empty(),
      initialState: AnnouncementListLoaded(announcements: const []),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('matchs'), findsNothing);
  });

  testWidgets('section sender non impactée quand activeRole == sender', (tester) async {
    when(() => activeRoleCubit.state).thenReturn(ActiveRole.sender);
    whenListen<AuthState>(
      authBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_activeUser),
    );

    await tester.pumpWidget(_buildTestHarness(
      authBloc: authBloc,
      deletionBloc: deletionBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
      activeRoleCubit: activeRoleCubit,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('MON ACTIVITÉ'), findsNothing);
    expect(find.text('SUPPORT'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Mes envois en cours'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mes envois en cours'), findsOneWidget);
  });
});
```

- [ ] **Ajouter l'import manquant** en tête du fichier si absent :

```dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
```

- [ ] **Vérifier que les tests échouent**

```bash
flutter test test/features/profile/presentation/profile_screen_test.dart
```

Expected : les tests du groupe `Section voyageur` FAIL avec des erreurs de widget not found.

---

## Task 4 : Restructurer la section voyageur dans profile_screen.dart

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Remplacer le bloc `if (activeRole == ActiveRole.traveler) ...[...]`**

Localiser le bloc qui commence à la ligne `if (activeRole == ActiveRole.traveler) ...[` (autour de la ligne 229) et le remplacer intégralement par :

```dart
if (activeRole == ActiveRole.traveler) ...[
  // ─── MON ACTIVITÉ ─────────────────────────────────
  _SectionLabel(label: 'MON ACTIVITÉ', cs: cs),
  DonyListSection(
    tiles: [
      DonyListTile(
        icon: Icons.flight_takeoff_rounded,
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Mes trajets',
        trailing: upcomingAnnouncements > 0
            ? Text(
                '$upcomingAnnouncements à venir',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        onTap: () => context.push('/announcements'),
      ),
      DonyListTile(
        icon: Icons.inventory_2_outlined,
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Colis sur mes trajets',
        trailing: upcomingAnnouncements > 0
            ? Text(
                '$upcomingAnnouncements matchs',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        onTap: () => context.push('/package-requests/search'),
      ),
      DonyListTile(
        icon: Icons.handshake_rounded,
        iconColor: cs.tertiary,
        iconBgColor: cs.tertiaryContainer,
        label: 'Mes négociations',
        showDivider: false,
        onTap: () => context.push('/negotiations'),
      ),
    ],
  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  const SizedBox(height: DonySpacing.lg),

  // ─── REVENUS & PAIEMENTS ───────────────────────────
  _SectionLabel(label: 'REVENUS & PAIEMENTS', cs: cs),
  DonyListSection(
    tiles: [
      DonyListTile(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: cs.success,
        iconBgColor: cs.successLight,
        label: 'Recevoir mes paiements',
        onTap: () => context.push('/payments/onboarding'),
      ),
      DonyListTile(
        icon: Icons.credit_card_rounded,
        iconColor: DonyColors.purple,
        iconBgColor: DonyColors.violetLight,
        label: 'Carte commission cash',
        onTap: () => context.push('/payments/commission-method'),
      ),
      DonyListTile(
        icon: Icons.credit_card_outlined,
        iconColor: DonyColors.purple,
        iconBgColor: DonyColors.violetLight,
        label: 'Paiements & factures',
        showDivider: false,
        onTap: () => ComingSoonBottomSheet.show(
          context,
          title: 'Paiements & factures',
          description:
              'Retrouve ici tes paiements reçus et tes factures téléchargeables.',
          icon: Icons.credit_card_rounded,
        ),
      ),
    ],
  ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  const SizedBox(height: DonySpacing.lg),

  // ─── COMPTE PRO ────────────────────────────────────
  _SectionLabel(label: 'COMPTE PRO', cs: cs),
  DonyListSection(
    tiles: [
      DonyListTile(
        icon: Icons.business_center_rounded,
        iconColor: isProAccount ? cs.success : cs.warning,
        iconBgColor: isProAccount ? cs.successLight : cs.warningLight,
        label: isProAccount ? 'Mon profil PRO' : 'Passer en compte PRO',
        trailing: isProAccount
            ? Icon(Icons.verified_rounded, color: cs.success, size: 18)
            : null,
        showDivider: false,
        onTap: user != null
            ? () => UpgradeProBottomSheet.show(context, user: user!)
            : null,
      ),
    ],
  ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  const SizedBox(height: DonySpacing.lg),

  // ─── IDENTITÉ & CONFIANCE ──────────────────────────
  _SectionLabel(label: 'IDENTITÉ & CONFIANCE', cs: cs),
  DonyListSection(
    tiles: [
      _kycTile(context, user),
      DonyListTile(
        icon: Icons.account_box_outlined,
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Mon profil public',
        onTap: () => context.push('/profile/public'),
      ),
      DonyListTile(
        icon: Icons.star_border_rounded,
        iconColor: cs.tertiary,
        iconBgColor: cs.tertiaryContainer,
        label: 'Mes avis reçus',
        showDivider: false,
        onTap: () => context.push('/profile/reviews'),
      ),
    ],
  ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  const SizedBox(height: DonySpacing.lg),

  // ─── FIDÉLITÉ ──────────────────────────────────────
  _SectionLabel(label: 'FIDÉLITÉ', cs: cs),
  DonyListSection(
    tiles: [
      DonyListTile(
        icon: Icons.people_outline_rounded,
        iconColor: cs.success,
        iconBgColor: cs.successLight,
        label: 'Parrainages',
        trailing: Text(
          '0 invité',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        showDivider: false,
        onTap: () => context.push('/profile/referral'),
      ),
    ],
  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  const SizedBox(height: DonySpacing.lg),

  // ─── SUPPORT ───────────────────────────────────────
  _SectionLabel(label: 'SUPPORT', cs: cs),
  DonyListSection(
    tiles: [
      DonyListTile(
        icon: Icons.gavel_rounded,
        iconColor: cs.error,
        iconBgColor: cs.errorContainer.withValues(alpha: 0.5),
        label: 'Mes litiges',
        onTap: () => context.push('/disputes'),
      ),
      DonyListTile(
        icon: Icons.support_agent_rounded,
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Contacter le support',
        onTap: () => context.push('/profile/help/contact'),
      ),
      DonyListTile(
        icon: Icons.help_outline_rounded,
        iconColor: cs.onSurfaceVariant,
        iconBgColor: cs.outline.withValues(alpha: 0.3),
        label: 'FAQ & aide',
        showDivider: false,
        onTap: () => context.push('/profile/help/faq'),
      ),
    ],
  ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
] else ...[
```

- [ ] **Vérifier les tests**

```bash
flutter test test/features/profile/presentation/profile_screen_test.dart
```

Expected : tous les tests du groupe `Section voyageur` passent, tests sender toujours verts.

---

## Task 5 : Enrichir le collapsed AppBar title

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Localiser le `title:` du SliverAppBar** (autour de la ligne 155) :

```dart
title: Text(
  displayName,
  style: tt.titleMedium!.copyWith(
    color: titleColor,
    fontWeight: FontWeight.w700,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

- [ ] **Remplacer par la Row enrichie** :

```dart
title: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Opacity(
      opacity: progress,
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isTraveler ? DonyColors.warning : cs.surface,
            width: 1.5,
          ),
        ),
        child: DonyAvatar(
          name: displayName,
          size: DonyAvatarSize.sm,
          verified: false,
          pro: false,
        ),
      ),
    ),
    const SizedBox(width: DonySpacing.sm),
    Flexible(
      child: Text(
        displayName,
        style: tt.titleSmall!.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    if (isKycVerified) ...[
      const SizedBox(width: DonySpacing.xs),
      Opacity(
        opacity: progress,
        child: Icon(
          Icons.verified_rounded,
          size: 13,
          color: isProAccount
              ? DonyColors.kycBadgeGold
              : DonyColors.kycBadgeBlue,
        ),
      ),
    ],
  ],
),
```

- [ ] **Vérifier que les tests existants passent toujours** (no-regression) :

```bash
flutter test test/features/profile/presentation/profile_screen_test.dart
```

Expected : tous les tests PASS.

---

## Task 6 : Passer `onSettingsTap` à ProfileHeader depuis profile_screen.dart

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Localiser l'appel à `ProfileHeader`** dans `flexibleSpace:` (autour de la ligne 166) et ajouter le paramètre après `onRoleSwitch:` :

```dart
ProfileHeader(
  displayName: displayName,
  activeRole: activeRole,
  isTraveler: isTraveler,
  isSender: isSender,
  isKycVerified: isKycVerified,
  isProAccount: isProAccount,
  totalTrips: user?.totalTrips ?? 0,
  totalShipments: user?.totalShipments ?? 0,
  isLoadingStats: bidState is BidLoading ||
      announcementState is AnnouncementLoading,
  onRoleSwitch: (isTraveler && isSender)
      ? (role) {
          if (role == ActiveRole.traveler) {
            context.read<ActiveRoleCubit>().switchToTraveler();
          } else {
            context.read<ActiveRoleCubit>().switchToSender();
          }
          context.go('/home');
        }
      : null,
  onSettingsTap: () => context.push('/settings'),  // ← ajouter
),
```

- [ ] **Vérifier que `flutter analyze` ne remonte aucune erreur**

```bash
flutter analyze lib/features/profile/
```

Expected : `No issues found!`

- [ ] **Lancer tous les tests profile**

```bash
flutter test test/features/profile/
```

Expected : tous les tests PASS.

---

## Task 7 : Couverture, vérification finale et commit

- [ ] **Lancer la suite complète**

```bash
flutter test --coverage
```

Expected : tous les tests passent, 0 rouge.

- [ ] **Vérifier la couverture des fichiers modifiés**

```bash
lcov --summary coverage/lcov.info 2>/dev/null | grep -E "lines|functions" || \
grep -E "profile_screen|profile_header" coverage/lcov.info | grep "^DA:" | \
awk -F',' '{hit+=$2; total++} END {printf "Coverage: %.1f%% (%d/%d lines)\n", hit/total*100, hit, total}'
```

Expected : couverture globale ≥ 90 %.

- [ ] **Commit final**

```bash
git add lib/features/profile/presentation/profile_screen.dart \
        lib/features/profile/presentation/widgets/profile_header.dart \
        test/features/profile/presentation/profile_screen_test.dart \
        test/features/profile/presentation/profile_header_test.dart
git commit -m "$(cat <<'EOF'
feat(profile): restructurer section voyageur + settings icon + collapsed title enrichi

- Section traveler : 6 sections (MON ACTIVITÉ / REVENUS & PAIEMENTS /
  COMPTE PRO / IDENTITÉ & CONFIANCE / FIDÉLITÉ / SUPPORT)
- Renommage "Demandes d'envoi à transporter" → "Colis sur mes trajets"
- Ajout : Mon profil public, Mes avis reçus, section SUPPORT complète
- ProfileHeader : icône settings en haut à droite (onSettingsTap)
- SliverAppBar collapsed title : avatar + nom + badge KYC doré
- No-regression : section sender et header expanded inchangés

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
