import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/tokens/color_tokens.dart';
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
    this.secondaryLabel,
    this.onSecondary,
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

  /// Libellé d'une action secondaire optionnelle (ex: « Partager mon trajet »),
  /// affichée sous le CTA principal. Ignoré si [onSecondary] est `null`.
  final String? secondaryLabel;

  /// Callback de l'action secondaire. Le bouton secondaire n'est rendu que si
  /// [secondaryLabel] ET [onSecondary] sont non-null — sinon rien n'est ajouté
  /// à l'écran (comportement inchangé pour les appelants existants).
  final VoidCallback? onSecondary;

  /// Slug identifiant le flux d'origine (ex: `trip_published`) — envoyé comme
  /// propriété `context` sur les events analytics de cet écran (vue,
  /// tap CTA, tap fermer). `null` = aucun tracking (écrans pas encore migrés).
  final String? analyticsContext;

  @override
  State<DonySuccessScreen> createState() => _DonySuccessScreenState();
}

class _DonySuccessScreenState extends State<DonySuccessScreen>
    with SingleTickerProviderStateMixin {
  // 160 (DonyMascotteSize.lg) × 1.4 — même multiplicateur que le halo dans
  // DonyMascotteAnimated (withGlow: true), pour que le burst reste centré
  // dessus sans déborder du layout.
  static const _confettiAreaSize = 224.0;

  static const _confettiParticleCount = 28;
  static const _confettiColors = [
    DonyColors.blue500,
    DonyColors.blue300,
    DonyColors.terra500,
    DonyColors.terra300,
    DonyColors.success500,
  ];

  late final AnimationController _confettiController;
  late final List<_ConfettiParticle> _confettiParticles;

  bool _reducedMotion = false;
  bool _confettiDecided = false;

  @override
  void initState() {
    super.initState();

    HapticFeedback.mediumImpact();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _confettiParticles = _generateConfettiParticles();

    _trackEvent(AnalyticsEvents.successScreenViewed);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        '${widget.title}. ${widget.subtitle}',
        TextDirection.ltr,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery n'est disponible qu'une fois les dépendances établies (pas
    // safe en initState) — on ne décide qu'une seule fois si le burst doit
    // jouer, malgré les rebuilds ultérieurs de didChangeDependencies.
    if (_confettiDecided) return;
    _confettiDecided = true;

    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_reducedMotion) {
      _confettiController.forward();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  List<_ConfettiParticle> _generateConfettiParticles() {
    // Seed fixe : burst visuellement stable d'un rebuild à l'autre, pas de
    // recalcul aléatoire à chaque frame (les particules sont générées une
    // seule fois dans initState).
    final random = math.Random(42);
    return List.generate(_confettiParticleCount, (i) {
      return _ConfettiParticle(
        angle: random.nextDouble() * 2 * math.pi,
        distance: 36 + random.nextDouble() * 90,
        fallDistance: 60 + random.nextDouble() * 100,
        size: 4 + random.nextDouble() * 4,
        rotations: (random.nextDouble() - 0.5) * 6,
        isCircle: random.nextBool(),
        color: _confettiColors[i % _confettiColors.length],
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

  void _handleSecondaryTap() {
    _trackEvent(AnalyticsEvents.successScreenSecondaryTapped);
    widget.onSecondary!();
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
                        SizedBox(
                          width: _confettiAreaSize,
                          height: _confettiAreaSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!_reducedMotion)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    key: const ValueKey(
                                      'dony-success-confetti',
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _confettiController,
                                      builder: (context, _) => CustomPaint(
                                        painter: _ConfettiPainter(
                                          progress: Curves.easeOut.transform(
                                            _confettiController.value,
                                          ),
                                          particles: _confettiParticles,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              DonyMascotteAnimated(
                                type: widget.mascotteType,
                                size: DonyMascotteSize.lg,
                                withGlow: true,
                              ),
                            ],
                          ),
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
                        if (widget.secondaryLabel != null &&
                            widget.onSecondary != null) ...[
                          const SizedBox(height: DonySpacing.md),
                          DonyButton(
                            label: widget.secondaryLabel!,
                            variant: DonyButtonVariant.secondary,
                            iconAsset: 'share-2',
                            onPressed: _handleSecondaryTap,
                          ),
                        ],
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

/// Description physique d'une particule de confetti — position de lancer,
/// trajectoire et apparence figées à la génération (voir
/// [_DonySuccessScreenState._generateConfettiParticles]).
@immutable
class _ConfettiParticle {
  const _ConfettiParticle({
    required this.angle,
    required this.distance,
    required this.fallDistance,
    required this.size,
    required this.rotations,
    required this.isCircle,
    required this.color,
  });

  /// Direction du lancer, en radians (0 = droite, sens horaire).
  final double angle;

  /// Distance parcourue en éventail (fan out) avant que la gravité prenne
  /// le relais, en px.
  final double distance;

  /// Chute additionnelle en fin de course (gravité), en px.
  final double fallDistance;

  /// Côté du carré / diamètre du cercle, en px — 4 à 8px (discret).
  final double size;

  /// Nombre de tours sur la durée du burst (peut être négatif).
  final double rotations;

  final bool isCircle;
  final Color color;
}

/// Peint un burst de confettis discret centré sur la mascotte de
/// [DonySuccessScreen]. `progress` (0 → 1) est déjà passé par l'appelant à
/// travers une courbe easeOut — le painter ne fait qu'interpoler la
/// trajectoire de chaque particule et son opacité.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      // Éventail rapide (les 60% premiers du run), puis la gravité domine.
      final fanOut = math.min(progress * 1.6, 1.0);
      final dx = math.cos(particle.angle) * particle.distance * fanOut;
      final dy =
          math.sin(particle.angle) * particle.distance * fanOut +
          particle.fallDistance * progress * progress;

      // Fade in rapide (10% du run) puis fade out linéaire sur le reste —
      // « subtile, pas carnaval ».
      final opacity = progress < 0.1
          ? progress / 0.1
          : (1 - (progress - 0.1) / 0.9).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final paint = Paint()..color = particle.color.withValues(alpha: opacity);
      final position = center + Offset(dx, dy);

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(particle.rotations * progress * 2 * math.pi);
      if (particle.isCircle) {
        canvas.drawCircle(Offset.zero, particle.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
