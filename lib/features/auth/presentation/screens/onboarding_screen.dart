import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _features = [
    (Icons.verified_user_outlined, 'Vérifié', 'KYC + selfie animé pour chaque profil'),
    (Icons.qr_code_2_outlined, 'Tracé', 'QR scanné à chaque étape, jusqu\'à la remise'),
    (Icons.lock_outline_rounded, 'Garanti', 'Paiement bloqué, libéré seulement à l\'arrivée'),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DonyColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg, DonySpacing.xxl, DonySpacing.lg, DonySpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo dony
                    const DonyLogo(fontSize: 36),
                    const SizedBox(height: DonySpacing.xxl),

                    // Headline — "Envoyez un colis"
                    Text(
                      'Envoyez un colis',
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DonyColors.ink900,
                        letterSpacing: -0.5,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                    const SizedBox(height: DonySpacing.xxs),

                    // Second line — "chez vous, autrement."
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: 'chez vous',
                          style: DonyTypography.caveat(
                            fontSize: 26,
                            color: DonyColors.green400,
                          ),
                        ),
                        TextSpan(
                          text: ', autrement.',
                          style: tt.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DonyColors.ink900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ]),
                    ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                    const SizedBox(height: DonySpacing.base),

                    // Subtitle
                    Text(
                      'Voyageurs vérifiés. Suivi en temps réel. Et le sourire de votre famille à l\'arrivée.',
                      style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: DonySpacing.xl),

                    // Feature cards
                    ..._features.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                      child: _FeatureCard(
                        icon: e.value.$1,
                        title: e.value.$2,
                        subtitle: e.value.$3,
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 120 + e.key * 60))
                          .slideX(begin: 0.04),
                    )),
                  ],
                ),
              ),
            ),

            // Pinned bottom CTAs + footer
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary CTA
                  DonyButton(
                    label: 'J\'envoie un colis',
                    onPressed: () {
                      context.read<AuthBloc>().add(const OnboardingCompleted());
                      context.go('/auth/phone');
                    },
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: DonySpacing.sm),

                  // Ghost CTA
                  DonyButton(
                    label: 'Je suis voyageur',
                    onPressed: () {
                      context.read<AuthBloc>().add(const OnboardingCompleted());
                      context.go('/auth/phone');
                    },
                    variant: DonyButtonVariant.ghost,
                  ).animate().fadeIn(delay: 340.ms),

                  const SizedBox(height: DonySpacing.base),

                  // CGU footer
                  Text.rich(
                    TextSpan(
                      text: 'En continuant vous acceptez nos ',
                      style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                      children: [
                        TextSpan(
                          text: 'CGU',
                          style: tt.bodySmall?.copyWith(
                            color: DonyColors.green400,
                            decoration: TextDecoration.underline,
                            decorationColor: DonyColors.green400,
                          ),
                        ),
                        const TextSpan(text: ' et notre '),
                        TextSpan(
                          text: 'politique de confidentialité',
                          style: tt.bodySmall?.copyWith(
                            color: DonyColors.green400,
                            decoration: TextDecoration.underline,
                            decorationColor: DonyColors.green400,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 380.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: DonySpacing.icon,
            height: DonySpacing.icon,
            decoration: BoxDecoration(
              color: DonyColors.green50,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Icon(icon, size: DonySpacing.iconSm, color: DonyColors.green400),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(color: DonyColors.ink900),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
