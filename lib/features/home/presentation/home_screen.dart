import 'package:dony/app/theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final isTraveler = user?.isTraveler ?? false;
        final isKycVerified = user?.isKycVerified ?? false;

        return Scaffold(
          backgroundColor: kBackground,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, user?.phoneNumber, isKycVerified),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!isKycVerified) ...[
                      _buildKycBanner(context),
                      const SizedBox(height: 28),
                    ],
                    Text(
                      'Que souhaitez-vous faire ?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextSecondary,
                        letterSpacing: 0.5,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 14),
                    if (isTraveler)
                      _FeatureCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A6B3C), Color(0xFF2E9E5B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.flight_takeoff_rounded,
                        label: 'Mes trajets',
                        description: 'Publiez et gérez vos annonces',
                        onTap: () => context.push('/announcements'),
                        delay: 150,
                      ),
                    if (isTraveler) const SizedBox(height: 12),
                    _FeatureCard(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4C75), Color(0xFF1B6CA8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      icon: Icons.search_rounded,
                      label: 'Trouver un trajet',
                      description: 'Recherchez un voyageur disponible',
                      onTap: () => context.push('/search'),
                      delay: 200,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallFeatureCard(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scanner QR',
                            color: const Color(0xFF6C3483),
                            comingSoon: true,
                            delay: 250,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SmallFeatureCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Paiements',
                            color: const Color(0xFF1A5276),
                            comingSoon: true,
                            delay: 300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallFeatureCard(
                            icon: Icons.gavel_rounded,
                            label: 'Litiges',
                            color: const Color(0xFF922B21),
                            comingSoon: true,
                            delay: 350,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SmallFeatureCard(
                            icon: Icons.star_rounded,
                            label: 'Évaluations',
                            color: const Color(0xFF784212),
                            comingSoon: true,
                            delay: 400,
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String? phone, bool isKycVerified) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: kSurface,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: kTextSecondary),
          onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF134F2D), Color(0xFF1A6B3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'dony',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isKycVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Vérifié',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bonjour 👋',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone ?? 'Bienvenue',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKycBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/kyc'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: kWarning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vérifiez votre identité',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    'Requis pour publier un trajet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: kWarning, size: 14),
          ],
        ),
      ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final int delay;

  const _FeatureCard({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.06, curve: Curves.easeOutCubic),
    );
  }
}

class _SmallFeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool comingSoon;
  final int delay;

  const _SmallFeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    this.comingSoon = false,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Bientôt',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kTextHint,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: comingSoon ? kTextHint : kTextPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}
