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
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:dony/features/profile/presentation/widgets/coming_soon_bottom_sheet.dart';
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

  // expandedHeight = topPad + 56 + contentHeight.
  // contentHeight = col_height - 24 (padding haut DonySpacing.lg=20 + bas DonySpacing.md=12 - 56 toolbar)
  // col_height dual   = avatar(72) + sm(12) + pill(38) + sm(12) + progressBar(24) = 158 → 158-24=134
  // col_height single = avatar(72) + sm(12) + progressBar(24) = 108 → 108-24=84
  static const double _kContentHeightDual   = 140.0; // double rôle (toggle présent, +6 buffer)
  static const double _kContentHeightSingle = 90.0;  // rôle unique (+6 buffer)

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
          buildWhen: (prev, curr) => curr is AuthAuthenticated || curr is AuthProfileUpdated,
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
                        final contentHeight = (isTraveler && isSender)
                            ? _kContentHeightDual
                            : _kContentHeightSingle;
                        final expandedHeight = topPad + 56.0 + contentHeight;
                        final offset = _scroll.hasClients
                            ? _scroll.offset.clamp(0.0, double.infinity)
                            : 0.0;
                        final progress = (offset / contentHeight).clamp(0.0, 1.0);

                        // Calcul du pourcentage de complétion du profil
                        int completionSteps = user?.profileCompletionSteps ?? 0;
                        if (user?.phoneNumber?.isNotEmpty == true) {
                          completionSteps++;
                        }
                        if (user?.email?.isNotEmpty == true) {
                          completionSteps++;
                        }
                        if (user?.isKycVerified == true) {
                          completionSteps++;
                        }
                        const totalCompletionSteps = UserModel.profileTotalSteps + 3;
                        final profileCompletionPercent = user != null
                            ? completionSteps / totalCompletionSteps
                            : 0.0;

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
                                          style: tt.titleSmall!.copyWith(
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
                                    activeRole: activeRole,
                                    isTraveler: isTraveler,
                                    isSender: isSender,
                                    isKycVerified: isKycVerified,
                                    isProAccount: isProAccount,
                                    phoneNumber: user?.phoneNumber,
                                    email: user?.email,
                                    city: user?.city,
                                    profileCompletionPercent: profileCompletionPercent,
                                    onEditProfile: () => EditProfileBottomSheet.show(context),
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

                                      // ─── CONTACT & SÉCURITÉ ──────────────────────────────
                                      _SectionLabel(label: 'CONTACT & SÉCURITÉ', cs: cs),
                                      _ContactSecuritySection(
                                        phoneNumber: user?.phoneNumber,
                                        email: user?.email,
                                        onPhoneTap: () => AddPhoneSheet.show(context),
                                        onEmailTap: () => AddEmailSheet.show(context),
                                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                      const SizedBox(height: DonySpacing.xl),

                                      // ─── ACTIVITÉ ─────────────────────────────────────────
                                      _SectionLabel(
                                        label: activeRole == ActiveRole.traveler
                                            ? 'ACTIVITÉ · VOYAGEUR'
                                            : 'ACTIVITÉ · EXPÉDITEUR',
                                        cs: cs,
                                      ),
                                      _ActivitySection(
                                        activeRole: activeRole,
                                        totalTrips: user?.totalTrips ?? 0,
                                        totalShipments: user?.totalShipments ?? 0,
                                        isLoading: bidState is BidLoading ||
                                            announcementState is AnnouncementLoading,
                                      ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                      const SizedBox(height: DonySpacing.xl),

                                      // ─── MENU PRINCIPAL CONTEXTUEL AU RÔLE ───────────────
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
                                              onTap: () => context.push('/package-requests/match'),
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
                                        // ─── SENDER ───────────────────────
                                        // 1. Mon activité — pilote des envois en cours
                                        _SectionLabel(label: 'MON ACTIVITÉ', cs: cs),
                                        DonyListSection(
                                          tiles: [
                                            DonyListTile(
                                              icon: Icons.inventory_2_outlined,
                                              iconColor: cs.secondary,
                                              iconBgColor: cs.secondaryContainer,
                                              label: 'Mes envois en cours',
                                              trailing: activeBids > 0
                                                  ? Text(
                                                      '$activeBids en cours',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: cs.secondary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    )
                                                  : null,
                                              onTap: () => context.push('/announcements'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.history_rounded,
                                              iconColor: cs.tertiary,
                                              iconBgColor: cs.tertiaryContainer,
                                              label: 'Historique des livraisons',
                                              showDivider: false,
                                              onTap: () => context.push('/profile/shipments/history'),
                                            ),
                                          ],
                                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                        const SizedBox(height: DonySpacing.lg),

                                        // 2. Mon carnet — accélère la prochaine demande
                                        _SectionLabel(label: 'MON CARNET', cs: cs),
                                        DonyListSection(
                                          tiles: [
                                            DonyListTile(
                                              icon: Icons.location_on_outlined,
                                              iconColor: cs.primary,
                                              iconBgColor: cs.primaryContainer,
                                              label: 'Mes adresses de pickup',
                                              onTap: () => context.push('/profile/addresses'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.contacts_outlined,
                                              iconColor: cs.primary,
                                              iconBgColor: cs.primaryContainer,
                                              label: 'Mes destinataires',
                                              onTap: () => context.push('/profile/recipients'),
                                            ),
                                            DonyListTile(
                                              icon: Icons.favorite_border_rounded,
                                              iconColor: cs.error,
                                              iconBgColor: cs.errorContainer.withValues(alpha: 0.5),
                                              label: 'Voyageurs favoris',
                                              showDivider: false,
                                              onTap: () => context.push('/profile/favorites'),
                                            ),
                                          ],
                                        ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                        const SizedBox(height: DonySpacing.lg),

                                        // 3. Paiements & factures
                                        _SectionLabel(label: 'PAIEMENTS & FACTURES', cs: cs),
                                        DonyListSection(
                                          tiles: [
                                            DonyListTile(
                                              icon: Icons.credit_card_outlined,
                                              iconColor: DonyColors.purple,
                                              iconBgColor: DonyColors.violetLight,
                                              label: 'Moyens de paiement',
                                              onTap: () => ComingSoonBottomSheet.show(
                                                context,
                                                title: 'Moyens de paiement',
                                                description: 'Gère tes cartes enregistrées, Apple Pay et Google Pay via Stripe.',
                                                icon: Icons.credit_card_rounded,
                                              ),
                                            ),
                                            DonyListTile(
                                              icon: Icons.receipt_long_outlined,
                                              iconColor: DonyColors.purple,
                                              iconBgColor: DonyColors.violetLight,
                                              label: 'Factures',
                                              onTap: () => ComingSoonBottomSheet.show(
                                                context,
                                                title: 'Factures',
                                                description: 'Télécharge les factures PDF de tes envois (utiles pour la valeur déclarée).',
                                                icon: Icons.receipt_long_rounded,
                                              ),
                                            ),
                                            DonyListTile(
                                              icon: Icons.local_offer_outlined,
                                              iconColor: cs.success,
                                              iconBgColor: cs.successLight,
                                              label: 'Crédits & codes promo',
                                              onTap: () => ComingSoonBottomSheet.show(
                                                context,
                                                title: 'Crédits & codes promo',
                                                description: 'Entre un code de réduction et suis ton solde de crédits dony.',
                                                icon: Icons.local_offer_rounded,
                                              ),
                                            ),
                                            DonyListTile(
                                              icon: Icons.people_outline_rounded,
                                              iconColor: cs.success,
                                              iconBgColor: cs.successLight,
                                              label: 'Parrainage',
                                              trailing: Text(
                                                '0 invité',
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                              showDivider: false,
                                              onTap: () => context.push('/profile/referral'),
                                            ),
                                          ],
                                        ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                        const SizedBox(height: DonySpacing.lg),

                                        // ─── DEVENIR VOYAGEUR ─────────────────────────────
                                        _SectionLabel(label: 'DEVENIR VOYAGEUR', cs: cs),
                                        DonyListSection(
                                          tiles: [
                                            DonyListTile(
                                              icon: Icons.flight_takeoff_rounded,
                                              iconColor: cs.secondary,
                                              iconBgColor: cs.secondaryContainer,
                                              label: 'Devenir voyageur dony',
                                              trailing: _TravelerUpgradeTrailing(
                                                kycStatus: user?.kycStatus,
                                                stripeStatus: user?.stripeAccountStatus,
                                              ),
                                              showDivider: false,
                                              onTap: () => context.push('/profile/become-traveler'),
                                            ),
                                          ],
                                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                        const SizedBox(height: DonySpacing.lg),

                                        // 4. Identité & confiance
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
                                        ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                        const SizedBox(height: DonySpacing.lg),

                                        // 5. Support
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
                                        ).animate().fadeIn(delay: 360.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                                      ],
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
            icon: Icons.email_rounded,
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
              ? const BorderRadius.vertical(top: Radius.circular(DonyRadius.card))
              : const BorderRadius.vertical(bottom: Radius.circular(DonyRadius.card)),
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
                        style: tt.bodyMedium?.copyWith(
                          color: isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                          fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                          fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
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
        if (showDivider)
          const Divider(height: 1, indent: DonySpacing.lg + 32),
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

// ── Section Activité ──────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.activeRole,
    required this.totalTrips,
    required this.totalShipments,
    required this.isLoading,
  });

  final ActiveRole activeRole;
  final int totalTrips;
  final int totalShipments;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTraveler = activeRole == ActiveRole.traveler;
    final mainValue = isLoading ? '—' : '${isTraveler ? totalTrips : totalShipments}';
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
          Expanded(child: _ActivityStat(value: mainValue, label: mainLabel, isLoading: isLoading)),
          Container(width: 1, height: 28, color: cs.outline.withValues(alpha: 0.4)),
          const Expanded(child: _ActivityStat(value: '4.9', label: 'Ma note', isLoading: false)),
          Container(width: 1, height: 28, color: cs.outline.withValues(alpha: 0.4)),
          Expanded(child: _ActivityStat(value: thirdValue, label: thirdLabel, isLoading: false)),
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

// ── Section label (UPPERCASE titre de groupe) ────────────────────────────────

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

// ── KYC tile partagée (sender + traveler) ────────────────────────────────────

DonyListTile _kycTile(BuildContext context, UserModel? user) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return DonyListTile(
    icon: Icons.badge_outlined,
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
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
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

// ── Traveler upgrade trailing indicator ──────────────────────────────────────

class _TravelerUpgradeTrailing extends StatelessWidget {
  const _TravelerUpgradeTrailing({
    required this.kycStatus,
    required this.stripeStatus,
  });

  final String? kycStatus;
  final String? stripeStatus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kycOk = kycStatus == 'VERIFIED';
    final stripeOk = stripeStatus == 'ONBOARDING_COMPLETE';

    if (kycOk && stripeOk) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: cs.success, size: 14),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'Prêt',
            style: tt.labelSmall?.copyWith(
              color: cs.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final int done = (kycOk ? 1 : 0) + (stripeOk ? 1 : 0);
    return Text(
      '$done/2 étapes',
      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}
