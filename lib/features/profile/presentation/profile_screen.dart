import 'package:dony/app/theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final phone = user?.phoneNumber ?? '';
        final isKycVerified = user?.isKycVerified ?? false;
        final isTraveler = user?.isTraveler ?? false;
        final isSender = user?.isSender ?? false;

        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            title: Text(
              'Mon profil',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            backgroundColor: kSurface,
            elevation: 0,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Column(
              children: [
                _buildAvatar(phone, isKycVerified)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 10),
                _buildRoleBadges(isTraveler, isSender)
                    .animate()
                    .fadeIn(delay: 120.ms),
                const SizedBox(height: 32),
                _buildSection(
                  title: 'Vérification',
                  children: [
                    _buildInfoTile(
                      icon: Icons.shield_outlined,
                      label: 'Identité',
                      value: isKycVerified ? 'Vérifiée' : 'Non vérifiée',
                      valueColor: isKycVerified ? kSuccess : kWarning,
                      trailing: isKycVerified
                          ? const Icon(Icons.verified_rounded, color: kSuccess, size: 18)
                          : null,
                    ),
                  ],
                ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Compte',
                  children: [
                    _buildInfoTile(
                      icon: Icons.phone_outlined,
                      label: 'Téléphone',
                      value: phone,
                    ),
                    const Divider(height: 1, indent: 52),
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Rôle',
                      value: _roleLabel(isTraveler, isSender),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),
                _buildLogoutButton(context)
                    .animate()
                    .fadeIn(delay: 260.ms)
                    .slideY(begin: 0.04, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String phone, bool isKycVerified) {
    final initials = phone.isNotEmpty ? phone.replaceAll('+', '').substring(0, 2) : '??';
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

  Widget _buildRoleBadges(bool isTraveler, bool isSender) {
    return Wrap(
      spacing: 8,
      children: [
        if (isTraveler)
          _Badge(
            icon: Icons.flight_takeoff_rounded,
            label: 'Voyageur',
            color: kGreenPrimary,
          ),
        if (isSender)
          _Badge(
            icon: Icons.send_rounded,
            label: 'Expéditeur',
            color: const Color(0xFF0F4C75),
          ),
        if (!isTraveler && !isSender)
          _Badge(
            icon: Icons.person_outline_rounded,
            label: 'Utilisateur',
            color: kTextSecondary,
          ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kTextSecondary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? kTextPrimary,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
        icon: const Icon(Icons.logout_rounded, size: 18, color: kError),
        label: Text(
          'Se déconnecter',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kError,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kError, width: 1.5),
          foregroundColor: kError,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  String _roleLabel(bool isTraveler, bool isSender) {
    if (isTraveler && isSender) return 'Voyageur & Expéditeur';
    if (isTraveler) return 'Voyageur';
    if (isSender) return 'Expéditeur';
    return 'Non défini';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}