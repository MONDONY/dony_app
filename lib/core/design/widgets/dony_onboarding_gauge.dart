import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// État d'un segment de [DonyOnboardingGauge].
enum DonyGaugeSegment {
  /// Le fait serveur existe : segment plein.
  done,

  /// Étape en cours : segment à demi rempli.
  current,

  /// Reste à faire, ou (hors parcours) une étape passée : passer n'est pas
  /// terminer.
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
    this.semanticsLabel = 'Progression de l\'inscription',
    this.showCounter = true,
  });

  final List<DonyGaugeSegment> segments;

  /// Nom de l'étape en cours, ou du contexte quand aucune ne l'est.
  final String label;

  /// Ce que la jauge mesure, lu par le lecteur d'écran. Par défaut le parcours
  /// d'inscription, son premier usage ; la carte des outils en fournit un autre.
  final String semanticsLabel;

  /// Affiche la ligne de compteur texte (« n / total · label ») au-dessus des
  /// segments. À `false` quand un autre élément de l'écran affiche déjà ce
  /// compteur (ex : titre de la carte de complétion des outils) — la
  /// `Semantics` reste inchangée dans les deux cas.
  final bool showCounter;

  /// Position affichée : segments pleins + l'étape en cours. Sur le 4e écran
  /// d'un parcours de 5, le compteur dit « 4 / 5 » — le numéro de l'étape où
  /// l'on se trouve, pas le nombre d'étapes remplies (un compteur qui stagne
  /// pendant qu'on avance se lit comme un parcours cassé).
  int get _reachedCount =>
      segments.where((s) => s != DonyGaugeSegment.todo).length;

  String _semanticsValue() {
    final total = segments.length;
    final index = segments.indexOf(DonyGaugeSegment.current);
    if (index >= 0) {
      return 'Étape ${index + 1} sur $total';
    }
    final plural = _reachedCount > 1 ? 's' : '';
    return '$_reachedCount étape$plural sur $total';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = segments.length;

    return Semantics(
      container: true,
      label: semanticsLabel,
      value: _semanticsValue(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCounter) ...[
            Text(
              '$_reachedCount / $total · $label',
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
          ],
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
          // Le fond reste visible pour que le nombre total de segments se
          // lise même quand rien n'est fait — mais en alpha, comme toute
          // piste de progression voisine (`edit_profile_screen.dart`,
          // `pro_stats_bottom_sheet.dart`), jamais `cs.outline` plein, trop
          // lourd à côté des autres composants du parcours.
          color: cs.outline.withValues(alpha: 0.3),
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
