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
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthAccountDeleted) {
          context.go('/auth/phone');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          UserModel? user;
          if (authState is AuthAuthenticated) user = authState.user;
          if (authState is AuthProfileUpdated) user = authState.user;
          final isTraveler = user?.isTraveler ?? false;
          final isSender = user?.isSender ?? false;
          final isKycVerified = user?.isKycVerified ?? false;
          final displayName = user?.displayName ?? 'Utilisateur';
          final initials = user?.initials ?? '?';

          return BlocBuilder<BidBloc, BidState>(
            builder: (context, bidState) {
              return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                builder: (context, announcementState) {
                  // Bid stats (sender)
                  final bids = bidState is BidListLoaded ? bidState.bids : <dynamic>[];
                  final totalBids = bids.length;
                  final activeBids =
                      bids.where((b) => b.status == 'ACCEPTED').length;

                  // Announcement stats (traveler)
                  final announcements = announcementState is AnnouncementListLoaded
                      ? announcementState.announcements
                      : <AnnouncementModel>[];
                  // totalElements = total from backend pagination (tous statuts)
                  final totalAnnouncements = announcementState is AnnouncementListLoaded
                      ? announcementState.totalElements
                      : 0;
                  // Trajets en cours ou à venir = ACTIVE + FULL
                  final upcomingAnnouncements = announcements
                      .where((a) => a.status == 'ACTIVE' || a.status == 'FULL')
                      .length;

                  return Scaffold(
                    backgroundColor: DonyColors.grey50,
                    appBar: AppBar(
                      title: Text(
                        'Mon profil',
                        style: GoogleFonts.sora(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: DonyColors.dark900,
                        ),
                      ),
                      centerTitle: true,
                      backgroundColor: DonyColors.white,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      bottom: const PreferredSize(
                        preferredSize: Size.fromHeight(1),
                        child: Divider(height: 1),
                      ),
                      actions: [
                        BlocBuilder<NotificationBloc, NotificationState>(
                          builder: (context, notifState) {
                            final unread = notifState is NotificationLoaded
                                ? notifState.unreadCount
                                : 0;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.notifications_outlined,
                                    color: DonyColors.dark900,
                                    size: 22,
                                  ),
                                  onPressed: () => context.go('/messages'),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: DonyColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                    body: RefreshIndicator(
                      color: DonyColors.blue400,
                      onRefresh: () async {
                        context.read<BidBloc>().add(BidMyListRequested());
                        context
                            .read<AnnouncementBloc>()
                            .add(AnnouncementListRequested());
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(20, 28, 20, 40),
                        child: Column(
                          children: [
                            // ── Avatar ─────────────────────────────────
                            _buildAvatar(initials, isKycVerified)
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .scale(
                                  begin: const Offset(0.85, 0.85),
                                  curve: Curves.easeOutBack,
                                ),
                            const SizedBox(height: 12),

                            // ── Nom / identifiant ───────────────────────
                            Text(
                              displayName,
                              style: GoogleFonts.sora(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: DonyColors.dark900,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 80.ms),
                            const SizedBox(height: 10),

                            // ── Badges ──────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isKycVerified) ...[
                                  _Badge(
                                    icon: Icons.verified_rounded,
                                    label: 'Identité vérifiée',
                                    color: DonyColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (isTraveler)
                                  _Badge(
                                    icon: Icons.flight_takeoff_rounded,
                                    label: 'Voyageur',
                                    color: DonyColors.blue400,
                                  ),
                                if (isTraveler && isSender)
                                  const SizedBox(width: 8),
                                if (isSender)
                                  _Badge(
                                    icon: Icons.send_rounded,
                                    label: 'Expéditeur',
                                    color: const Color(0xFFE67E22),
                                  ),
                              ],
                            ).animate().fadeIn(delay: 120.ms),
                            const SizedBox(height: 24),

                            // ── Stats ───────────────────────────────────
                            _StatsRow(
                              isTraveler: isTraveler,
                              totalBids: totalBids,
                              totalAnnouncements: totalAnnouncements,
                              isLoading: bidState is BidLoading ||
                                  announcementState is AnnouncementLoading,
                            ).animate().fadeIn(delay: 160.ms),
                            const SizedBox(height: 20),

                            // ── Bannière complétion profil ───────────────
                            if (user != null && !user.isProfileComplete) ...[
                              _ProfileCompletionBanner(
                                user: user,
                                onTap: () =>
                                    context.push('/profile/edit'),
                              ).animate().fadeIn(delay: 180.ms),
                              const SizedBox(height: 20),
                            ],

                            // ── Menu principal ──────────────────────────
                            _MenuSection(
                              children: [
                                if (isTraveler)
                                  _MenuItem(
                                    icon: Icons.flight_takeoff_rounded,
                                    iconColor: DonyColors.blue400,
                                    label: 'Mes trajets',
                                    trailing: upcomingAnnouncements > 0
                                        ? '$upcomingAnnouncements à venir'
                                        : null,
                                    onTap: () =>
                                        context.push('/announcements'),
                                  ),
                                if (isSender)
                                  _MenuItem(
                                    icon: Icons.inventory_2_outlined,
                                    iconColor: const Color(0xFFE67E22),
                                    label: 'Mes envois',
                                    trailing: activeBids > 0
                                        ? '$activeBids en cours'
                                        : null,
                                    onTap: () =>
                                        context.push('/announcements'),
                                  ),
                                if (isTraveler)
                                  _MenuItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    iconColor: const Color(0xFF16A34A),
                                    label: 'Recevoir mes paiements',
                                    onTap: () =>
                                        context.push('/payments/onboarding'),
                                  ),
                                _MenuItem(
                                  icon: Icons.credit_card_outlined,
                                  iconColor: const Color(0xFF8E44AD),
                                  label: 'Paiements & factures',
                                  onTap: () {},
                                ),
                                _MenuItem(
                                  icon: Icons.badge_outlined,
                                  iconColor: DonyColors.blue400,
                                  label: 'Documents KYC',
                                  trailing:
                                      isKycVerified ? 'Vérifié' : null,
                                  trailingColor:
                                      isKycVerified ? DonyColors.success : null,
                                  onTap: () => context.push('/kyc'),
                                ),
                                _MenuItem(
                                  icon: Icons.people_outline_rounded,
                                  iconColor: const Color(0xFF27AE60),
                                  label: 'Parrainages',
                                  trailing: '0 invité',
                                  isLast: true,
                                  onTap: () {},
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideY(
                                    begin: 0.04,
                                    curve: Curves.easeOutCubic),
                            const SizedBox(height: 16),

                            // ── Menu settings ───────────────────────────
                            _MenuSection(
                              children: [
                                _MenuItem(
                                  icon: Icons.notifications_outlined,
                                  iconColor: const Color(0xFFF59E0B),
                                  label: 'Notifications',
                                  onTap: () {},
                                ),
                                _MenuItem(
                                  icon: Icons.language_rounded,
                                  iconColor: DonyColors.blue400,
                                  label: 'Langue',
                                  trailing: 'Français',
                                  onTap: () {},
                                ),
                                _MenuItem(
                                  icon: Icons.lock_outline_rounded,
                                  iconColor: DonyColors.grey400,
                                  label: 'Sécurité & confidentialité',
                                  onTap: () {},
                                ),
                                _MenuItem(
                                  icon: Icons.help_outline_rounded,
                                  iconColor: DonyColors.grey400,
                                  label: 'Aide & support',
                                  isLast: true,
                                  onTap: () {},
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 240.ms)
                                .slideY(
                                    begin: 0.04,
                                    curve: Curves.easeOutCubic),
                            const SizedBox(height: 28),

                            // ── Déconnexion ─────────────────────────────
                            GestureDetector(
                              onTap: () => context
                                  .read<AuthBloc>()
                                  .add(const AuthLogoutRequested()),
                              child: Text(
                                'Se déconnecter',
                                style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: DonyColors.error,
                                ),
                              ),
                            ).animate().fadeIn(delay: 280.ms),
                            const SizedBox(height: 32),

                            // ── Footer ──────────────────────────────────
                            Text(
                              'dony v1.0.0 · Made with ❤️ in Paris',
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: DonyColors.grey200,
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

  Widget _buildAvatar(String initials, bool isKycVerified) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DonyColors.blue600, DonyColors.blue400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: DonyColors.blue400.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (isKycVerified)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: DonyColors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: DonyColors.success, size: 20),
          ),
      ],
    );
  }
}

// ── Profile completion banner ─────────────────────────────────────────────────

class _ProfileCompletionBanner extends StatelessWidget {
  const _ProfileCompletionBanner({
    required this.user,
    required this.onTap,
  });

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = user.profileCompletionSteps;
    final total = UserModel.profileTotalSteps;

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DonyColors.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DonyColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: DonyColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: DonyColors.warning, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil incomplet',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DonyColors.dark900,
                        ),
                      ),
                      Text(
                        '${(completed / total * 100).round()}% complété · Compléter maintenant',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          color: DonyColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: DonyColors.grey200, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completed / total,
                backgroundColor: DonyColors.grey100,
                valueColor: const AlwaysStoppedAnimation<Color>(DonyColors.warning),
                minHeight: 5,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    missing.map((m) => _MissingChip(label: m)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DonyColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: DonyColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_rounded, color: DonyColors.warning, size: 12),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 11,
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
    required this.totalAnnouncements,
    required this.isLoading,
  });

  final bool isTraveler;
  final int totalBids;
  final int totalAnnouncements;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final String stat1Value;
    final String stat1Label;
    final String stat3Value;
    final String stat3Label;

    if (isTraveler) {
      stat1Value = isLoading ? '—' : '$totalAnnouncements';
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Row(
        children: [
          Expanded(
              child: _StatItem(value: stat1Value, label: stat1Label)),
          Container(width: 1, height: 32, color: DonyColors.grey100),
          const Expanded(
              child: _StatItem(value: '4.9', label: 'Ma note')),
          Container(width: 1, height: 32, color: DonyColors.grey100),
          Expanded(
              child: _StatItem(value: stat3Value, label: stat3Label)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: DonyColors.dark900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 12,
            color: DonyColors.grey400,
          ),
        ),
      ],
    );
  }
}

// ── Menu section ──────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.trailingColor,
    this.isLast = false,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? trailing;
  final Color? trailingColor;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: DonyColors.dark900,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing!,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: trailingColor ?? DonyColors.grey400,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: DonyColors.grey200,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 66),
            child: Divider(height: 1),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
