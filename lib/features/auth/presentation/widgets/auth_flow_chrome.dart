import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

class AuthFlowBackground extends StatelessWidget {
  const AuthFlowBackground({super.key});

  static const imageAsset = 'assets/illustrations/auth-login-security.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          opacity: AlwaysStoppedAnimation(isLight ? 0.24 : 0.48),
          semanticLabel: 'Connexion sécurisée Yadony',
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? [
                      cs.surface.withValues(alpha: 0.92),
                      cs.primaryContainer.withValues(alpha: 0.70),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.96),
                    ]
                  : [
                      DonyColors.ink900.withValues(alpha: 0.76),
                      DonyColors.ink900.withValues(alpha: 0.64),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.98),
                    ],
              stops: const [0, 0.40, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class AuthFlowHeader extends StatelessWidget {
  /// Tunnel pré-compte (téléphone, e-mail, code) : une pastille « n / total ».
  const AuthFlowHeader({
    super.key,
    required int this.current,
    required int this.total,
    required this.label,
    this.showBack = true,
  }) : segments = null;

  /// Parcours d'onboarding progressif : la jauge remplace la pastille.
  ///
  /// Les deux ne comptent pas la même chose. La pastille compte les écrans du
  /// tunnel d'inscription ; la jauge compte les étapes du compte (quatre ou
  /// cinq selon la couverture Stripe du pays, parrainage exclu).
  ///
  /// Pas de `showBack` ici : aucun des quatre écrans du parcours (pays,
  /// adresse, parrainage, consentement) n'affiche de retour, et aucun
  /// appelant ne l'a jamais demandé (vérifié par grep) — toujours `false`,
  /// sans paramètre pour l'exposer.
  const AuthFlowHeader.gauge({
    super.key,
    required List<DonyGaugeSegment> this.segments,
    required this.label,
  }) : current = null,
       total = null,
       showBack = false;

  final int? current;
  final int? total;
  final List<DonyGaugeSegment>? segments;
  final String label;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showBack) const DonyAppBarBackButton(),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.full),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.46),
                    ),
                  ),
                  child: const Center(child: DonyLogo(fontSize: 24)),
                ),
              ),
            ),
            const Spacer(),
            if (showBack) const SizedBox(width: kDonyMinTapTarget),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        if (segments == null)
          Align(
            alignment: Alignment.centerRight,
            child: DonyStepPill(current: current!, total: total!, label: label),
          )
        else
          // Le `Column` parent est en `CrossAxisAlignment.stretch` : la jauge
          // prend la largeur, son propre `Column` aligne le compteur à droite
          // comme le faisait la pastille.
          DonyOnboardingGauge(segments: segments!, label: label),
      ],
    );
  }
}

class AuthTrustBadge extends StatelessWidget {
  const AuthTrustBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(
          alpha: cs.brightness == Brightness.light ? 0.76 : 0.16,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('shield-check', size: 18, color: cs.success),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              'Connexion protégée',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthIntroCard extends StatelessWidget {
  const AuthIntroCard({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.body,
    this.footnote,
  });

  final String iconAsset;
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface.withValues(
          alpha: cs.brightness == Brightness.light ? 0.94 : 0.82,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        border: Border.all(color: cs.outline.withValues(alpha: 0.44)),
        boxShadow: DonyShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                ),
                child: Center(
                  child: DonyIcon(iconAsset, size: 26, color: cs.primary),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              const Expanded(child: AuthTrustBadge()),
            ],
          ),
          const SizedBox(height: DonySpacing.lg),
          Text(
            title,
            style: tt.displayLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.06,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            body,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.48,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: DonySpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('lock', size: 16, color: cs.success),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    footnote!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
