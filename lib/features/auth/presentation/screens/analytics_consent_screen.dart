import 'dart:async';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Première étape du parcours d'onboarding progressif, affichée juste après
/// l'inscription. `_respond` navigue vers `/auth/country-selection` : ce
/// n'est ni un écran terminal, ni un écran qui va vers `/home`.
class AnalyticsConsentScreen extends StatelessWidget {
  const AnalyticsConsentScreen({super.key, required this.progress});

  final OnboardingProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthFlowBackground(),
          SafeArea(
            child: DonyLayout.constrained(
              context,
              Padding(
                padding: EdgeInsets.fromLTRB(
                  h,
                  DonySpacing.base,
                  h,
                  DonySpacing.base + bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthFlowHeader.gauge(
                      segments: progress.segments,
                      label: 'Confidentialité',
                    ),
                    const SizedBox(height: DonySpacing.md),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(
                          bottom: DonySpacing.base,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AuthIntroCard.compact(
                                  iconAsset: 'shield-check',
                                  title: 'Une dernière chose',
                                  body:
                                      "Pour améliorer Yadony, on aimerait mesurer comment l'app est utilisée. C'est anonyme et facultatif.",
                                  footnote:
                                      'Jamais tes paiements, ton identité ou ton numéro. Tu peux changer d’avis dans Réglages.',
                                )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(
                                  begin: 0.04,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: DonySpacing.md),
                            _ConsentPoints(cs: cs, tt: tt),
                          ],
                        ),
                      ),
                    ),
                    const _Buttons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: isLight
            ? cs.surface.withValues(alpha: 0.94)
            : DonyColors.ink900.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        border: Border.all(
          color: isLight
              ? cs.outline.withValues(alpha: 0.42)
              : DonyColors.neutral0.withValues(alpha: 0.18),
        ),
        boxShadow: DonyShadow.lg,
      ),
      child: child,
    );
  }
}

class _ConsentPoint {
  const _ConsentPoint(this.icon, this.text);

  final String icon;
  final String text;
}

class _ConsentPoints extends StatelessWidget {
  const _ConsentPoints({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    const points = [
      _ConsentPoint(
        'trending-up',
        'Écrans visités et fonctionnalités utilisées',
      ),
      _ConsentPoint('search', 'Gestes pour repérer ce qui bloque'),
      _ConsentPoint('lock', 'Jamais tes paiements, identité ou numéro'),
      _ConsentPoint('refresh-cw', 'Modifiable à tout moment dans Réglages'),
    ];

    return _GlassPanel(
          child: Column(
            children: [
              for (var i = 0; i < points.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: DonySpacing.lg,
                    color: cs.outline.withValues(alpha: 0.5),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: DonyIcon(
                        points[i].icon,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Text(
                        points[i].text,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  Future<void> _respond(BuildContext context, {required bool granted}) async {
    await getIt<AnalyticsService>().setConsent(granted: granted);
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.analyticsConsentAnswered,
        properties: {'granted': granted},
      ),
    );
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.onboardingStepCompleted,
        properties: {'step': 'consent'},
      ),
    );
    if (context.mounted) context.go('/auth/country-selection');
  }

  @override
  Widget build(BuildContext context) {
    // Même zone d'action que les autres écrans du parcours : « Non merci »
    // occupe la place du lien « Passer pour l'instant » — refuser le suivi et
    // passer une étape sont la même intention, et le pouce les retrouve à la
    // même hauteur d'un écran à l'autre.
    return AuthFlowActions(
          primary: DonyButton(
            label: 'Accepter',
            iconAsset: 'shield-check',
            onPressed: () => _respond(context, granted: true),
          ),
          skipLabel: 'Non merci',
          onSkip: () => _respond(context, granted: false),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}
