import 'dart:async';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran de consentement analytics affiché une seule fois,
/// après le PIN setup lors de l'inscription.
/// Les deux choix (accepter / refuser) naviguent vers /home.
class AnalyticsConsentScreen extends StatelessWidget {
  const AnalyticsConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: Column(
              children: [
                const SizedBox(height: DonySpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: DonyStepPill(current: 4, total: 4, label: 'Préférences'),
                ),
                const Spacer(flex: 2),
                _Header(cs: cs, tt: tt),
                const Spacer(flex: 2),
                _ConsentPoints(cs: cs, tt: tt),
                const Spacer(flex: 3),
                _Buttons(bottom: bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DonyMascotteAnimated(
          type: DonyMascotteType.joyeux,
          size: DonyMascotteSize.md,
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Une dernière chose',
          style: tt.headlineLarge?.copyWith(color: cs.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          "Pour améliorer dony, on aimerait mesurer comment\nl'app est utilisée. C'est anonyme et facultatif.",
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

class _ConsentPoints extends StatelessWidget {
  const _ConsentPoints({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final points = [
      ('📊', 'Écrans visités et fonctionnalités utilisées'),
      ('👆', 'Gestes pour repérer ce qui bloque'),
      ('🔒', 'Jamais tes paiements, KYC ou numéro'),
      ('↩️', 'Modifiable à tout moment dans Réglages'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        children: [
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0)
              Divider(height: DonySpacing.lg, color: cs.outline),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(points[i].$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    points[i].$2,
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
  const _Buttons({required this.bottom});
  final double bottom;

  Future<void> _respond(BuildContext context, {required bool granted}) async {
    await getIt<AnalyticsService>().setConsent(granted: granted);
    unawaited(getIt<AnalyticsService>().logEvent(
      AnalyticsEvents.analyticsConsentAnswered,
      properties: {'granted': granted},
    ));
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DonyButton(
          label: 'Accepter',
          onPressed: () => _respond(context, granted: true),
        ),
        const SizedBox(height: DonySpacing.md),
        DonyButton(
          label: 'Non merci',
          variant: DonyButtonVariant.ghost,
          onPressed: () => _respond(context, granted: false),
        ),
        SizedBox(height: DonySpacing.xxl + bottom),
      ],
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}
