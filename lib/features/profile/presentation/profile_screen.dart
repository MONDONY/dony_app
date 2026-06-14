import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
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
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:dony/features/profile/presentation/widgets/become_traveler_cta_card.dart';
import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/presentation/widgets/redeem_code_bottom_sheet.dart';
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

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _tabController = TabController(length: 3, vsync: this);

  static const double _kContentHeightDual = 124.0;
  static const double _kContentHeightSingle = 74.0;
  static const double _kProgressBarSectionHeight = 38.0;

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
    _tabController.dispose();
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
          buildWhen: (prev, curr) =>
              curr is AuthAuthenticated || curr is AuthProfileUpdated,
          builder: (context, authState) {
            UserModel? user;
            if (authState is AuthAuthenticated) user = authState.user;
            if (authState is AuthProfileUpdated) user = authState.user;

            final isTraveler = user?.isTraveler ?? false;
            final isSender = user?.isSender ?? false;
            final isKycVerified = user?.isKycVerified ?? false;
            final isProAccount = user?.isProAccount ?? false;
            final displayName = user?.displayName ?? 'Utilisateur';

            return BlocBuilder<BidBloc, BidState>(
              builder: (context, bidState) {
                return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                  builder: (context, announcementState) {
                    final bids = bidState is BidListLoaded
                        ? bidState.bids
                        : <BidModel>[];
                    final activeBids = bids
                        .where((b) => b.status == 'ACCEPTED')
                        .length;
                    final announcements =
                        announcementState is AnnouncementListLoaded
                        ? announcementState.announcements
                        : <AnnouncementModel>[];
                    final upcomingAnnouncements = announcements
                        .where(
                          (a) => a.status == 'ACTIVE' || a.status == 'FULL',
                        )
                        .length;

                    final cs = Theme.of(context).colorScheme;
                    final topPad = MediaQuery.of(context).padding.top;
                    final contentHeight = (isTraveler && isSender)
                        ? _kContentHeightDual
                        : _kContentHeightSingle;
                    final offset = _scroll.hasClients
                        ? _scroll.offset.clamp(0.0, double.infinity)
                        : 0.0;
                    final progress = (offset / contentHeight).clamp(0.0, 1.0);

                    int completionSteps = user?.profileCompletionSteps ?? 0;
                    if (user?.phoneNumber?.isNotEmpty == true) {
                      completionSteps++;
                    }
                    if (user?.email?.isNotEmpty == true) completionSteps++;
                    if (user?.isKycVerified == true) completionSteps++;
                    const totalCompletionSteps =
                        UserModel.profileTotalSteps + 3;
                    final profileCompletionPercent = user != null
                        ? completionSteps / totalCompletionSteps
                        : 0.0;
                    final isProfileComplete = profileCompletionPercent >= 1.0;
                    final expandedHeight =
                        topPad +
                        56.0 +
                        contentHeight -
                        (isProfileComplete ? _kProgressBarSectionHeight : 0.0);

                    return RefreshIndicator(
                      color: cs.primary,
                      onRefresh: () async {
                        context.read<BidBloc>().add(BidMyListRequested());
                        context.read<AnnouncementBloc>().add(
                          AnnouncementListRequested(),
                        );
                      },
                      child: NestedScrollView(
                        controller: _scroll,
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          // ── AppBar avec ProfileHeader existant ────
                          SliverAppBar(
                            expandedHeight: expandedHeight,
                            pinned: true,
                            elevation: 0,
                            scrolledUnderElevation: 0,
                            automaticallyImplyLeading: false,
                            centerTitle: false,
                            forceElevated: innerBoxIsScrolled,
                            backgroundColor: cs.surface,
                            surfaceTintColor: Colors.transparent,
                            title: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: progress,
                                  child: DonyAvatar(
                                    name: displayName,
                                    size: DonyAvatarSize.xs,
                                    verified: isKycVerified,
                                    pro: isProAccount,
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Flexible(
                                  child: Opacity(
                                    opacity: progress,
                                    child: Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall!
                                          .copyWith(
                                            color: cs.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                            actions: const [],
                            flexibleSpace: FlexibleSpaceBar(
                              collapseMode: CollapseMode.parallax,
                              background: ProfileHeader(
                                displayName: displayName,
                                isTraveler: isTraveler,
                                isSender: isSender,
                                isKycVerified: isKycVerified,
                                isProAccount: isProAccount,
                                phoneNumber: user?.phoneNumber,
                                email: user?.email,
                                city: user?.city,
                                profileCompletionPercent:
                                    profileCompletionPercent,
                                onEditProfile: () =>
                                    context.push('/profile/edit'),
                              ),
                            ),
                          ),
                          // ── Tab bar sticky ────────────────────────
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _ProfileTabBarDelegate(
                              tabBar: TabBar(
                                controller: _tabController,
                                labelColor: cs.primary,
                                unselectedLabelColor: cs.onSurfaceVariant,
                                indicatorColor: cs.primary,
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                unselectedLabelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                dividerColor: cs.outline.withValues(alpha: 0.4),
                                tabs: const [
                                  Tab(
                                    child: _TabItem(
                                      icon: Icons.bolt_rounded,
                                      label: 'Activité',
                                    ),
                                  ),
                                  Tab(
                                    child: _TabItem(
                                      icon: Icons.manage_accounts_rounded,
                                      label: 'Compte',
                                    ),
                                  ),
                                  Tab(
                                    child: _TabItem(
                                      icon: Icons.tune_rounded,
                                      label: 'Réglages',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: cs.surface,
                            ),
                          ),
                        ],
                        body: TabBarView(
                          controller: _tabController,
                          children: [
                            _ActivityTab(
                              user: user,
                              isTraveler: isTraveler,
                              upcomingAnnouncements: upcomingAnnouncements,
                              activeBids: activeBids,
                              bidState: bidState,
                              announcementState: announcementState,
                            ),
                            _AccountTab(
                              user: user,
                              isTraveler: isTraveler,
                              isProAccount: isProAccount,
                            ),
                            const _SettingsTab(),
                          ],
                        ),
                      ),
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

// ── Sticky tab bar delegate ───────────────────────────────────────────────────

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate old) =>
      old.backgroundColor != backgroundColor;
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 15), const SizedBox(width: 5), Text(label)],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — ACTIVITÉ
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.user,
    required this.isTraveler,
    required this.upcomingAnnouncements,
    required this.activeBids,
    required this.bidState,
    required this.announcementState,
  });

  final UserModel? user;
  final bool isTraveler;
  final int upcomingAnnouncements;
  final int activeBids;
  final BidState bidState;
  final AnnouncementState announcementState;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLoading =
        bidState is BidLoading || announcementState is AnnouncementLoading;

    return ListView(
      key: const Key('profile_activity_tab'),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: [
        if (user != null &&
            user!.isPendingDeletion &&
            user!.deletionRequestedAt != null) ...[
          PendingDeletionBanner(
            deletionRequestedAt: user!.deletionRequestedAt!,
            onReactivate: () => context.read<AccountDeletionBloc>().add(
              const ReactivateAccount(),
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
        ],

        if (user != null && !user!.isProfileComplete) ...[
          _ProfileCompletionBanner(
            user: user!,
            onTap: () => context.push('/profile/edit'),
            cs: cs,
            tt: tt,
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: DonySpacing.lg),
        ],

        // ── Stats card ──────────────────────────────────────────────────
        _SectionLabel(
          label: isTraveler ? 'ACTIVITÉ · VOYAGEUR' : 'ACTIVITÉ · EXPÉDITEUR',
          cs: cs,
        ),
        _ActivitySection(
              isTraveler: isTraveler,
              totalTrips: user?.totalTrips ?? 0,
              totalShipments: user?.totalShipments ?? 0,
              isLoading: isLoading,
            )
            .animate()
            .fadeIn(delay: 100.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.xl),

        // Base commune (expéditeur) — toujours visible
        _SectionLabel(label: 'MON ACTIVITÉ', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.local_shipping_rounded,
                  iconColor: cs.secondary,
                  iconBgColor: cs.secondaryContainer,
                  label: 'Mes envois en cours',
                  showDivider: activeBids > 0,
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
                if (activeBids > 0)
                  DonyListTile(
                    icon: Icons.compare_arrows_rounded,
                    iconColor: cs.tertiary,
                    iconBgColor: cs.tertiaryContainer,
                    label: 'Mes négociations',
                    showDivider: false,
                    onTap: () => context.push('/negotiations'),
                  ),
              ],
            )
            .animate()
            .fadeIn(delay: 140.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.lg),

        _SectionLabel(label: 'MON CARNET', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.contacts_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Mes destinataires',
                  onTap: () => context.push('/profile/recipients'),
                ),
                DonyListTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: cs.tertiary,
                  iconBgColor: cs.tertiaryContainer.withValues(alpha: 0.5),
                  label: 'Mes abonnements',
                  onTap: () => context.push('/profile/subscriptions'),
                ),
                DonyListTile(
                  icon: Icons.location_on_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Mes adresses',
                  showDivider: false,
                  onTap: () => context.push('/profile/addresses'),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 180.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.lg),

        _SectionLabel(label: 'LITIGES', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.balance_rounded,
                  iconColor: cs.error,
                  iconBgColor: cs.errorContainer.withValues(alpha: 0.5),
                  label: 'Mes litiges',
                  showDivider: false,
                  onTap: () => context.push('/disputes'),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 240.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.xl),

        // Ajout voyageur
        if (isTraveler) ...[
          _SectionLabel(label: 'MES TRAJETS', cs: cs),
          DonyListSection(
                tiles: [
                  DonyListTile(
                    icon: Icons.flight_rounded,
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
                    icon: Icons.move_to_inbox_rounded,
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
                    onTap: () => context.push('/package-requests/match'),
                  ),
                  DonyListTile(
                    icon: Icons.bookmark_rounded,
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Mes modèles de trajet',
                    showDivider: false,
                    onTap: () => context.push('/trip-templates'),
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 140.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          const SizedBox(height: DonySpacing.xl),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — COMPTE
// ═══════════════════════════════════════════════════════════════════════════════

class _AccountTab extends StatelessWidget {
  const _AccountTab({
    required this.user,
    required this.isTraveler,
    required this.isProAccount,
  });

  final UserModel? user;
  final bool isTraveler;
  final bool isProAccount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      key: const Key('profile_account_tab'),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: [
        // ── CTA Devenir voyageur (non-voyageur uniquement) ──────────────
        if (!isTraveler) ...[
          BecomeTravelerCtaCard(
            onTap: () => context.push('/profile/become-traveler'),
            kycStatus: user?.kycStatus,
            stripeStatus: user?.stripeAccountStatus,
          ),
          const SizedBox(height: DonySpacing.xl),
        ],

        // ── CONTACT & SÉCURITÉ ──────────────────────────────────────────
        _SectionLabel(label: 'CONTACT & SÉCURITÉ', cs: cs),
        _ContactSecuritySection(
              phoneNumber: user?.phoneNumber,
              email: user?.email,
              onPhoneTap: () => AddPhoneSheet.show(context),
              onEmailTap: () => AddEmailSheet.show(context),
            )
            .animate()
            .fadeIn(delay: 80.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.xl),

        // ── IDENTITÉ & CONFIANCE ────────────────────────────────────────
        _SectionLabel(label: 'IDENTITÉ & CONFIANCE', cs: cs),
        DonyListSection(
              tiles: [
                _kycTile(context, user),
                DonyListTile(
                  icon: Icons.person_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Mon profil public',
                  onTap: () => context.push(
                    '/profile/public',
                    extra: ProfilePublicArgs(
                      userId: user?.id,
                      showSubscribe: false,
                    ),
                  ),
                ),
                DonyListTile(
                  icon: Icons.stars_rounded,
                  iconColor: cs.tertiary,
                  iconBgColor: cs.tertiaryContainer,
                  label: 'Mes avis reçus',
                  showDivider: false,
                  onTap: () => context.push('/profile/reviews'),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.lg),

        // ── FIDÉLITÉ (commun, dédupliqué) ───────────────────────────────
        _SectionLabel(label: 'FIDÉLITÉ', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.group_add_rounded,
                  iconColor: cs.success,
                  iconBgColor: cs.successLight,
                  label: 'Parrainages',
                  trailing: Text(
                    '0 invité',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  showDivider: true,
                  onTap: () => context.push('/profile/referral'),
                ),
                BlocBuilder<ReferralBloc, ReferralState>(
                  builder: (context, referralState) {
                    final alreadyReferred =
                        referralState is ReferralLoaded &&
                        referralState.info.hasBeenReferred;
                    if (alreadyReferred) return const SizedBox.shrink();
                    return DonyListTile(
                      icon: Icons.card_giftcard_rounded,
                      iconColor: cs.primary,
                      iconBgColor: cs.primaryContainer,
                      label: 'J\'ai un code parrain',
                      showDivider: false,
                      onTap: () async {
                        final redeemed = await RedeemCodeBottomSheet.show(
                          context,
                        );
                        if ((redeemed ?? false) && context.mounted) {
                          context.read<ReferralBloc>().add(
                            const ReferralLoadRequested(),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.lg),

        // ── Ajout voyageur ──────────────────────────────────────────────
        if (isTraveler) ...[
          // ── REVENUS & PAIEMENTS ─────────────────────────────────────
          _SectionLabel(label: 'REVENUS & PAIEMENTS', cs: cs),
          DonyListSection(
                tiles: [
                  DonyListTile(
                    icon: Icons.savings_rounded,
                    iconColor: cs.success,
                    iconBgColor: cs.successLight,
                    label: 'Recevoir mes paiements',
                    onTap: () => context.push('/payments/onboarding'),
                  ),
                  DonyListTile(
                    icon: Icons.payment_rounded,
                    iconColor: DonyColors.purple,
                    iconBgColor: DonyColors.violetLight,
                    label: 'Carte commission cash',
                    onTap: () => context.push('/payments/commission-method'),
                  ),
                  DonyListTile(
                    icon: Icons.grid_view_outlined,
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Ma grille de prix',
                    subtitle: 'Tarifs par article pour vos trajets',
                    showDivider: false,
                    onTap: () => context.push('/profile/price-grid'),
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 240.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          const SizedBox(height: DonySpacing.lg),

          // ── COMPTE PRO ─────────────────────────────────────────────
          _SectionLabel(label: 'COMPTE PRO', cs: cs),
          DonyListSection(
                tiles: [
                  DonyListTile(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: isProAccount ? cs.success : cs.warning,
                    iconBgColor: isProAccount
                        ? cs.successLight
                        : cs.warningLight,
                    label: isProAccount
                        ? 'Mon profil PRO'
                        : 'Passer en compte PRO',
                    trailing: isProAccount
                        ? Icon(
                            Icons.verified_rounded,
                            color: cs.success,
                            size: 18,
                          )
                        : null,
                    showDivider: false,
                    onTap: user != null
                        ? () => context.push('/profile/upgrade-to-pro')
                        : null,
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 280.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          const SizedBox(height: DonySpacing.lg),
        ],

        // ── PAIEMENTS (commun aux deux rôles) ───────────────────────────
        const SizedBox(height: DonySpacing.lg),
        _SectionLabel(label: 'PAIEMENTS', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Mon portefeuille',
                  subtitle: 'Solde & recharges',
                  showDivider: false,
                  onTap: () => context.push('/payments/wallet'),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 260.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — RÉGLAGES
// ═══════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      key: const Key('profile_settings_tab'),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: [
        // ── PRÉFÉRENCES ─────────────────────────────────────────────────
        _SectionLabel(label: 'PRÉFÉRENCES', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.tune_rounded,
                  label: 'Paramètres',
                  onTap: () => context.push('/settings'),
                ),
                DonyListTile(
                  icon: Icons.notifications_none_rounded,
                  iconColor: cs.warning,
                  iconBgColor: cs.warningLight,
                  label: 'Notifications',
                  onTap: () {},
                ),
                DonyListTile(
                  icon: Icons.translate_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Langue',
                  trailing: Text(
                    'Français',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  showDivider: false,
                  onTap: () {},
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 80.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.lg),

        // ── SÉCURITÉ ────────────────────────────────────────────────────
        _SectionLabel(label: 'SÉCURITÉ', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.security_rounded,
                  iconColor: cs.onSurfaceVariant,
                  iconBgColor: cs.outline.withValues(alpha: 0.3),
                  label: 'Sécurité & confidentialité',
                  showDivider: false,
                  onTap: () {},
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.lg),

        // ── SUPPORT ─────────────────────────────────────────────────────
        _SectionLabel(label: 'SUPPORT', cs: cs),
        DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.headset_mic_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Contacter le support',
                  onTap: () => context.push('/profile/help/contact'),
                ),
                DonyListTile(
                  icon: Icons.quiz_rounded,
                  iconColor: cs.onSurfaceVariant,
                  iconBgColor: cs.outline.withValues(alpha: 0.3),
                  label: 'FAQ & aide',
                  showDivider: false,
                  onTap: () => context.push('/profile/help/faq'),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 160.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.xxl),

        // ── DÉCONNEXION ─────────────────────────────────────────────────
        DonyButton(
          label: 'Se déconnecter',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
          variant: DonyButtonVariant.ghost,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── FOOTER ──────────────────────────────────────────────────────
        Text(
          'dony v1.0.0 · Made with ❤️ in Paris',
          style: tt.bodySmall?.copyWith(color: cs.outline),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 240.ms),
      ],
    );
  }
}

// ── Section Contact & Sécurité ────────────────────────────────────────────────

class _ContactSecuritySection extends StatelessWidget {
  const _ContactSecuritySection({
    required this.phoneNumber,
    required this.email,
    required this.onPhoneTap,
    required this.onEmailTap,
  });

  final String? phoneNumber;
  final String? email;
  final VoidCallback onPhoneTap;
  final VoidCallback onEmailTap;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phoneNumber != null && phoneNumber!.isNotEmpty;
    final hasEmail = email != null && email!.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.phone_rounded,
            iconBg: cs.primaryContainer,
            iconColor: cs.primary,
            typeLabel: 'TÉLÉPHONE',
            value: hasPhone ? phoneNumber! : 'Non ajouté',
            isEmpty: !hasPhone,
            isVerified: hasPhone,
            showDivider: true,
            onTap: onPhoneTap,
          ),
          _ContactRow(
            icon: Icons.alternate_email_rounded,
            iconBg: cs.successLight,
            iconColor: cs.success,
            typeLabel: 'E-MAIL',
            value: hasEmail ? email! : 'Non ajouté',
            isEmpty: !hasEmail,
            isVerified: hasEmail,
            showDivider: false,
            onTap: onEmailTap,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.typeLabel,
    required this.value,
    required this.isEmpty,
    required this.isVerified,
    required this.showDivider,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String typeLabel;
  final String value;
  final bool isEmpty;
  final bool isVerified;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: showDivider
              ? const BorderRadius.vertical(
                  top: Radius.circular(DonyRadius.card),
                )
              : const BorderRadius.vertical(
                  bottom: Radius.circular(DonyRadius.card),
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                DonyIconContainer(
                  icon: icon,
                  backgroundColor: iconBg,
                  iconColor: iconColor,
                  borderRadius: DonyRadius.sm,
                  size: DonyIconContainerSize.sm,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                          fontWeight: isEmpty
                              ? FontWeight.w400
                              : FontWeight.w600,
                          fontStyle: isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                _StatusBadge(isVerified: isVerified),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: DonySpacing.lg + 32),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isVerified});
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isVerified ? cs.successLight : cs.primaryContainer;
    final fg = isVerified ? cs.success : cs.primary;
    final label = isVerified ? '✓ Vérifié' : '+ Ajouter';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Section Activité (stats card) ─────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.isTraveler,
    required this.totalTrips,
    required this.totalShipments,
    required this.isLoading,
  });

  final bool isTraveler;
  final int totalTrips;
  final int totalShipments;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mainValue = isLoading
        ? '—'
        : '${isTraveler ? totalTrips : totalShipments}';
    final mainLabel = isTraveler ? 'Trajets' : 'Envois';
    final thirdValue = isTraveler ? '98%' : '0€';
    final thirdLabel = isTraveler ? 'Livraison' : 'Économisés';

    return DonyCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActivityStat(
              value: mainValue,
              label: mainLabel,
              isLoading: isLoading,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: cs.outline.withValues(alpha: 0.4),
          ),
          const Expanded(
            child: _ActivityStat(
              value: '4.9',
              label: 'Ma note',
              isLoading: false,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: cs.outline.withValues(alpha: 0.4),
          ),
          Expanded(
            child: _ActivityStat(
              value: thirdValue,
              label: thirdLabel,
              isLoading: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.value,
    required this.label,
    required this.isLoading,
  });

  final String value;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          )
        else
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.xs,
        0,
        DonySpacing.xs,
        DonySpacing.sm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── KYC tile partagée ─────────────────────────────────────────────────────────

DonyListTile _kycTile(BuildContext context, UserModel? user) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return DonyListTile(
    icon: Icons.shield_rounded,
    iconColor: cs.primary,
    iconBgColor: cs.primaryContainer,
    label: 'Documents KYC',
    trailing: switch (user?.kycStatus) {
      'VERIFIED' => Text(
        'Vérifié',
        style: tt.labelMedium?.copyWith(
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
            style: tt.labelMedium?.copyWith(
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
            style: tt.labelMedium?.copyWith(
              color: cs.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      _ => Text(
        'Vérifier',
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    },
    onTap: user?.kycStatus == 'VERIFIED'
        ? () => KycStatusBottomSheet.show(context)
        : () => KycOnboardingBottomSheet.show(context),
  );
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
    if (user.birthDate == null) missing.add('Date de naissance');
    if (!(user.city?.isNotEmpty ?? false)) missing.add("Lieu d'habitation");

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
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: cs.warning,
                    size: 18,
                  ),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 18,
                ),
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
                children: missing
                    .map((m) => _MissingChip(label: m, tt: tt))
                    .toList(),
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
      child: Column(children: tiles),
    );
  }
}

