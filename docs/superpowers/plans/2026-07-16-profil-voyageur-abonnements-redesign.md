# Redesign profil voyageur + Mes abonnements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigner l'écran profil voyageur (`TravelerProfileHubScreen`) et l'écran Mes abonnements (`MesAbonnementsScreen`) suivant la direction "hero immersif + boarding pass" validée en brainstorming, sans changer aucun comportement métier ni aucune donnée.

**Architecture:** Refonte 100% présentation. Trois blocs indépendants : (1) la card trajet devient une "boarding pass" (barre dégradée + séparateur pointillé), (2) le header du profil devient un hero nuit immersif avec stats en pills flottantes, (3) la section "Ont publié récemment" de Mes abonnements devient une rangée horizontale de "stories" à anneau dégradé. Aucun changement de BLoC/state/modèle.

**Tech Stack:** Flutter/Dart, flutter_bloc (inchangé), design system `lib/core/design/` (tokens + `DonyCard`/`DonyAvatar`/`DonyButton` existants), `CustomPainter` pour le séparateur pointillé (aucune nouvelle dépendance pub).

## Global Constraints

- Aucun changement de `SubscriptionsBloc`, `TravelerHubBloc`, `ProfilePublicBloc`, ni de leurs events/states/modèles (`SubscriptionItem`, `ProfilePublicModel`, `TravelerAnnouncement`).
- Toutes les couleurs sauf le fond du hero (choix de marque fixe, non theme-aware) passent par `Theme.of(context).colorScheme` — jamais de `Color(0xFF...)` hardcodé ailleurs (`lib/core/design/CLAUDE.md`).
- Espacements/rayons via `DonySpacing`/`DonyRadius` — jamais de valeur en dur.
- Aucune régression sur les tests existants : `test/features/subscriptions/traveler_profile_hub_screen_test.dart` (17 tests), `test/features/subscriptions/traveler_announcement_card_test.dart` (7 tests), `test/features/subscriptions/mes_abonnements_screen_test.dart` (8 tests) — seul le test `hasNew` de `mes_abonnements_screen_test.dart` est explicitement mis à jour (Task 3), tous les autres doivent rester verts sans modification.
- Le bouton "Réserver" de la card trajet reste **toujours actif** (aucune désactivation basée sur `availableKg`, comportement actuel vérifié — voir spec section 3).
- Aucun nouveau package dans `pubspec.yaml`.
- Couverture ≥ 90 % sur les fichiers modifiés (`flutter test --coverage`).

---

### Task 1: `BoardingPassTripCard` — accent dégradé + séparateur pointillé sur `TravelerAnnouncementCard`

**Files:**
- Modify: `lib/features/subscriptions/presentation/widgets/traveler_announcement_card.dart`
- Test: `test/features/subscriptions/traveler_announcement_card_test.dart`

**Interfaces:**
- Consumes: rien de nouveau — `TravelerAnnouncement` (déjà défini dans `lib/features/subscriptions/data/subscriptions_repository.dart`, champs `departureCity`, `arrivalCity`, `departureDate`, `pricePerKg`, `availableKg`, `status`).
- Produces: `TravelerAnnouncementCard` garde exactement la même API (`announcement`, `onReserve`) — aucun changement de signature, seul le rendu interne change. Ajoute un widget privé `_DashedDivider` (interne au fichier, non exporté).

- [ ] **Step 1: Test rouge — état "Complet" quand `availableKg <= 0`**

Ajouter dans `test/features/subscriptions/traveler_announcement_card_test.dart`, juste avant le test `'pas de débordement sur 320px de large'` (avant la ligne `testWidgets('pas de débordement sur 320px de large', ...`) :

```dart
  testWidgets('availableKg=0 → affiche "Complet" au lieu de "X kg dispo"', (tester) async {
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(availableKg: 0),
      onReserve: () {},
    )));
    expect(find.text('Complet'), findsOneWidget);
    expect(find.textContaining('kg dispo'), findsNothing);
  });

```

- [ ] **Step 2: Vérifier l'échec**

```bash
flutter test test/features/subscriptions/traveler_announcement_card_test.dart > /tmp/dony-redesign-t1-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t1-red.log
tail -20 /tmp/dony-redesign-t1-red.log
```
Expected: FAIL — `find.text('Complet')` trouve 0 widget (le code actuel affiche toujours `'0 kg dispo'`).

- [ ] **Step 3: Réécrire `traveler_announcement_card.dart`**

Remplacer le contenu entier du fichier par :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TravelerAnnouncementCard extends StatelessWidget {
  const TravelerAnnouncementCard({
    super.key,
    required this.announcement,
    required this.onReserve,
  });

  final TravelerAnnouncement announcement;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isFull = announcement.availableKg <= 0;

    return DonyCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre d'accent dégradée — signature visuelle "boarding pass"
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, DonyColors.accent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DonyRadius.card),
                  bottomLeft: Radius.circular(DonyRadius.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zone 1 — Route
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.departureCity,
                            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 1.5,
                                color: cs.primary.withValues(alpha: 0.3),
                              ),
                              const DonyEmoji.planeTakeoff(size: 16),
                              Container(
                                width: 28,
                                height: 1.5,
                                color: cs.primary.withValues(alpha: 0.3),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: cs.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            announcement.arrivalCity,
                            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: DonySpacing.base),
                    SizedBox(
                      height: 8,
                      child: CustomPaint(
                        painter: _DashedLinePainter(color: cs.outline),
                        size: const Size(double.infinity, 1),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.base),

                    // Zone 2 — Footer grille 2×2
                    Column(
                      children: [
                        // Ligne 1 : date (gauche) · kg dispo / Complet (droite)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DonyIcon(
                                    'calendar',
                                    size: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: DonySpacing.xs),
                                  Flexible(
                                    child: Text(
                                      DateFormat('dd MMM yyyy', 'fr')
                                          .format(announcement.departureDate),
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              isFull
                                  ? 'Complet'
                                  : '${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                              style: tt.bodySmall?.copyWith(
                                color: isFull ? cs.error : cs.onSurfaceVariant,
                                fontWeight: isFull ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: DonySpacing.sm),

                        // Ligne 2 : prix (gauche) · bouton Réserver (droite)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${formatKgPrice(netToSenderPrice(announcement.pricePerKg))} €',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.titleLarge?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: DonySpacing.xxs),
                                  Text(
                                    '/kg',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: onReserve,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.base,
                                  vertical: DonySpacing.sm,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                                ),
                                minimumSize: const Size(0, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Réserver'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Séparateur pointillé horizontal — signature visuelle "boarding pass".
/// Pas de nouvelle dépendance pub : simple CustomPainter.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
```

Note : `CustomPaint(size: const Size(double.infinity, 1))` à l'intérieur d'un `SizedBox(height: 8)` — le `CustomPaint` reçoit une contrainte de largeur infinie au sein d'un parent borné (`Column` → largeur de l'écran), Flutter résout `double.infinity` en la largeur disponible du parent borné ; le `SizedBox(height: 8)` fixe la hauteur du peintre indépendamment du `size` passé à `CustomPaint` (qui ne sert qu'à indiquer l'intention, la vraie taille de rendu vient des contraintes du parent).

- [ ] **Step 4: Vérifier que le nouveau test passe et qu'aucun test existant ne casse**

```bash
flutter test test/features/subscriptions/traveler_announcement_card_test.dart > /tmp/dony-redesign-t1-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t1-green.log
tail -20 /tmp/dony-redesign-t1-green.log
```
Expected: `00:0X +8: All tests passed!` (7 tests existants + 1 nouveau), EXIT_CODE=0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/subscriptions/presentation/widgets/traveler_announcement_card.dart test/features/subscriptions/traveler_announcement_card_test.dart
git commit -m "feat(subscriptions): boarding pass — barre dégradée + séparateur pointillé sur la card trajet"
```

---

### Task 2: Hero immersif + stat-pills flottantes sur `TravelerProfileHubScreen`

**Files:**
- Modify: `lib/features/subscriptions/presentation/traveler_profile_hub_screen.dart`
- Test: `test/features/subscriptions/traveler_profile_hub_screen_test.dart` (aucune modification attendue — vérifier en Step 3 que les 17 tests existants restent verts tels quels)

**Interfaces:**
- Consumes : `ProfilePublicModel` (`displayName`, `avatarUrl`, `kycVerified`, `isProAccount`, `isKiloPro`, `averageRating`, `completedBidsCount`, `responseDelayHours`) — inchangé, déjà défini dans `lib/features/profile/data/models/profile_public_model.dart`. `DonyColors.proBg1/proBg2/proBg3` (déjà définis dans `lib/core/design/tokens/color_tokens.dart:117-119`).
- Produces : aucune nouvelle interface publique — widgets privés `_LoadedProfileHeader`, `_ProfileBadge`, `_StatCard`, `_StatsAndTabBar` gardent leurs noms et paramètres actuels, seul leur rendu interne change.

- [ ] **Step 1: Confirmer que les tests existants passent avant modification (baseline)**

```bash
flutter test test/features/subscriptions/traveler_profile_hub_screen_test.dart > /tmp/dony-redesign-t2-baseline.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t2-baseline.log
tail -10 /tmp/dony-redesign-t2-baseline.log
```
Expected: `00:0X +17: All tests passed!`, EXIT_CODE=0. Ce test ne porte pas sur du nouveau code (pas de TDD rouge ici : le redesign ne change ni texte ni logique, seulement le style — la garantie de non-régression est justement que ces 17 tests restent verts après modification sans être touchés).

- [ ] **Step 2: Réécrire `_LoadedProfileHeader`, `_ProfileBadge`, `_StatCard`, `_StatsAndTabBar` dans `traveler_profile_hub_screen.dart`**

Remplacer le bloc allant de `class _LoadedProfileHeader extends StatelessWidget {` (ligne 129 du fichier actuel) jusqu'à la fin de `class _StatsAndTabBar extends StatelessWidget implements PreferredSizeWidget {` (ligne 427, juste avant `// ─── Subscription Bar`) par :

```dart
class _LoadedProfileHeader extends StatelessWidget {
  const _LoadedProfileHeader({required this.profile});

  final ProfilePublicModel profile;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Stack(
      children: [
        // Fond nuit fixe (choix de marque assumé, non theme-aware — voir spec
        // section "Dark mode" : ce hero reste identique en light/dark mode).
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.9),
                radius: 1.4,
                colors: [
                  DonyColors.proBg3,
                  DonyColors.proBg1,
                  DonyColors.proBg2,
                ],
              ),
            ),
          ),
        ),
        // Halo diffus terracotta, haut-droit
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.7),
                radius: 0.9,
                colors: [
                  DonyColors.accent.withValues(alpha: 0.30),
                  DonyColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.base,
              0,
              DonySpacing.base,
              _StatsAndTabBar.height + DonySpacing.md,
            ),
            child: Row(
              children: [
                // Avatar avec bordure blanche et ombre accent
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: DonyColors.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DonyAvatar(
                    name: profile.displayName,
                    imageUrl: profile.avatarUrl,
                    size: DonyAvatarSize.lg,
                    verified: profile.kycVerified,
                    pro: profile.isProAccount,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                // Infos à droite
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.displayName,
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      Wrap(
                        spacing: DonySpacing.xs,
                        runSpacing: DonySpacing.xs,
                        children: [
                          if (profile.isProAccount)
                            _ProfileBadge(
                              lucideIcon: 'star',
                              label: 'Compte PRO',
                              iconColor: DonyColors.kycBadgeGold,
                            ),
                          if (profile.isKiloPro)
                            _ProfileBadge(
                              iconAsset: 'package',
                              label: 'Kilo Pro',
                              iconColor: DonyColors.kycBadgeGold,
                            ),
                          if (profile.kycVerified)
                            _ProfileBadge(
                              lucideIcon: 'badge-check',
                              label: 'Identité vérifiée',
                              iconColor: DonyColors.kycBadgeBlue,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    this.lucideIcon,
    this.iconAsset,
    required this.label,
    required this.iconColor,
  });

  final String? lucideIcon;
  final String? iconAsset;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconAsset != null
              ? const DonyEmoji.parcel(size: 11)
              : DonyIcon(lucideIcon!, size: 11, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    this.lucideIcon,
    this.iconAsset,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final String? lucideIcon;
  final String? iconAsset;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconAsset != null
              ? const DonyEmoji.parcel(size: 14)
              : DonyIcon(lucideIcon!, size: 14, color: iconColor),
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatsAndTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatsAndTabBar({required this.controller});

  final TabController controller;

  // 96px (stats) + 18px (marge pour l'effet "flottant") + 48px (TabBar) = 162px
  static const double height = 162;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Stats row (114px = 96 + 18 de marge pour le Transform) ────────
          BlocBuilder<ProfilePublicBloc, ProfilePublicState>(
            buildWhen: (p, c) =>
                c is ProfilePublicLoaded ||
                c is ProfilePublicLoading ||
                c is ProfilePublicInitial,
            builder: (context, state) {
              if (state is! ProfilePublicLoaded) {
                return SizedBox(
                  height: 114,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              final profile = state.profile;
              return SizedBox(
                height: 114,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base,
                    DonySpacing.sm + 18,
                    DonySpacing.base,
                    DonySpacing.sm,
                  ),
                  child: Transform.translate(
                    // Fait "flotter" les pills sur le bas du hero immersif.
                    offset: const Offset(0, -18),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            lucideIcon: 'star',
                            iconColor: cs.warning,
                            value: profile.averageRating > 0
                                ? profile.averageRating.toStringAsFixed(1)
                                : '–',
                            label: 'Note',
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: _StatCard(
                            iconAsset: 'package',
                            iconColor: cs.primary,
                            value: '${profile.completedBidsCount}',
                            label: 'Livraisons',
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: _StatCard(
                            lucideIcon: 'timer',
                            iconColor: cs.success,
                            value: profile.responseDelayHours != null
                                ? '<${profile.responseDelayHours}h'
                                : '–',
                            label: 'Réponse',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // ── TabBar (48px) ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            child: TabBar(
              controller: controller,
              tabs: const [
                Tab(text: 'Trajets'),
                Tab(text: 'Avis'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Notes d'implémentation :
- `Transform.translate(offset: Offset(0, -18))` déplace uniquement le rendu visuel des pills, pas leur zone de hit-test dans l'arbre — Flutter applique la même transformation à la géométrie de hit-testing, donc les `tester.tap`/`find` existants restent valides.
- Le padding-top du `Container` est augmenté de 18px (`DonySpacing.sm + 18`) pour compenser le `Transform.translate` négatif et garder les pills à l'intérieur de la `SizedBox(height: 114)` sans clipper leur ombre portée en haut.
- `_LoadedProfileHeader` n'utilise plus `cs`/`Theme.of(context).colorScheme` pour son fond (fond fixe, non theme-aware, par choix — voir spec) : seul `tt` (textTheme) est encore utilisé pour la typographie, la couleur du texte est mise en dur en blanc pour ce composant précis uniquement.
- Le `import 'package:dony/core/widgets/dony_emoji.dart';` et `import 'package:dony/core/widgets/dony_icon.dart';` déjà présents en tête de fichier restent inchangés et suffisent (aucun nouvel import requis, `Colors` vient de `package:flutter/material.dart` déjà importé).

- [ ] **Step 3: Vérifier que les 17 tests existants restent verts sans modification**

```bash
flutter test test/features/subscriptions/traveler_profile_hub_screen_test.dart > /tmp/dony-redesign-t2-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t2-green.log
tail -20 /tmp/dony-redesign-t2-green.log
```
Expected: `00:0X +17: All tests passed!`, EXIT_CODE=0. **Si un test échoue**, ne pas l'affaiblir : lire précisément le finder en échec et ajuster le widget pour qu'il continue de produire le même texte/widget attendu (le contrat de ce redesign est zéro changement de texte/comportement).

- [ ] **Step 4: Commit**

```bash
git add lib/features/subscriptions/presentation/traveler_profile_hub_screen.dart
git commit -m "feat(subscriptions): hero immersif nuit + stat-pills flottantes sur le profil voyageur"
```

---

### Task 3: `_SubscriptionStoryRow` — rangée "stories" pour les nouveautés sur `MesAbonnementsScreen`

**Files:**
- Modify: `lib/features/subscriptions/presentation/mes_abonnements_screen.dart`
- Test: `test/features/subscriptions/mes_abonnements_screen_test.dart`

**Interfaces:**
- Consumes: `SubscriptionItem` (`travelerId`, `travelerName`, `hasNew`, `pushEnabled`, déjà définis dans `lib/features/subscriptions/data/subscriptions_repository.dart`) — inchangé.
- Produces: nouveau widget privé `_SubscriptionStoryRow({required List<SubscriptionItem> items})` et `_StoryAvatar({required SubscriptionItem item})`, tous deux internes au fichier (non exportés, pas de réutilisation prévue ailleurs pour l'instant).

- [ ] **Step 1: Test rouge — la rangée story remplace la liste "NOUVEAU", avec un a11y label**

Dans `test/features/subscriptions/mes_abonnements_screen_test.dart`, remplacer le test existant (lignes 181-204, de `testWidgets(` à la fermeture `);` juste avant le `}` final de `main()`) par :

```dart
  testWidgets(
    'item hasNew:true + lastAnnouncement → section "ONT PUBLIÉ RÉCEMMENT" + story avatar accessible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => bloc.state).thenReturn(
        SubscriptionsState(
          status: SubscriptionsStatus.success,
          items: [_itemWithNew('Ibou')],
        ),
      );
      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      // The section label is uppercased
      expect(
        find.textContaining('ONT PUBLIÉ RÉCEMMENT', findRichText: true),
        findsOneWidget,
      );
      // La story-row remplace le badge texte "NOUVEAU" par un Semantics
      // label sur l'avatar (a11y — cf. lib/core/design/CLAUDE.md règle
      // "Semantics sur icônes sans label").
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics &&
              w.properties.label == 'Nouveau trajet publié par Ibou',
        ),
        findsOneWidget,
      );
      expect(find.text('Ibou'), findsOneWidget);
    },
  );
```

- [ ] **Step 2: Vérifier l'échec**

```bash
flutter test test/features/subscriptions/mes_abonnements_screen_test.dart > /tmp/dony-redesign-t3-red.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t3-red.log
tail -20 /tmp/dony-redesign-t3-red.log
```
Expected: FAIL sur l'assertion `Semantics` (le code actuel n'a pas de tel widget) — le `find.text('Ibou')` et la section label peuvent déjà passer (c'est attendu, seule la nouvelle assertion doit échouer).

- [ ] **Step 3: Implémenter `_SubscriptionStoryRow`**

Dans `lib/features/subscriptions/presentation/mes_abonnements_screen.dart`, remplacer :

```dart
                    if (recent.isNotEmpty) ...[
                      const _SectionLabel('🆕 Ont publié récemment'),
                      ...recent.map((i) => _slidable(context, i)),
                    ],
```

par :

```dart
                    if (recent.isNotEmpty) ...[
                      const _SectionLabel('🆕 Ont publié récemment'),
                      _SubscriptionStoryRow(items: recent),
                    ],
```

Puis ajouter ces deux nouvelles classes juste après la classe `_SectionLabel` (en fin de fichier, avant le dernier `}`) :

```dart
class _SubscriptionStoryRow extends StatelessWidget {
  const _SubscriptionStoryRow({required this.items});

  final List<SubscriptionItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: DonySpacing.md),
        itemBuilder: (context, index) => _StoryAvatar(item: items[index]),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      label: 'Nouveau trajet publié par ${item.travelerName}',
      child: GestureDetector(
        onTap: () => context.push('/travelers/${item.travelerId}'),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [cs.primary, DonyColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: DonyAvatar(name: item.travelerName, size: DonyAvatarSize.md),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                item.travelerName,
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`context.push` (go_router) et `DonyColors`/`DonyAvatar`/`DonySpacing` (design_system.dart) sont déjà importés en tête du fichier — aucun nouvel import requis.

- [ ] **Step 4: Vérifier que le nouveau test passe et que les 7 autres tests du fichier restent verts**

```bash
flutter test test/features/subscriptions/mes_abonnements_screen_test.dart > /tmp/dony-redesign-t3-green.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t3-green.log
tail -20 /tmp/dony-redesign-t3-green.log
```
Expected: `00:0X +8: All tests passed!`, EXIT_CODE=0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/subscriptions/presentation/mes_abonnements_screen.dart test/features/subscriptions/mes_abonnements_screen_test.dart
git commit -m "feat(subscriptions): rangée stories (anneau dégradé) pour les nouveautés dans Mes abonnements"
```

---

### Task 4: Régression complète, couverture, PR

**Files:**
- Aucun fichier de code — vérification et publication uniquement.

**Interfaces:**
- Consumes: l'ensemble des changements des Tasks 1-3.
- Produces: rien — tâche de clôture.

- [ ] **Step 1: `flutter analyze`**

```bash
flutter analyze > /tmp/dony-redesign-t4-analyze.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t4-analyze.log
tail -30 /tmp/dony-redesign-t4-analyze.log
```
Expected: 0 nouvelle erreur/warning sur les 3 fichiers modifiés (`traveler_announcement_card.dart`, `traveler_profile_hub_screen.dart`, `mes_abonnements_screen.dart`) par rapport à la baseline `main` — des infos de lint pré-existantes ailleurs dans le repo peuvent subsister (non liées à ce changement).

- [ ] **Step 2: Suite Flutter complète**

```bash
flutter test > /tmp/dony-redesign-t4-full.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t4-full.log
tail -15 /tmp/dony-redesign-t4-full.log
```
Expected: `All tests passed!`, EXIT_CODE=0, 0 nouvel échec vs baseline `main`.

- [ ] **Step 3: Couverture sur les fichiers modifiés**

```bash
flutter test --coverage test/features/subscriptions > /tmp/dony-redesign-t4-cov.log 2>&1; echo "EXIT_CODE=$?" >> /tmp/dony-redesign-t4-cov.log
tail -10 /tmp/dony-redesign-t4-cov.log
```
Vérifier ≥ 90 % sur `traveler_announcement_card.dart`, `traveler_profile_hub_screen.dart`, `mes_abonnements_screen.dart` via `coverage/lcov.info` (`genhtml coverage/lcov.info -o coverage/html` si besoin d'un rapport visuel).

- [ ] **Step 4: Commit + push + PR draft**

```bash
git add -A && git status --short   # vérifier : uniquement les fichiers de cette feature
git push -u origin feature/profil-voyageur-redesign
gh pr create --draft --title "feat(subscriptions): redesign profil voyageur + Mes abonnements (hero immersif + boarding pass)" --body "Redesign 100% présentation, zéro changement de BLoC/state/modèle. Direction validée via 3 rounds de mockups (compagnon visuel brainstorming). Spec : docs/superpowers/specs/2026-07-16-profil-voyageur-abonnements-redesign-design.md.

- Card trajet → boarding pass (barre dégradée + séparateur pointillé + état Complet cosmétique)
- Header profil voyageur → hero nuit immersif + stat-pills flottantes
- Mes abonnements → rangée stories (anneau dégradé) pour les nouveautés, remplace le badge NOUVEAU"
```
