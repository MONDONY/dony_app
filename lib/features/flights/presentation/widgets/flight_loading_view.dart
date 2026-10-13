import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Couleurs primitives intentionnelles : l'écran d'attente est sombre dans
// les deux thèmes (fond de nuit, texte blanc), comme une illustration.
const _night = DonyColors.ink900;
const _nightGlow = DonyColors.ink500;
const _white = DonyColors.neutral0;

/// Attente d'une recherche de billets : rappel du trajet, anneau terracotta
/// qui tourne autour d'un avion, trois étapes qui avancent pendant l'attente.
///
/// Les étapes sont cosmétiques (minutées) : elles reprennent l'ordre des
/// requêtes du back (vols avec escale, puis directs, puis tri) sans prétendre
/// suivre leur avancement réel.
class FlightLoadingView extends StatefulWidget {
  const FlightLoadingView({
    super.key,
    required this.routeChip,
    required this.destinationName,
  });

  /// « PAR ↔ ABJ · 12 déc. – 3 janv. · 1 pers. ».
  final String routeChip;
  final String destinationName;

  /// Durée totale du défilé des étapes.
  static const stepsDuration = Duration(milliseconds: 4200);

  @override
  State<FlightLoadingView> createState() => _FlightLoadingViewState();
}

class _FlightLoadingViewState extends State<FlightLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _steps = AnimationController(
    vsync: this,
    duration: FlightLoadingView.stepsDuration,
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Réduction des animations : l'anneau reste immobile.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.repeat();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _steps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: FlightStatusBar.night(context),
      child: DecoratedBox(
        key: const Key('flights-loading'),
        decoration: const BoxDecoration(
          color: _night,
          gradient: RadialGradient(
            center: Alignment(0, -0.64),
            radius: 1.1,
            colors: [_nightGlow, _night],
            stops: [0, 0.62],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.xl + DonySpacing.xxs,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: DonySpacing.sm),
                      _RouteChip(text: widget.routeChip),
                      const SizedBox(height: DonySpacing.huge),
                      _Ring(animation: _ring),
                      const SizedBox(height: DonySpacing.xl),
                      Text(
                        l.flightsLoadingKicker(widget.destinationName),
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: _white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        l.flightsLoadingTitle,
                        textAlign: TextAlign.center,
                        style: tt.displayMedium?.copyWith(
                          fontSize: 27,
                          color: _white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxl),
                      AnimatedBuilder(
                        animation: _steps,
                        builder: (context, _) => _Steps(progress: _steps.value),
                      ),
                      const Spacer(),
                      const SizedBox(height: DonySpacing.xl),
                      _Tip(
                        title: l.flightsLoadingTipTitle,
                        body: l.flightsLoadingTipBody,
                      ),
                      const SizedBox(height: DonySpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm - 1,
      ),
      decoration: BoxDecoration(
        color: _white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        text,
        style: tt.bodySmall?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: _white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: RotationTransition(
              turns: animation,
              child: const CustomPaint(
                size: Size.square(132),
                painter: _RingPainter(),
              ),
            ),
          ),
          const DonyIcon('plane', size: 44, color: _white),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2 + 1);
    canvas.drawCircle(
      rect.center,
      circle.width / 2,
      Paint()
        ..color = _white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      circle,
      -math.pi / 2,
      // Arc d'environ un tiers du cercle, comme la maquette.
      2 * math.pi * 0.33,
      false,
      Paint()
        // Couleur primitive intentionnelle : accent sur fond toujours sombre.
        ..color = DonyColors.terra500
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}

enum _StepState { done, now, wait }

class _Steps extends StatelessWidget {
  const _Steps({required this.progress});

  /// 0 → 1 sur [FlightLoadingView.stepsDuration].
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Étape 1 terminée à 30 %, étape 2 à 70 %, la troisième reste en cours.
    _StepState state(int i) {
      final doneAt = [0.3, 0.7, 2.0][i];
      final startAt = [0.0, 0.3, 0.7][i];
      if (progress >= doneAt) return _StepState.done;
      if (progress >= startAt) return _StepState.now;
      return _StepState.wait;
    }

    final labels = [
      l.flightsLoadingStepStops,
      l.flightsLoadingStepDirect,
      l.flightsLoadingStepSort,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.md),
          _Step(
            key: Key('flights-loading-step-$i-${state(i).name}'),
            label: labels[i],
            state: state(i),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({super.key, required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dot = switch (state) {
      _StepState.done => Container(
        decoration: const BoxDecoration(
          // Primitive intentionnelle : vert de validation sur fond sombre.
          color: DonyColors.successDark500,
          shape: BoxShape.circle,
        ),
        child: const DonyIcon('check', size: 13, color: _white),
      ),
      _StepState.now => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: DonyColors.terra500, width: 2),
        ),
      ),
      _StepState.wait => Container(
        decoration: BoxDecoration(
          color: _white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
      ),
    };
    return Row(
      children: [
        SizedBox.square(
          dimension: 22,
          child: AnimatedSwitcher(
            duration: DonyDuration.base,
            child: KeyedSubtree(key: ValueKey(state), child: dot),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: DonyDuration.base,
            style: (tt.bodyMedium ?? const TextStyle()).copyWith(
              fontSize: 13.5,
              color: _white.withValues(
                alpha: state == _StepState.wait ? 0.45 : 0.88,
              ),
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.md + DonySpacing.xxs),
      decoration: BoxDecoration(
        color: _white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _white,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            body,
            style: tt.bodySmall?.copyWith(
              fontSize: 12.5,
              color: _white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
