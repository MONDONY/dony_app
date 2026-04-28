import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ── Static corridor data ─────────────────────────────────────────────────────

typedef _Corridor = ({String code, int travelers, bool isHot});

const List<_Corridor> _corridors = [
  (code: 'PAR → DKR', travelers: 23, isHot: true),
  (code: 'LYS → ABJ', travelers: 11, isHot: false),
  (code: 'MRS → BKO', travelers: 7, isHot: false),
  (code: 'PAR → DLA', travelers: 14, isHot: false),
];

// ── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated
            ? authState.user
            : authState is AuthProfileUpdated
                ? authState.user
                : null;

        final isTraveler = user?.roles.contains('ROLE_TRAVELER') ?? false;

        if (isTraveler) {
          return _TravelerView(displayName: user?.displayName ?? 'Voyageur');
        }
        return _SenderView(
          firstName: user?.firstName ?? user?.displayName ?? 'vous',
          displayName: user?.displayName ?? 'vous',
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SENDER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _SenderView extends StatelessWidget {
  const _SenderView({required this.firstName, required this.displayName});

  final String firstName;
  final String displayName;

  String get _initials {
    if (displayName.isEmpty) {
      return '?';
    }
    final parts = displayName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: DonyColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Container(
              color: DonyColors.white,
              padding: EdgeInsets.fromLTRB(DonySpacing.lg, topPad + DonySpacing.base, DonySpacing.lg, DonySpacing.base),
              child: Row(
                children: [
                  // Logo
                  Text(
                    'dony',
                    style: DonyTypography.caveat(fontSize: 26, color: DonyColors.ink900),
                  ),
                  Text(
                    '.',
                    style: DonyTypography.caveat(fontSize: 26, color: DonyColors.green400),
                  ),
                  const Spacer(),
                  // Bell icon
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: DonyColors.ink900),
                    onPressed: () => context.push('/messages'),
                    tooltip: 'Notifications',
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  // Avatar chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
                    decoration: BoxDecoration(
                      color: DonyColors.green50,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                      border: Border.all(color: DonyColors.green200),
                    ),
                    child: Text(
                      _initials,
                      style: tt.labelMedium!.copyWith(
                        color: DonyColors.green400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 280.ms),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting ──────────────────────────────────────────────
                  Text(
                    'Bonjour $firstName,',
                    style: tt.bodyMedium!.copyWith(color: DonyColors.grey400),
                  ),
                  const SizedBox(height: DonySpacing.xs),

                  // ── Headline ──────────────────────────────────────────────
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'on envoie quoi ',
                          style: tt.headlineLarge!.copyWith(
                            color: DonyColors.ink900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Text(
                            "aujourd'hui",
                            style: DonyTypography.caveat(
                              fontSize: 24,
                              color: DonyColors.green400,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: ' ?',
                          style: tt.headlineLarge!.copyWith(
                            color: DonyColors.ink900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 60.ms, duration: 300.ms),

                  const SizedBox(height: DonySpacing.xl),

                  // ── Search form card ───────────────────────────────────────
                  const _SearchFormCard().animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),

                  const SizedBox(height: DonySpacing.base),

                  // ── CTA button ────────────────────────────────────────────
                  DonyButton(
                    label: 'Trouver un voyageur',
                    icon: Icons.search,
                    onPressed: () => context.push('/search'),
                  ).animate().fadeIn(delay: 140.ms),

                  const SizedBox(height: DonySpacing.xxl),

                  // ── Section header ────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'CORRIDORS POPULAIRES',
                        style: tt.labelMedium!.copyWith(
                          color: DonyColors.grey400,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'cette semaine',
                        style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
                      ),
                    ],
                  ),

                  const SizedBox(height: DonySpacing.md),

                  // ── Corridors grid ────────────────────────────────────────
                  const _CorridorsGrid().animate().fadeIn(delay: 180.ms),

                  const SizedBox(height: DonySpacing.xl),

                  // ── Garantie Dony card ─────────────────────────────────────
                  const _GarantieCard().animate().fadeIn(delay: 220.ms),

                  const SizedBox(height: DonySpacing.huge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search form card ─────────────────────────────────────────────────────────

class _SearchFormCard extends StatelessWidget {
  const _SearchFormCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Column(
        children: [
          // Row 1: DÉPART
          Padding(
            padding: const EdgeInsets.fromLTRB(DonySpacing.base, DonySpacing.base, DonySpacing.base, DonySpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DÉPART',
                        style: tt.labelSmall!.copyWith(color: DonyColors.grey400),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        'Paris CDG',
                        style: tt.titleMedium!.copyWith(
                          color: DonyColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert_rounded, color: DonyColors.grey400),
                  onPressed: () {},
                  tooltip: 'Inverser',
                ),
              ],
            ),
          ),
          // Row 2: ARRIVÉE
          Padding(
            padding: const EdgeInsets.fromLTRB(DonySpacing.base, 0, DonySpacing.base, DonySpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARRIVÉE',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: DonyColors.grey400),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        'Dakar DKR',
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: DonyColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Modifier',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: DonyColors.green400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DonyColors.grey200),
          // Row 3: Date + Weight
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 12, color: DonyColors.grey400),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'Cette semaine',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: DonyColors.ink900),
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Jusqu\'à ',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: DonyColors.ink900),
                      ),
                      TextSpan(
                        text: '15',
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: DonyColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' kg',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: DonyColors.ink900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corridors grid ────────────────────────────────────────────────────────────

class _CorridorsGrid extends StatelessWidget {
  const _CorridorsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DonySpacing.sm,
        mainAxisSpacing: DonySpacing.sm,
        childAspectRatio: 2.2,
      ),
      itemCount: _corridors.length,
      itemBuilder: (context, i) {
        final corridor = _corridors[i];
        return _CorridorChip(corridor: corridor);
      },
    );
  }
}

class _CorridorChip extends StatelessWidget {
  const _CorridorChip({required this.corridor});

  final _Corridor corridor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    corridor.code,
                    style: tt.titleSmall!.copyWith(
                      color: DonyColors.ink900,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (corridor.isHot) ...[
                  const SizedBox(width: DonySpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs, vertical: DonySpacing.xxs),
                    decoration: BoxDecoration(
                      color: DonyColors.errorLight,
                      borderRadius: BorderRadius.circular(DonyRadius.xs),
                    ),
                    child: Text(
                      'HOT',
                      style: tt.labelSmall!.copyWith(
                        color: DonyColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DonySpacing.xxs),
            Text(
              '${corridor.travelers} voyageurs',
              style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Garantie Dony card ────────────────────────────────────────────────────────

class _GarantieCard extends StatelessWidget {
  const _GarantieCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.grey50,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.green200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: DonyColors.green400, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garantie Dony',
                  style: tt.titleMedium!.copyWith(
                    color: DonyColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  'Remboursé jusqu\'à 200 € si le colis n\'arrive pas.',
                  style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TRAVELER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _TravelerView extends StatelessWidget {
  const _TravelerView({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: DonyColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (notification bell only) ──────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(DonySpacing.lg, topPad + DonySpacing.sm, DonySpacing.lg, 0),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: DonyColors.ink900),
                    onPressed: () => context.push('/messages'),
                    tooltip: 'Notifications',
                  ),
                ],
              ).animate().fadeIn(duration: 280.ms),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.sm, DonySpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile row ──────────────────────────────────────────
                  Row(
                    children: [
                      DonyAvatar(
                        name: displayName,
                        size: DonyAvatarSize.md,
                        verified: true,
                      ),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: tt.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: DonySpacing.xxs),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: DonyColors.warning, size: 14),
                                const SizedBox(width: DonySpacing.xxs),
                                Text(
                                  '4.9',
                                  style: tt.bodySmall!.copyWith(
                                    color: DonyColors.ink900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
                                  decoration: BoxDecoration(
                                    color: DonyColors.green50,
                                    borderRadius: BorderRadius.circular(DonyRadius.full),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 11, color: DonyColors.green400),
                                      const SizedBox(width: DonySpacing.xxs),
                                      Text(
                                        'VTC vérifié',
                                        style: tt.labelSmall!.copyWith(color: DonyColors.green400),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: DonySpacing.xl),

                  // ── Dark stats card ──────────────────────────────────────
                  const _StatsCard().animate().fadeIn(delay: 60.ms).slideY(begin: 0.03, curve: Curves.easeOutCubic),

                  const SizedBox(height: DonySpacing.xxl),

                  // ── Active trips section ──────────────────────────────────
                  Text(
                    'MES TRAJETS ACTIFS',
                    style: tt.labelMedium!.copyWith(
                      color: DonyColors.grey400,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: DonySpacing.md),

                  // ── Trip card ────────────────────────────────────────────
                  const _ActiveTripCard().animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: DonySpacing.xl),

                  // ── Publish CTA ──────────────────────────────────────────
                  DonyButton(
                    label: 'Publier un trajet',
                    icon: Icons.send_rounded,
                    onPressed: () => context.push('/announcements/create'),
                  ).animate().fadeIn(delay: 140.ms),

                  const SizedBox(height: DonySpacing.xl),

                  // ── Payout footer ────────────────────────────────────────
                  const _PayoutFooter().animate().fadeIn(delay: 180.ms),

                  const SizedBox(height: DonySpacing.huge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats card (dark greenDark background) ────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: DonyColors.greenDark,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CE MOIS-CI',
            style: tt.labelSmall!.copyWith(
              color: DonyColors.white.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            '248,50 €',
            style: tt.displaySmall!.copyWith(color: DonyColors.white),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            '4 colis · paiement Wed',
            style: tt.bodySmall!.copyWith(
              color: DonyColors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: DonySpacing.base),
          const Row(
            children: [
              _StatPill(label: 'Trajets', value: '8'),
              SizedBox(width: DonySpacing.sm),
              _StatPill(label: 'Portés', value: '62kg'),
              SizedBox(width: DonySpacing.sm),
              _StatPill(label: 'Complétés', value: '100%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.sm),
      decoration: BoxDecoration(
        color: DonyColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleSmall!.copyWith(color: DonyColors.white, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: tt.labelSmall!.copyWith(color: DonyColors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ── Active trip card ──────────────────────────────────────────────────────────

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    const double reserved = 5;
    const double total = 15;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CDG → DSS',
                style: tt.titleLarge!.copyWith(
                  color: DonyColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
                decoration: BoxDecoration(
                  color: DonyColors.successLight,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  'OUVERT',
                  style: tt.labelSmall!.copyWith(
                    color: DonyColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Ven 18 · 14h05 · 5 kg réservés',
            style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
          ),
          const SizedBox(height: DonySpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: reserved / total,
              minHeight: 6,
              color: DonyColors.green400,
              backgroundColor: DonyColors.grey200,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${reserved.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} kg',
              style: tt.bodySmall!.copyWith(color: DonyColors.grey400),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payout footer row ─────────────────────────────────────────────────────────

class _PayoutFooter extends StatelessWidget {
  const _PayoutFooter();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(Icons.access_time_rounded, color: DonyColors.grey400, size: 16),
        const SizedBox(width: DonySpacing.xs),
        Text(
          'Prochain payout · mer. 23/04',
          style: tt.bodyMedium!.copyWith(color: DonyColors.ink900),
        ),
        const Spacer(),
        Text(
          '248,50 €',
          style: tt.titleMedium!.copyWith(
            color: DonyColors.green400,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
