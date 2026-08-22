import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// État d'un segment de [DonyOnboardingGauge].
enum DonyGaugeSegment {
  /// Le fait serveur existe : segment plein.
  done,

  /// Étape en cours : segment à demi rempli.
  current,

  /// Reste à faire — y compris une étape **passée** : passer n'est pas terminer.
  todo,
}

/// Jauge segmentée de l'onboarding progressif.
///
/// Segmentée et non continue : un segment par étape, pour montrer *lesquelles*
/// sont faites et pas seulement combien.
///
/// Ne connaît aucune étape métier — `lib/core/design/widgets/` n'importe jamais
/// `lib/features/**`. Le mappage se fait dans
/// `features/auth/presentation/onboarding_step.dart`
/// (`OnboardingProgress.segments`).
class DonyOnboardingGauge extends StatelessWidget {
  const DonyOnboardingGauge({
    super.key,
    required this.segments,
    required this.label,
  });

  final List<DonyGaugeSegment> segments;

  /// Nom de l'étape en cours, ou du contexte quand aucune ne l'est.
  final String label;

  int get _doneCount =>
      segments.where((s) => s == DonyGaugeSegment.done).length;

  String _semanticsValue() {
    final total = segments.length;
    final index = segments.indexOf(DonyGaugeSegment.current);
    final plural = _doneCount > 1 ? 's' : '';
    if (index >= 0) {
      return 'Étape ${index + 1} sur $total, $_doneCount terminée$plural';
    }
    return '$_doneCount étape$plural sur $total terminée$plural';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = segments.length;

    return Semantics(
      container: true,
      value: _semanticsValue(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_doneCount / $total · $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              // Chiffres tabulaires : le compteur ne doit pas se décaler
              // quand il passe de 1 à 4 (cf. dony_price_tag.dart).
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Row(
            children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < total - 1 ? DonySpacing.xs : 0,
                    ),
                    child: _GaugeSegment(state: segments[i]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeSegment extends StatelessWidget {
  const _GaugeSegment({required this.state});

  final DonyGaugeSegment state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final fill = switch (state) {
      DonyGaugeSegment.done => 1.0,
      DonyGaugeSegment.current => 0.5,
      DonyGaugeSegment.todo => 0.0,
    };

    // Anime *entre deux valeurs* et non à l'entrée : un `.animate()` de
    // flutter_animate rejouerait son entrée à chaque reconstruction. Même
    // parti pris que le composant frère DonyStepIndicator.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fill),
      duration: DonyDuration.base,
      curve: DonyCurve.easeOut,
      builder: (context, value, _) => Container(
        height: 6,
        decoration: BoxDecoration(
          // Le fond reste visible pour que le nombre total de segments se lise
          // même quand rien n'est fait.
          color: cs.outline,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
          ),
        ),
      ),
    );
  }
}
