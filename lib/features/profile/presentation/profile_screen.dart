import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart';
import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:dony/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
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
  final _scroll = ScrollController();

  // Hauteur du contenu sous l'AppBar de base (56) — donne expandedHeight total :
  // topPad + 56 + _kContentHeight. Le ProfileHeader rendu en flexibleSpace a sa
  // propre hauteur naturelle ; ce paramètre détermine juste la zone collapsable.
  static const double _kContentHeight = 264.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    context.read<BidBloc>().add(BidMyListRequested());
    context.read<AnnouncementBloc>().add(AnnouncementListRequested());
  }

  void _onScroll() => setState(() {});

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthInitial || state is AuthAccountDeleted) {
              context.go('/auth/phone');
            }
          },
        ),
        BlocListener<AccountDeletionBloc, AccountDeletionState>(
          listener: (context, state) {
            if (state is AccountReactivated) {
              context.read<AuthBloc>().add(const AuthCheckRequested());
            } else if (state is AccountDeletionError) {
              ErrorPresenter.show(context, state.error);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: BlocBuilder<AuthBloc, AuthState>(
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
            final isProAccount = user?.isProAccount ?? false;
            final displayName = user?.displayName ?? 'Utilisateur';

            return BlocBuilder<ActiveRoleCubit, ActiveRole>(
              builder: (context, activeRole) {
                return BlocBuilder<BidBloc, BidState>(
                  builder: (context, bidState) {
                    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                      builder: (context, announcementState) {
                        final bids = bidState is BidListLoaded ? bidState.bids : <BidModel>[];
                        final activeBids = bids.where((b) => b.status == 'ACCEPTED').length;
                        final announcements = announcementState is AnnouncementListLoaded
                            ? announcementState.announcements
                            : <AnnouncementModel>[];
                        final upcomingAnnouncements = announcements
                            .where((a) => a.status == 'ACTIVE' || a.status == 'FULL')
                            .length;

                        final tt = Theme.of(context).textTheme;
                        final cs = Theme.of(context).colorScheme;
                        final topPad = MediaQuery.of(context).padding.top;
                        final expandedHeight = topPad + 56.0 + _kContentHeight;
                        final offset = _scroll.hasClients
                            ? _scroll.offset.clamp(0.0, double.infinity)
                            : 0.0;
                        final progress =
                            (offset / _kContentHeight).clamp(0.0, 1.0);
                        final headerBg = Color.lerp(
                          cs.primary,
                          cs.surface,
                          progress,
                        )!;
                        final iconColor = Color.lerp(
                          cs.onPrimary,
                          cs.onSurface,
                          progress,
                        )!;
                        final titleColor = Color.lerp(
                          cs.onPrimary.withValues(alpha: 0.0),
                          cs.onSurface,
                          progress,
                        )!;

                        return RefreshIndicator(
                          color: cs.primary,
                          onRefresh: () async {
                            context.read<BidBloc>().add(BidMyListRequested());
                            context
                                .read<AnnouncementBloc>()
                                .add(AnnouncementListRequested());
                          },
                          child: CustomScrollView(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverAppBar(
                                expandedHeight: expandedHeight,
                                pinned: true,
                                elevation: 0,
                                scrolledUnderElevation: 0,
                                automaticallyImplyLeading: false,
                                centerTitle: false,
                                backgroundColor: headerBg,
                                surfaceTintColor: Colors.transparent,
                                title: Text(
                                  displayName,
                                  style: tt.titleMedium!.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                actions: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.notifications_outlined,
                                      color: iconColor,
                                    ),
                                    onPressed: () {},
                                    tooltip: 'Notifications',
                                  ),
                                ],
                                flexibleSpace: FlexibleSpaceBar(
                                  collapseMode: CollapseMode.parallax,
                                  background: ProfileHeader(
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
                                              context
                                                  .read<ActiveRoleCubit>()
                                                  .switchToTraveler();
                                            } else {
                                              context
                                                  .read<ActiveRoleCubit>()
                                                  .switchToSender();
                                            }
                                            context.go('/home');
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  DonySpacing.lg,
                                  DonySpacing.xl,
                                  DonySpacing.lg,
                                  DonySpacing.huge,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                      // Bannière suppression en attente
                                      if (user != null &&
                                          user.isPendingDeletion &&
                                          user.deletionRequestedAt != null) ...[
                                        PendingDeletionBanner(
                                          deletionRequestedAt: user.deletionRequestedAt!,
                                          onReactivate: () => context
                                              .read<AccountDeletionBloc>()
                                              .add(const ReactivateAccount()),
                                        ),
                                        const SizedBox(height: DonySpacing.lg),
                                      ],

                                      // Bannière complétion profil
                                      if (user != null && !user.isProfileComplete) ...[
                                        _ProfileCompletionBanner(
                                          user: user,
                                          onTap: () => EditProfileBottomSheet.show(context),
                                          cs: Theme.of(context).colorScheme,
                                          tt: Theme.of(context).textTheme,
                                        ).animate().fadeIn(delay: 180.ms),
                                        const SizedBox(height: DonySpacing.lg),
                                      ],

                                      // Menu principal contextuel au rôle
                                      DonyListSection(
                                        tiles: [
                                          if (activeRole == ActiveRole.traveler) ...[
                                            DonyListTile(
                                              icon: Icons.flight_takeoff_rounded,
                                              iconColor: Theme.of(context).colorScheme.primary,
                                              iconBgColor: Theme.of(context).colorScheme.primaryContainer,
                                              label: 'Mes trajets',
                                              trailing: upcomingAnnouncements > 0
                                                  ? Text(
                                                      '$upcomingAnnouncements à venir',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    )
                                                  : null,
                                              onTap: () => context.push('/announcements'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.account_balance_wallet_rounded,
                                              iconColor: cs.success,
                                              iconBgColor: cs.successLight,
                                              label: 'Recevoir mes paiements',
                                              onTap: () => context.push('/payments/onboarding'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.business_center_rounded,
                                              iconColor: isProAccount ? cs.success : cs.warning,
                                              iconBgColor: isProAccount ? cs.successLight : cs.warningLight,
                                              label: isProAccount ? 'Mon profil PRO' : 'Passer en compte PRO',
                                              trailing: isProAccount
                                                  ? Icon(Icons.verified_rounded, color: cs.success, size: 18)
                                                  : null,
                                              onTap: user != null
                                                  ? () => UpgradeProBottomSheet.show(context, user: user!)
                                                  : null,
                                            ),
                                          ] else ...[
                                            DonyListTile(
                                              icon: Icons.inventory_2_outlined,
                                              iconColor: Theme.of(context).colorScheme.secondary,
                                              iconBgColor: Theme.of(context).colorScheme.secondaryContainer,
                                              label: 'Mes envois',
                                              trailing: activeBids > 0
                                                  ? Text(
                                                      '$activeBids en cours',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.secondary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    )
                                                  : null,
                                              onTap: () => context.push('/announcements'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.outbox_rounded,
                                              iconColor: Theme.of(context).colorScheme.primary,
                                              iconBgColor: Theme.of(context).colorScheme.primaryContainer,
                                              label: 'Mes demandes d\'envoi',
                                              onTap: () => context.push('/package-requests/me'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.add_circle_outline_rounded,
                                              iconColor: cs.success,
                                              iconBgColor: cs.successLight,
                                              label: 'Publier une demande d\'envoi',
                                              onTap: () =>
                                                  PackageRequestCreateWizard
                                                      .show(context),
                                            ),
                                          ],
                                          if (activeRole == ActiveRole.traveler)
                                            DonyListTile(
                                              icon: Icons.search_rounded,
                                              iconColor: cs.success,
                                              iconBgColor: cs.successLight,
                                              label: 'Demandes d\'envoi à transporter',
                                              onTap: () => context.push('/package-requests/search'),
                                            ),
                                          DonyListTile(
                                            icon: Icons.handshake_rounded,
                                            iconColor: Theme.of(context).colorScheme.tertiary,
                                            iconBgColor: Theme.of(context).colorScheme.tertiaryContainer,
                                            label: 'Mes négociations',
                                            onTap: () => context.push('/negotiations'),
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
                                            iconColor: Theme.of(context).colorScheme.primary,
                                            iconBgColor: Theme.of(context).colorScheme.primaryContainer,
                                            label: 'Documents KYC',
                                            trailing: switch (user?.kycStatus) {
                                              'VERIFIED' => Text(
                                                  'Vérifié',
                                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: cs.success,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              'REJECTED' => Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.warning_amber_rounded, color: cs.warning, size: 16),
                                                    const SizedBox(width: DonySpacing.xs),
                                                    Text(
                                                      'Réessayer',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: cs.warning,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              'PENDING' => Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 1.5,
                                                        color: cs.warning,
                                                      ),
                                                    ),
                                                    const SizedBox(width: DonySpacing.xs),
                                                    Text(
                                                      'En cours',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: cs.warning,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              _ => Text(
                                                  'Vérifier',
                                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                            },
                                            onTap: user?.kycStatus == 'VERIFIED'
                                                ? () => KycStatusBottomSheet.show(context)
                                                : () => KycOnboardingBottomSheet.show(context),
                                          ),
                                          DonyListTile(
                                            icon: Icons.people_outline_rounded,
                                            iconColor: cs.success,
                                            iconBgColor: cs.successLight,
                                            label: 'Parrainages',
                                            trailing: Text(
                                              '0 invité',
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            showDivider: false,
                                            onTap: () {},
                                          ),
                                        ],
                                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                      const SizedBox(height: DonySpacing.base),

                                      // Menu settings
                                      DonyListSection(
                                        tiles: [
                                          DonyListTile(
                                            icon: Icons.settings_outlined,
                                            label: 'Paramètres',
                                            onTap: () => context.push('/settings'),
                                          ),
                                          DonyListTile(
                                            icon: Icons.notifications_outlined,
                                            iconColor: cs.warning,
                                            iconBgColor: cs.warningLight,
                                            label: 'Notifications',
                                            onTap: () {},
                                          ),
                                          DonyListTile(
                                            icon: Icons.language_rounded,
                                            iconColor: Theme.of(context).colorScheme.primary,
                                            iconBgColor: Theme.of(context).colorScheme.primaryContainer,
                                            label: 'Langue',
                                            trailing: Text(
                                              'Français',
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            onTap: () {},
                                          ),
                                          DonyListTile(
                                            icon: Icons.lock_outline_rounded,
                                            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                            iconBgColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                            label: 'Sécurité & confidentialité',
                                            onTap: () {},
                                          ),
                                          DonyListTile(
                                            icon: Icons.help_outline_rounded,
                                            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                            iconBgColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                            label: 'Aide & support',
                                            showDivider: false,
                                            onTap: () {},
                                          ),
                                        ],
                                      ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                      const SizedBox(height: DonySpacing.xxl),

                                      // Déconnexion
                                      DonyButton(
                                        label: 'Se déconnecter',
                                        onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                                        variant: DonyButtonVariant.ghost,
                                      ).animate().fadeIn(delay: 280.ms),
                                      const SizedBox(height: DonySpacing.xxl),

                                      // Footer
                                      Text(
                                        'dony v1.0.0 · Made with ❤️ in Paris',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ).animate().fadeIn(delay: 320.ms),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
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
          color: cs.warningLight,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Icon(Icons.edit_note_rounded,
                      color: cs.warning, size: 18),
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
                          color: cs.warning,
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
                valueColor: AlwaysStoppedAnimation<Color>(cs.warning),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: cs.warning, size: 12),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── List Section wrapper ──────────────────────────────────────────────────────

class DonyListSection extends StatelessWidget {
  const DonyListSection({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }
}
