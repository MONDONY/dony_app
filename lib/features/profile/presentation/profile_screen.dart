import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BidBloc>().add(BidMyListRequested());
    context.read<AnnouncementBloc>().add(AnnouncementListRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthAccountDeleted) {
          context.go('/auth/phone');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          UserModel? user;
          if (authState is AuthAuthenticated) {
            user = authState.user;
          }
          if (authState is AuthProfileUpdated) {
            user = authState.user;
          }
          final isTraveler = user?.isTraveler ?? false;
          final isSender = user?.isSender ?? false;
          final isKycVerified = user?.isKycVerified ?? false;
          final displayName = user?.displayName ?? 'Utilisateur';

          return BlocBuilder<BidBloc, BidState>(
            builder: (context, bidState) {
              return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                builder: (context, announcementState) {
                  // Bid stats (sender)
                  final bids = bidState is BidListLoaded ? bidState.bids : <BidModel>[];
                  final totalBids = bids.length;
                  final activeBids =
                      bids.where((b) => b.status == 'ACCEPTED').length;

                  // Announcement stats (traveler)
                  final announcements = announcementState is AnnouncementListLoaded
                      ? announcementState.announcements
                      : <AnnouncementModel>[];
                  // Trajets en cours ou à venir = ACTIVE + FULL
                  final upcomingAnnouncements = announcements
                      .where((a) => a.status == 'ACTIVE' || a.status == 'FULL')
                      .length;

                  return Scaffold(
                    appBar: DonyAppBar(
                      title: 'Mon profil',
                      showBackButton: false,
                    ),
                    body: RefreshIndicator(
                      color: cs.primary,
                      onRefresh: () async {
                        context.read<BidBloc>().add(BidMyListRequested());
                        context
                            .read<AnnouncementBloc>()
                            .add(AnnouncementListRequested());
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg, DonySpacing.xxl, DonySpacing.lg, DonySpacing.huge,
                        ),
                        child: Column(
                          children: [
                            // ── Avatar ─────────────────────────────────
                            DonyAvatar(
                              name: displayName,
                              size: DonyAvatarSize.xl,
                              verified: isKycVerified,
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .scale(
                                  begin: const Offset(0.85, 0.85),
                                  curve: Curves.easeOutBack,
                                ),
                            const SizedBox(height: DonySpacing.md),

                            // ── Nom / identifiant ───────────────────────
                            Text(
                              displayName,
                              style: tt.headlineMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 80.ms),
                            const SizedBox(height: DonySpacing.md),

                            // ── Badges ──────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isKycVerified) ...[
                                  const _Badge(
                                    icon: Icons.verified_rounded,
                                    label: 'Identité vérifiée',
                                    color: DonyColors.success,
                                  ),
                                  const SizedBox(width: DonySpacing.sm),
                                ],
                                if (isTraveler)
                                  _Badge(
                                    icon: Icons.flight_takeoff_rounded,
                                    label: 'Voyageur',
                                    color: cs.primary,
                                  ),
                                if (isTraveler && isSender)
                                  const SizedBox(width: DonySpacing.sm),
                                if (isSender)
                                  _Badge(
                                    icon: Icons.send_rounded,
                                    label: 'Expéditeur',
                                    color: cs.secondary,
                                  ),
                              ],
                            ).animate().fadeIn(delay: 120.ms),
                            const SizedBox(height: DonySpacing.xl),

                            // ── Stats ───────────────────────────────────
                            _StatsRow(
                              isTraveler: isTraveler,
                              totalBids: totalBids,
                              totalTrips: user?.totalTrips ?? 0,
                              isLoading: bidState is BidLoading ||
                                  announcementState is AnnouncementLoading,
                              cs: cs,
                              tt: tt,
                            ).animate().fadeIn(delay: 160.ms),
                            const SizedBox(height: DonySpacing.lg),

                            // ── Bannière complétion profil ───────────────
                            if (user != null && !user.isProfileComplete) ...[
                              _ProfileCompletionBanner(
                                user: user,
                                onTap: () => context.push('/profile/edit'),
                                cs: cs,
                                tt: tt,
                              ).animate().fadeIn(delay: 180.ms),
                              const SizedBox(height: DonySpacing.lg),
                            ],

                            // ── Menu principal ──────────────────────────
                            DonyListSection(
                              tiles: [
                                if (isTraveler)
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
                                if (isSender)
                                  DonyListTile(
                                    icon: Icons.inventory_2_outlined,
                                    iconColor: cs.secondary,
                                    iconBgColor: cs.secondaryContainer,
                                    label: 'Mes envois',
                                    trailing: activeBids > 0
                                        ? Text(
                                            '$activeBids en cours',
                                            style: tt.labelMedium?.copyWith(
                                              color: cs.secondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : null,
                                    onTap: () => context.push('/announcements'),
                                  ),
                                if (isTraveler)
                                  DonyListTile(
                                    icon: Icons.account_balance_wallet_rounded,
                                    iconColor: DonyColors.success,
                                    iconBgColor: DonyColors.successLight,
                                    label: 'Recevoir mes paiements',
                                    onTap: () =>
                                        context.push('/payments/onboarding'),
                                  ),
                                DonyListTile(
                                  icon: Icons.credit_card_outlined,
                                  iconColor: DonyColors.purple,
                                  iconBgColor: DonyColors.violetLight,
                                  label: 'Paiements & factures',
                                  onTap: () {},
                                ),
                                DonyListTile(
                                  icon: Icons.badge_outlined,
                                  iconColor: cs.primary,
                                  iconBgColor: cs.primaryContainer,
                                  label: 'Documents KYC',
                                  trailing: isKycVerified
                                      ? Text(
                                          'Vérifié',
                                          style: tt.labelMedium?.copyWith(
                                            color: DonyColors.success,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                  onTap: () => context.push('/kyc'),
                                ),
                                DonyListTile(
                                  icon: Icons.people_outline_rounded,
                                  iconColor: DonyColors.success,
                                  iconBgColor: DonyColors.successLight,
                                  label: 'Parrainages',
                                  trailing: Text(
                                    '0 invité',
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  showDivider: false,
                                  onTap: () {},
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideY(
                                    begin: 0.04,
                                    curve: Curves.easeOutCubic),
                            const SizedBox(height: DonySpacing.base),

                            // ── Menu settings ───────────────────────────
                            DonyListSection(
                              tiles: [
                                DonyListTile(
                                  icon: Icons.notifications_outlined,
                                  iconColor: DonyColors.warning,
                                  iconBgColor: DonyColors.warningLight,
                                  label: 'Notifications',
                                  onTap: () {},
                                ),
                                DonyListTile(
                                  icon: Icons.language_rounded,
                                  iconColor: cs.primary,
                                  iconBgColor: cs.primaryContainer,
                                  label: 'Langue',
                                  trailing: Text(
                                    'Français',
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  onTap: () {},
                                ),
                                DonyListTile(
                                  icon: Icons.lock_outline_rounded,
                                  iconColor: cs.onSurfaceVariant,
                                  iconBgColor: cs.outline.withValues(alpha: 0.3),
                                  label: 'Sécurité & confidentialité',
                                  onTap: () {},
                                ),
                                DonyListTile(
                                  icon: Icons.help_outline_rounded,
                                  iconColor: cs.onSurfaceVariant,
                                  iconBgColor: cs.outline.withValues(alpha: 0.3),
                                  label: 'Aide & support',
                                  showDivider: false,
                                  onTap: () {},
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 240.ms)
                                .slideY(
                                    begin: 0.04,
                                    curve: Curves.easeOutCubic),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Déconnexion ─────────────────────────────
                            DonyButton(
                              label: 'Se déconnecter',
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(const AuthLogoutRequested()),
                              variant: DonyButtonVariant.ghost,
                            ).animate().fadeIn(delay: 280.ms),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Footer ──────────────────────────────────
                            Text(
                              'dony v1.0.0 · Made with ❤️ in Paris',
                              style: tt.bodySmall?.copyWith(
                                color: cs.outline,
                              ),
                            ).animate().fadeIn(delay: 320.ms),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Profile completion banner ─────────────────────────────────────────────────

class _ProfileCompletionBanner extends StatelessWidget {
  const _ProfileCompletionBanner({
    required this.user,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final UserModel user;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final completed = user.profileCompletionSteps;
    const total = UserModel.profileTotalSteps;

    final missing = <String>[];
    if (!(user.firstName?.isNotEmpty ?? false) &&
        !(user.lastName?.isNotEmpty ?? false)) {
      missing.add('Votre nom');
    }
    if (user.birthDate == null) {
      missing.add('Date de naissance');
    }
    if (!(user.city?.isNotEmpty ?? false)) {
      missing.add("Lieu d'habitation");
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: DonyColors.warningLight,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: DonyColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: DonyColors.warning, size: 18),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil incomplet',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${(completed / total * 100).round()}% complété · Compléter maintenant',
                        style: tt.bodySmall?.copyWith(
                          color: DonyColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.xs),
              child: LinearProgressIndicator(
                value: completed / total,
                backgroundColor: cs.outline,
                valueColor: const AlwaysStoppedAnimation<Color>(DonyColors.warning),
                minHeight: 5,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.md),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: missing.map((m) => _MissingChip(label: m, tt: tt)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label, required this.tt});
  final String label;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DonyColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: Border.all(color: DonyColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_rounded, color: DonyColors.warning, size: 12),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: DonyColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.isTraveler,
    required this.totalBids,
    required this.totalTrips,
    required this.isLoading,
    required this.cs,
    required this.tt,
  });

  final bool isTraveler;
  final int totalBids;
  final int totalTrips;
  final bool isLoading;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final String stat1Value;
    final String stat1Label;
    final String stat3Value;
    final String stat3Label;

    if (isTraveler) {
      stat1Value = isLoading ? '—' : '$totalTrips';
      stat1Label = 'Trajets';
      stat3Value = '98%';
      stat3Label = 'Livraison';
    } else {
      stat1Value = isLoading ? '—' : '$totalBids';
      stat1Label = 'Envois';
      stat3Value = '0€';
      stat3Label = 'Économisés';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Expanded(child: _StatItem(value: stat1Value, label: stat1Label, cs: cs, tt: tt)),
          Container(width: 1, height: 32, color: cs.outline),
          Expanded(child: _StatItem(value: '4.9', label: 'Ma note', cs: cs, tt: tt)),
          Container(width: 1, height: 32, color: cs.outline),
          Expanded(child: _StatItem(value: stat3Value, label: stat3Label, cs: cs, tt: tt)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.cs,
    required this.tt,
  });

  final String value;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
