import 'dart:async';
import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Nombre de pages du carrousel, lu hors d'un `build` (indicateur,
  /// dernière page). Doit rester égal à la longueur de [_pages].
  static const _pageCount = 4;

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
    final cs = Theme.of(context).colorScheme;
    final pages = _pages(context.l10n);
    assert(
      pages.length == _pageCount,
      'Mettre _pageCount à jour', // i18n-ignore
    );
    return Scaffold(
      backgroundColor: cs.surface,
      body: ValueListenableBuilder<int>(
        valueListenable: _currentPage,
        builder: (context, page, _) => Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (page) => _currentPage.value = page,
              itemBuilder: (context, index) =>
                  _OnboardingPhotoPage(data: pages[index], pageIndex: index),
            ),
            _OnboardingTopBar(
              showSkip: page < _pageCount - 1,
              onSkip: _proceed,
            ),
            _OnboardingFooter(
              currentPage: _currentPage,
              onNext: _nextPage,
              onProceed: _proceed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Les quatre pages du carrousel, dans l'ordre, traduites par [l].
List<_OnboardingPageData> _pages(AppLocalizations l) => [
  _OnboardingPageData(
    imageAsset: 'assets/illustrations/onboarding-handoff.png',
    eyebrow: l.authOnboardingHandoffEyebrow,
    title: l.authOnboardingHandoffTitle,
    subtitle: l.authOnboardingHandoffSubtitle,
    placement: _CopyPlacement.top,
    steps: [
      _JourneyStep(
        number: '1',
        title: l.authOnboardingHandoffStep1Title,
        subtitle: l.authOnboardingHandoffStep1Subtitle,
      ),
      _JourneyStep(
        number: '2',
        title: l.authOnboardingHandoffStep2Title,
        subtitle: l.authOnboardingHandoffStep2Subtitle,
      ),
      _JourneyStep(
        number: '3',
        title: l.authOnboardingHandoffStep3Title,
        subtitle: l.authOnboardingHandoffStep3Subtitle,
      ),
    ],
  ),
  _OnboardingPageData(
    imageAsset: 'assets/illustrations/onboarding-security.png',
    eyebrow: l.authOnboardingSecurityEyebrow,
    title: l.authOnboardingSecurityTitle,
    subtitle: l.authOnboardingSecuritySubtitle,
    placement: _CopyPlacement.middle,
    chips: [
      l.authOnboardingChipVerifiedIdentity,
      l.authOnboardingChipPaymentOnHold,
      l.authOnboardingChipTrackingQr,
      l.authOnboardingChipProofOfDropOff,
    ],
  ),
  _OnboardingPageData(
    imageAsset: 'assets/illustrations/onboarding-tracking.png',
    eyebrow: l.authOnboardingTrackingEyebrow,
    title: l.authOnboardingTrackingTitle,
    subtitle: l.authOnboardingTrackingSubtitle,
    placement: _CopyPlacement.top,
    showRoute: true,
    steps: [
      _JourneyStep(
        number: '1',
        title: l.authOnboardingTrackingStep1Title,
        subtitle: l.authOnboardingTrackingStep1Subtitle,
      ),
      _JourneyStep(
        number: '2',
        title: l.authOnboardingTrackingStep2Title,
        subtitle: l.authOnboardingTrackingStep2Subtitle,
      ),
      _JourneyStep(
        number: '3',
        title: l.authOnboardingTrackingStep3Title,
        subtitle: l.authOnboardingTrackingStep3Subtitle,
      ),
    ],
  ),
  _OnboardingPageData(
    imageAsset: 'assets/illustrations/onboarding-destinations.png',
    eyebrow: l.authOnboardingDestinationsEyebrow,
    title: l.authOnboardingDestinationsTitle,
    subtitle: l.authOnboardingDestinationsSubtitle,
    placement: _CopyPlacement.top,
    steps: [
      _JourneyStep(
        number: '6',
        title: l.authOnboardingDestinationsStep6Title,
        subtitle: l.authOnboardingDestinationsStep6Subtitle,
      ),
      _JourneyStep(
        number: '7',
        title: l.authOnboardingDestinationsStep7Title,
        subtitle: l.authOnboardingDestinationsStep7Subtitle,
      ),
    ],
    chips: [
      l.countryZoneEurope,
      l.authOnboardingChipAfrica,
      l.authOnboardingChipAvailableCountries,
    ],
  ),
];

class _OnboardingPhotoPage extends StatelessWidget {
  const _OnboardingPhotoPage({required this.data, required this.pageIndex});

  final _OnboardingPageData data;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 640;
        final h = DonyLayout.hPadding(
          context,
        ).clamp(DonySpacing.base, DonySpacing.xl);
        final top = media.padding.top + (compact ? 70.0 : 88.0);
        final bottom = media.padding.bottom + (compact ? 102.0 : 128.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            _BackgroundImage(asset: data.imageAsset),
            const _ImageScrim(),
            Positioned(
              left: h,
              right: h,
              top: data.placement == _CopyPlacement.top ? top : null,
              bottom: data.placement == _CopyPlacement.middle
                  ? (constraints.maxHeight * 0.40).clamp(210.0, 330.0)
                  : null,
              child: _HeroCopy(data: data, compact: compact)
                  .animate(target: reduceMotion ? 0 : 1)
                  .fadeIn(duration: DonyDuration.slow)
                  .slideY(
                    begin: 0.05,
                    duration: DonyDuration.slow,
                    curve: DonyCurve.enter,
                  ),
            ),
            Positioned(
              left: h,
              right: h,
              bottom: bottom,
              child: _JourneyCard(data: data, compact: compact)
                  .animate(target: reduceMotion ? 0 : 1)
                  .fadeIn(
                    delay: (80 + pageIndex * 20).ms,
                    duration: DonyDuration.slow,
                  )
                  .slideY(
                    begin: 0.04,
                    duration: DonyDuration.slow,
                    curve: DonyCurve.enter,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      semanticLabel: context.l10n.authOnboardingImageLabel,
    );
  }
}

class _ImageScrim extends StatelessWidget {
  const _ImageScrim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.scrim.withValues(alpha: isDark ? 0.58 : 0.44),
            cs.scrim.withValues(alpha: isDark ? 0.16 : 0.08),
            cs.scrim.withValues(alpha: isDark ? 0.34 : 0.24),
            cs.scrim.withValues(alpha: isDark ? 0.88 : 0.76),
          ],
          stops: const [0, 0.34, 0.58, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomCenter,
            radius: 0.9,
            colors: [
              cs.primary.withValues(alpha: isDark ? 0.28 : 0.22),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(
      context,
    ).clamp(DonySpacing.base, DonySpacing.xl);

    return Positioned(
      left: h,
      right: h,
      top: media.padding.top + DonySpacing.sm,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.24)),
                ),
                child: const Center(child: DonyLogo(fontSize: 24)),
              ),
            ),
          ),
          const Spacer(),
          if (showSkip)
            _GlassButton(
              label: context.l10n.authOnboardingSkip,
              onPressed: onSkip,
            )
          else
            const SizedBox(width: 72, height: 44),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(72, 44),
            foregroundColor: cs.onPrimary,
            backgroundColor: cs.primary.withValues(alpha: 0.72),
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DonyRadius.full),
              side: BorderSide(color: cs.onPrimary.withValues(alpha: 0.18)),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.data, required this.compact});

  final _OnboardingPageData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final titleSize = compact ? 26.0 : 31.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Eyebrow(label: data.eyebrow),
        const SizedBox(height: DonySpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            data.title,
            style: tt.displayLarge?.copyWith(
              color: cs.onPrimary,
              fontSize: titleSize,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              shadows: [
                Shadow(
                  color: DonyColors.neutral900.withValues(alpha: 0.42),
                  blurRadius: 18,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            data.subtitle,
            style: tt.bodyLarge?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.88),
              fontSize: compact ? 13 : 14,
              height: 1.38,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: DonyColors.neutral900.withValues(alpha: 0.42),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            border: Border.all(color: cs.onPrimary.withValues(alpha: 0.20)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.data, required this.compact});

  final _OnboardingPageData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.all(compact ? DonySpacing.md : DonySpacing.base),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withValues(alpha: 0.72)
                : cs.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            border: Border.all(
              color: cs.outline.withValues(alpha: isDark ? 0.20 : 0.28),
            ),
            boxShadow: isDark ? DonyShadow.md : DonyShadow.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.showRoute) ...[
                const _RouteProgress(),
                const SizedBox(height: DonySpacing.sm),
              ],
              if (data.steps.isNotEmpty)
                _JourneySteps(steps: data.steps, compact: compact),
              if (data.chips.isNotEmpty) ...[
                if (data.steps.isNotEmpty)
                  const SizedBox(height: DonySpacing.sm),
                _ChipWrap(chips: data.chips),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteProgress extends StatelessWidget {
  const _RouteProgress();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: List.generate(5, (index) {
            final active = index <= 2;
            return Expanded(
              child: Row(
                children: [
                  _RoutePin(active: active),
                  if (index < 4)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: (index < 2 ? cs.primary : cs.outline).withValues(
                          alpha: index < 2 ? 0.86 : 0.42,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: [
            Expanded(
              child: _RouteLabel(
                l10n.authOnboardingRouteDropOff,
                align: TextAlign.left,
              ),
            ),
            Expanded(child: _RouteLabel(l10n.authOnboardingRouteDeparture)),
            Expanded(child: _RouteLabel(l10n.authOnboardingRouteTransit)),
            Expanded(child: _RouteLabel(l10n.authOnboardingRouteArrival)),
            Expanded(
              child: _RouteLabel(
                l10n.authOnboardingRouteDelivery,
                align: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoutePin extends StatelessWidget {
  const _RoutePin({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? cs.success : cs.surface;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), spreadRadius: 5),
        ],
      ),
    );
  }
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel(this.label, {this.align = TextAlign.center});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _JourneySteps extends StatelessWidget {
  const _JourneySteps({required this.steps, required this.compact});

  final List<_JourneyStep> steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps
          .map(
            (step) => Padding(
              padding: EdgeInsets.only(
                bottom: step == steps.last ? 0 : DonySpacing.sm,
              ),
              child: _JourneyStepRow(step: step, compact: compact),
            ),
          )
          .toList(),
    );
  }
}

class _JourneyStepRow extends StatelessWidget {
  const _JourneyStepRow({required this.step, required this.compact});

  final _JourneyStep step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 24 : 28,
          height: compact ? 24 : 28,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Center(
            child: Text(
              step.number,
              style: tt.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontSize: compact ? 13 : null,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                step.subtitle,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: compact ? 11 : 12,
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.chips});

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: DonySpacing.xs,
        runSpacing: DonySpacing.xs,
        children: chips.map((chip) => _OnboardingChip(label: chip)).toList(),
      ),
    );
  }
}

class _OnboardingChip extends StatelessWidget {
  const _OnboardingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

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
    final media = MediaQuery.of(context);
    final h = DonyLayout.hPadding(
      context,
    ).clamp(DonySpacing.base, DonySpacing.xl);

    return Positioned(
      left: h,
      right: h,
      bottom: media.padding.bottom + DonySpacing.base,
      child: ValueListenableBuilder<int>(
        valueListenable: currentPage,
        builder: (context, page, _) {
          final isLast = page == _OnboardingScreenState._pageCount - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyStepIndicator(
                total: _OnboardingScreenState._pageCount,
                current: page,
              ),
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                label: isLast
                    ? context.l10n.authOnboardingGetStarted
                    : context.l10n.authOnboardingNext,
                onPressed: isLast ? onProceed : onNext,
              ),
              if (isLast) ...[
                const SizedBox(height: DonySpacing.sm),
                const _LegalFooter(),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Mention légale du bas de l'onboarding.
///
/// Même défaut que sur l'écran de connexion : les deux libellés étaient
/// soulignés sans porter de `recognizer`, donc inertes au toucher.
class _LegalFooter extends StatefulWidget {
  const _LegalFooter();

  @override
  State<_LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<_LegalFooter> {
  /// Libéré à la main : construit dans `build()`, il fuirait à chaque
  /// reconstruction du carrousel.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/terms'));
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/privacy'));

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final linkStyle = tt.bodySmall?.copyWith(
      color: cs.onPrimary,
      decoration: TextDecoration.underline,
      decorationColor: cs.onPrimary,
    );
    return Text.rich(
      TextSpan(
        text: l10n.authOnboardingLegalPrefix,
        style: tt.bodySmall?.copyWith(
          color: cs.onPrimary.withValues(alpha: 0.78),
          height: 1.3,
        ),
        children: [
          TextSpan(
            text: l10n.authOnboardingLegalTermsLink,
            style: linkStyle,
            recognizer: _termsTap,
          ),
          TextSpan(text: l10n.authOnboardingLegalMiddle),
          TextSpan(
            text: l10n.authOnboardingLegalPrivacyLink,
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

enum _CopyPlacement { top, middle }

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.imageAsset,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.placement,
    this.steps = const [],
    this.chips = const [],
    this.showRoute = false,
  });

  final String imageAsset;
  final String eyebrow;
  final String title;
  final String subtitle;
  final _CopyPlacement placement;
  final List<_JourneyStep> steps;
  final List<String> chips;
  final bool showRoute;
}

class _JourneyStep {
  const _JourneyStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;
}
