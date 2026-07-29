import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _features = [
    (
      'shield-check',
      'Vérifié',
      'Vérification d\'identité + selfie animé pour chaque profil',
    ),
    ('qr-code', 'Tracé', 'QR lu à chaque étape, jusqu\'à la remise'),
    ('lock', 'Garanti', 'Paiement bloqué, libéré seulement à l\'arrivée'),
  ];

  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier(0);

  @override
  void dispose() {
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  void _proceed() {
    context.go('/auth/method');
  }

  Future<void> _nextPage() => _pageController.nextPage(
    duration: DonyDuration.base,
    curve: DonyCurve.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Column(
            children: [
              _OnboardingHeader(currentPage: _currentPage, onSkip: _proceed),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => _currentPage.value = page,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: h),
                      child: const _HookPage(),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: h),
                      child: const _BenefitsPage(features: _features),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: h),
                      child: const _TrustPage(),
                    ),
                  ],
                ),
              ),
              _OnboardingFooter(
                currentPage: _currentPage,
                onNext: _nextPage,
                onProceed: _proceed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.currentPage, required this.onSkip});

  final ValueListenable<int> currentPage;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: h),
        child: Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<int>(
            valueListenable: currentPage,
            builder: (_, page, _) => page < 2
                ? TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(72, 44),
                    ),
                    child: const Text('Passer'),
                  )
                : const SizedBox(width: 72, height: 44),
          ),
        ),
      ),
    );
  }
}

class _HookPage extends StatelessWidget {
  const _HookPage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 480;
        final mascotSize = (constraints.maxHeight * (compact ? 0.23 : 0.35))
            .clamp(compact ? 88.0 : 128.0, compact ? 112.0 : 240.0)
            .toDouble();
        final headlineStyle = tt.displayLarge?.copyWith(
          fontSize: compact ? 26 : null,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
          letterSpacing: -0.8,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyMascotteAnimated(
              type: DonyMascotteType.bienvenue,
              customDimension: mascotSize,
            ),
            SizedBox(height: compact ? DonySpacing.sm : DonySpacing.xl),
            Text(
              'Envoyez un colis',
              style: headlineStyle,
              textAlign: TextAlign.center,
            ).animate().fadeIn().slideY(
              begin: 0.04,
              curve: Curves.easeOutCubic,
            ),
            const SizedBox(height: DonySpacing.xxs),
            Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'chez vous',
                        style: DonyTypography.caveat(
                          fontSize: compact ? 25 : 28,
                          color: cs.primary,
                        ),
                      ),
                      TextSpan(text: ', autrement.', style: headlineStyle),
                    ],
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 60.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
            SizedBox(height: compact ? DonySpacing.sm : DonySpacing.base),
            Text(
              'Voyageurs vérifiés. Suivi en temps réel. Et le sourire de votre famille à l\'arrivée.',
              style: tt.bodyLarge?.copyWith(
                fontSize: compact ? 14 : null,
                color: cs.onSurfaceVariant,
                height: compact ? 1.35 : 1.55,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms),
          ],
        );
      },
    );
  }
}

class _BenefitsPage extends StatelessWidget {
  const _BenefitsPage({required this.features});

  final List<(String, String, String)> features;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 480;
        final mascotSize = (constraints.maxHeight * (compact ? 0.18 : 0.22))
            .clamp(compact ? 56.0 : 72.0, compact ? 72.0 : 120.0)
            .toDouble();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyMascotteAnimated(
              type: DonyMascotteType.securise,
              customDimension: mascotSize,
            ),
            SizedBox(height: compact ? DonySpacing.xs : DonySpacing.md),
            Text(
              'Pourquoi voyager en confiance ?',
              style: tt.headlineSmall?.copyWith(
                fontSize: compact ? 18 : null,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: compact ? DonySpacing.xs : DonySpacing.lg),
            ...features.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child:
                    _FeatureCard(
                          iconAsset: entry.value.$1,
                          title: entry.value.$2,
                          subtitle: entry.value.$3,
                          compact: compact,
                        )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 60 + entry.key * 60),
                        )
                        .slideX(begin: 0.03),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrustPage extends StatelessWidget {
  const _TrustPage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 440;
        final mascotSize = (constraints.maxHeight * (compact ? 0.23 : 0.3))
            .clamp(compact ? 72.0 : 112.0, compact ? 96.0 : 180.0)
            .toDouble();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyMascotteAnimated(
              type: DonyMascotteType.confiant,
              customDimension: mascotSize,
            ),
            SizedBox(height: compact ? DonySpacing.sm : DonySpacing.xl),
            Text(
              'Votre colis, entre de bonnes mains.',
              style: tt.displayLarge?.copyWith(
                fontSize: compact ? 25 : null,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.8,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: compact ? DonySpacing.sm : DonySpacing.base),
            Text(
              'Yadony vous accompagne à chaque étape, du départ jusqu\'aux retrouvailles.',
              style: tt.bodyLarge?.copyWith(
                fontSize: compact ? 14 : null,
                color: cs.onSurfaceVariant,
                height: compact ? 1.35 : 1.55,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 80.ms),
          ],
        );
      },
    );
  }
}

// ── Feature card ─────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(compact ? DonySpacing.xs : DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadow.xs,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 32 : DonySpacing.icon,
            height: compact ? 32 : DonySpacing.icon,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: DonyIcon(
              iconAsset,
              size: compact ? 18 : DonySpacing.iconSm,
              color: cs.primary,
            ),
          ),
          SizedBox(width: compact ? DonySpacing.sm : DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontSize: compact ? 13 : null,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: compact ? 0 : DonySpacing.xxs),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    fontSize: compact ? 12 : null,
                    height: compact ? 1.2 : null,
                    color: cs.onSurfaceVariant,
                  ),
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
  const _OnboardingFooter({
    required this.currentPage,
    required this.onNext,
    required this.onProceed,
  });

  final ValueListenable<int> currentPage;
  final VoidCallback onNext;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<int>(
      valueListenable: currentPage,
      builder: (context, page, _) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: cs.outline)),
        ),
        padding: EdgeInsets.fromLTRB(
          h,
          DonySpacing.md,
          h,
          DonySpacing.md + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyStepIndicator(total: 3, current: page),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              label: page == 2 ? 'Commencer' : 'Suivant',
              onPressed: page == 2 ? onProceed : onNext,
            ),
            if (page == 2) ...[
              const SizedBox(height: DonySpacing.md),
              const _LegalFooter(),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text.rich(
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
    ).animate().fadeIn(duration: 300.ms);
  }
}
