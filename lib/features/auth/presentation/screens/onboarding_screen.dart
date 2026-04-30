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
    (Icons.verified_user_outlined, 'Vérifié',
        'KYC + selfie animé pour chaque profil'),
    (Icons.qr_code_2_outlined, 'Tracé',
        'QR scanné à chaque étape, jusqu\'à la remise'),
    (Icons.lock_outline_rounded, 'Garanti',
        'Paiement bloqué, libéré seulement à l\'arrivée'),
  ];

  void _proceed(BuildContext context) {
    context.read<AuthBloc>().add(const OnboardingCompleted());
    context.go('/auth/phone');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      backgroundColor: DonyColors.bgApp,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Column(
            children: [
              // ── Scrollable content ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DonyLogo(fontSize: 48),
                      const SizedBox(height: DonySpacing.xxl),

                      // Headline
                      Text(
                        'Envoyez un colis',
                        style: tt.displayLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: DonyColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                      const SizedBox(height: DonySpacing.xxs),

                      // Tagline "chez vous, autrement."
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: 'chez vous',
                            style: DonyTypography.caveat(
                              fontSize: 28,
                              color: DonyColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: ', autrement.',
                            style: tt.displayLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DonyColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ]),
                      )
                          .animate()
                          .fadeIn(delay: 60.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                      const SizedBox(height: DonySpacing.base),

                      Text(
                        'Voyageurs vérifiés. Suivi en temps réel. Et le sourire de votre famille à l\'arrivée.',
                        style: tt.bodyLarge?.copyWith(
                          color: DonyColors.textMuted,
                          height: 1.55,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: DonySpacing.xl),

                      // Feature cards
                      ..._features.asMap().entries.map((e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: DonySpacing.sm),
                            child: _FeatureCard(
                              icon: e.value.$1,
                              title: e.value.$2,
                              subtitle: e.value.$3,
                            )
                                .animate()
                                .fadeIn(
                                    delay: Duration(
                                        milliseconds: 140 + e.key * 60))
                                .slideX(begin: 0.03),
                          )),

                      const SizedBox(height: DonySpacing.lg),
                    ],
                  ),
                ),
              ),

              // ── Pinned CTAs ────────────────────────────────────────────
              _OnboardingFooter(onSender: () => _proceed(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature card ─────────────────────────────────────────────────────────────

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
        color: DonyColors.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.borderDefault),
        boxShadow: DonyShadow.xs,
      ),
      child: Row(
        children: [
          Container(
            width: DonySpacing.icon,
            height: DonySpacing.icon,
            decoration: BoxDecoration(
              color: DonyColors.primarySoft,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Icon(icon, size: DonySpacing.iconSm, color: DonyColors.primary),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(color: DonyColors.textPrimary),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom CTAs + footer ──────────────────────────────────────────────────────

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({required this.onSender});
  final VoidCallback onSender;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.bgApp,
        border: Border(top: BorderSide(color: DonyColors.borderDefault)),
      ),
      padding: EdgeInsets.fromLTRB(h, DonySpacing.base, h, DonySpacing.md + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'J\'envoie un colis',
            onPressed: onSender,
          ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

          const SizedBox(height: DonySpacing.sm),

          DonyButton(
            label: 'Je suis voyageur',
            onPressed: onSender,
            variant: DonyButtonVariant.ghost,
          ).animate().fadeIn(delay: 360.ms),

          const SizedBox(height: DonySpacing.md),

          Text.rich(
            TextSpan(
              text: 'En continuant vous acceptez nos ',
              style: tt.bodySmall?.copyWith(color: DonyColors.textSubtle),
              children: [
                TextSpan(
                  text: 'CGU',
                  style: tt.bodySmall?.copyWith(
                    color: DonyColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: DonyColors.primary,
                  ),
                ),
                const TextSpan(text: ' et notre '),
                TextSpan(
                  text: 'politique de confidentialité',
                  style: tt.bodySmall?.copyWith(
                    color: DonyColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: DonyColors.primary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}
