import 'dart:async';

import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/utils/dony_layout.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran plein affiché après une action majeure réussie (paiement confirmé,
/// trajet publié, livraison confirmée). Pas d'auto-navigation : l'utilisateur
/// quitte l'écran uniquement via [onCta] — ou via le bouton fermer en haut à
/// droite, qui ramène par défaut vers `/home` (voir [onClose]).
class DonySuccessScreen extends StatefulWidget {
  const DonySuccessScreen({
    super.key,
    required this.mascotteType,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.ctaVariant = DonyButtonVariant.primary,
    this.onClose,
    this.analyticsContext,
  });

  final DonyMascotteType mascotteType;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;
  final DonyButtonVariant ctaVariant;

  /// Appelé au tap sur le bouton fermer (X). Par défaut (null), navigue vers
  /// `/home` — utile pour permettre à un écran appelant de surcharger ce
  /// comportement (ex: retour vers un autre onglet).
  final VoidCallback? onClose;

  /// Slug identifiant le flux d'origine (ex: `trip_published`) — envoyé comme
  /// propriété `context` sur les events analytics de cet écran (vue,
  /// tap CTA, tap fermer). `null` = aucun tracking (écrans pas encore migrés).
  final String? analyticsContext;

  @override
  State<DonySuccessScreen> createState() => _DonySuccessScreenState();
}

class _DonySuccessScreenState extends State<DonySuccessScreen> {
  @override
  void initState() {
    super.initState();

    HapticFeedback.mediumImpact();

    _trackEvent(AnalyticsEvents.successScreenViewed);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        '${widget.title}. ${widget.subtitle}',
        TextDirection.ltr,
      );
    });
  }

  /// Envoie un event analytics best-effort — no-op silencieux si
  /// [DonySuccessScreen.analyticsContext] est `null` ou si `AnalyticsService`
  /// n'est pas enregistré dans `getIt` (tests widgets, previews).
  void _trackEvent(String name) {
    final analyticsContext = widget.analyticsContext;
    if (analyticsContext == null) return;
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        name,
        properties: {'context': analyticsContext},
      ),
    );
  }

  void _handleCtaTap() {
    _trackEvent(AnalyticsEvents.successScreenCtaTapped);
    widget.onCta();
  }

  void _handleClose(BuildContext context) {
    _trackEvent(AnalyticsEvents.successScreenClosed);
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      GoRouter.of(context).go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      // Seules sorties autorisées : le CTA et le bouton fermer (X). Le retour
      // arrière système (geste iOS / bouton Android) doit être ignoré pour
      // éviter d'exposer le formulaire sous-jacent (risque de double soumission).
      canPop: false,
      child: Scaffold(
        appBar: DonyAppBar(
          title: '',
          showBackButton: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: DonySpacing.base),
              child: Tooltip(
                message: 'Fermer',
                child: Semantics(
                  button: true,
                  label: 'Fermer',
                  child: InkWell(
                    onTap: () => _handleClose(context),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: DonySpacing.icon,
                      height: DonySpacing.icon,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surface,
                        border: Border.all(color: cs.outline),
                      ),
                      child: DonyIcon(
                        'x',
                        size: DonySpacing.iconSm,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            final h = DonyLayout.hPadding(context);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                h,
                DonySpacing.xxl,
                h,
                DonySpacing.huge,
              ),
              child: DonyLayout.constrained(
                context,
                Column(
                      children: [
                        const SizedBox(height: DonySpacing.xxl),
                        DonyMascotteAnimated(
                          type: widget.mascotteType,
                          size: DonyMascotteSize.lg,
                          withGlow: true,
                        ),
                        const SizedBox(height: DonySpacing.xl),
                        Text(
                          widget.title,
                          style: tt.displayLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: DonySpacing.md),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: tt.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xxl),
                        DonyButton(
                          label: widget.ctaLabel,
                          variant: widget.ctaVariant,
                          onPressed: _handleCtaTap,
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      curve: Curves.easeOutCubic,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}
