import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Quatre segments, un par étape de `shipmentStepFor` (accepté, en route,
/// arrivé, remis) : faits en bleu, l'étape en cours en terracotta. La
/// dernière (remis) n'est pas « en cours » : tout passe en bleu. Avec cinq
/// segments pour quatre étapes, un colis remis restait à moitié vide (Sentry
/// FLUTTER-6E). Partagée par « Mes envois » et « Colis à recevoir ».
class ShipmentProgressBar extends StatelessWidget {
  const ShipmentProgressBar({super.key, required this.step});

  /// Nombre de segments, égal à la dernière étape de `shipmentStepFor`.
  static const segments = 4;

  /// Étape courante, 1 à 4 (voir `shipmentStepFor`).
  final int step;

  bool _done(int i) => i < step || step >= segments;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 1; i <= segments; i++) ...[
            if (i > 1) const SizedBox(width: DonySpacing.xxs),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _done(i)
                      ? cs.primary
                      : i == step
                      ? cs.secondary
                      : cs.outline,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
