import 'package:dony/app/theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthAccountDeleted) {
          context.go('/auth/phone');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : null;
          final displayName = user?.phoneNumber ?? '';
          final isKycVerified = user?.isKycVerified ?? false;
          final isTraveler = user?.isTraveler ?? false;

          return Scaffold(
            backgroundColor: kBackground,
            appBar: AppBar(
              title: Text(
                'Mon profil',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              centerTitle: true,
              backgroundColor: kSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: kTextPrimary,
                    size: 22,
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Column(
                children: [
                  // Avatar
                  _buildAvatar(displayName, isKycVerified)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 12),
                  // Nom
                  Text(
                    displayName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ).animate().fadeIn(delay: 80.ms),
                  const SizedBox(height: 10),
                  // Badges identité + rôle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isKycVerified) ...[
                        _Badge(
                          icon: Icons.verified_rounded,
                          label: 'Identité vérifiée',
                          color: kSuccess,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _Badge(
                        icon: isTraveler
                            ? Icons.flight_takeoff_rounded
                            : Icons.send_rounded,
                        label: isTraveler ? 'Voyageur' : 'Expéditeur',
                        color: kGreenPrimary,
                      ),
                    ],
                  ).animate().fadeIn(delay: 120.ms),
                  const SizedBox(height: 24),
                  // Stats
                  _StatsRow().animate().fadeIn(delay: 160.ms),
                  const SizedBox(height: 28),
                  // Menu principal
                  _MenuSection(
                    children: [
                      _MenuItem(
                        icon: Icons.inventory_2_outlined,
                        iconColor: const Color(0xFFE67E22),
                        label: 'Mes envois',
                        trailing: '3 en cours',
                        onTap: () => context.push('/announcements'),
                      ),
                      _MenuItem(
                        icon: Icons.credit_card_outlined,
                        iconColor: const Color(0xFF8E44AD),
                        label: 'Paiements & factures',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        iconColor: const Color(0xFF1E88E5),
                        label: 'Documents KYC',
                        trailing: isKycVerified ? 'Vérifié' : null,
                        trailingColor: isKycVerified ? kSuccess : null,
                        onTap: () => context.push('/kyc'),
                      ),
                      _MenuItem(
                        icon: Icons.people_outline_rounded,
                        iconColor: const Color(0xFF27AE60),
                        label: 'Parrainages',
                        trailing: '2 invités',
                        isLast: true,
                        onTap: () {},
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideY(
                    begin: 0.04,
                    curve: Curves.easeOutCubic,
                  ),
                  const SizedBox(height: 16),
                  // Menu settings
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
                        iconColor: const Color(0xFF1E88E5),
                        label: 'Langue',
                        trailing: 'Français',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        iconColor: kTextSecondary,
                        label: 'Sécurité & confidentialité',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        iconColor: kTextSecondary,
                        label: 'Aide & support',
                        isLast: true,
                        onTap: () {},
                      ),
                    ],
                  ).animate().fadeIn(delay: 240.ms).slideY(
                    begin: 0.04,
                    curve: Curves.easeOutCubic,
                  ),
                  const SizedBox(height: 28),
                  // Déconnexion
                  GestureDetector(
                    onTap: () =>
                        context.read<AuthBloc>().add(const AuthLogoutRequested()),
                    child: Text(
                      'Se déconnecter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kError,
                      ),
                    ),
                  ).animate().fadeIn(delay: 280.ms),
                  const SizedBox(height: 32),
                  // Footer
                  Text(
                    'dony v1.0.0 · Made with ❤️ in Paris',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: kTextHint,
                    ),
                  ).animate().fadeIn(delay: 320.ms),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String displayName, bool isKycVerified) {
    final initials = displayName.isNotEmpty
        ? displayName.replaceAll('+', '').substring(0, 2).toUpperCase()
        : '??';
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kGreenPrimary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (isKycVerified)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: kSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: kSuccess, size: 20),
          ),
      ],
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _StatItem(value: '12', label: 'Envois')),
          Container(width: 1, height: 32, color: kBorder),
          Expanded(child: _StatItem(value: '4.9', label: 'Ma note')),
          Container(width: 1, height: 32, color: kBorder),
          Expanded(child: _StatItem(value: '84€', label: 'Économisés')),
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Menu section ─────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: kTextPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: trailingColor ?? kTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: kTextHint,
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

// ── Badge ────────────────────────────────────────────────────────────────────

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
            style: GoogleFonts.plusJakartaSans(
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
