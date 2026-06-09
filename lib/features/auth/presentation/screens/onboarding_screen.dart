import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _features = [
    (
      Icons.verified_user_outlined,
      'Vérifié',
      'KYC + selfie animé pour chaque profil',
    ),
    (
      Icons.qr_code_2_outlined,
      'Tracé',
      'QR scanné à chaque étape, jusqu\'à la remise',
    ),
    (
      Icons.lock_outline_rounded,
      'Garanti',
      'Paiement bloqué, libéré seulement à l\'arrivée',
    ),
  ];

  void _proceed(BuildContext context) {
    context.go('/auth/method');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Column(
            children: [
              // ── Scrollable content ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    h,
                    DonySpacing.xxl,
                    h,
                    DonySpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyMascotteAnimated(
                        type: DonyMascotteType.joyeux,
                        size: DonyMascotteSize.lg,
                      ),
                      const SizedBox(height: DonySpacing.lg),
                      const DonyLogo(fontSize: 48),
                      const SizedBox(height: DonySpacing.xxl),

                      // Headline
                      Text(
                            'Envoyez un colis',
                            style: tt.displayLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.8,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                      const SizedBox(height: DonySpacing.xxs),

                      // Tagline "chez vous, autrement."
                      Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'chez vous',
                                  style: DonyTypography.caveat(
                                    fontSize: 28,
                                    color: cs.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: ', autrement.',
                                  style: tt.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 60.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                      const SizedBox(height: DonySpacing.base),

                      Text(
                        'Voyageurs vérifiés. Suivi en temps réel. Et le sourire de votre famille à l\'arrivée.',
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: DonySpacing.xl),

                      // Feature cards
                      ..._features.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: DonySpacing.sm,
                          ),
                          child:
                              _FeatureCard(
                                    icon: e.value.$1,
                                    title: e.value.$2,
                                    subtitle: e.value.$3,
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(
                                      milliseconds: 140 + e.key * 60,
                                    ),
                                  )
                                  .slideX(begin: 0.03),
                        ),
                      ),

                      const SizedBox(height: DonySpacing.lg),
                    ],
                  ),
                ),
              ),

              // ── Pinned CTA ─────────────────────────────────────────────
              _OnboardingFooter(onProceed: () => _proceed(context)),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadow.xs,
      ),
      child: Row(
        children: [
          Container(
            width: DonySpacing.icon,
            height: DonySpacing.icon,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Icon(icon, size: DonySpacing.iconSm, color: cs.primary),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
  const _OnboardingFooter({required this.onProceed});
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        DonySpacing.md + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(label: 'Commencer', onPressed: onProceed)
              .animate()
              .fadeIn(delay: 320.ms)
              .slideY(begin: 0.05, curve: Curves.easeOutCubic),

          const SizedBox(height: DonySpacing.md),

          Text.rich(
            TextSpan(
              text: 'En continuant vous acceptez nos ',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              children: [
                TextSpan(
                  text: 'CGU',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.primary,
                  ),
                ),
                const TextSpan(text: ' et notre '),
                TextSpan(
                  text: 'politique de confidentialité',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.primary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 360.ms),
        ],
      ),
    );
  }
}
