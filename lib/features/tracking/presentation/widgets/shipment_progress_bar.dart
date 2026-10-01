import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Cinq segments : faits en bleu, l'étape en cours en terracotta. Partagée
/// par « Mes envois » et « Colis à recevoir » de l'onglet Suivi.
class ShipmentProgressBar extends StatelessWidget {
  const ShipmentProgressBar({super.key, required this.step});

  /// Étape courante, 1 à 5 (voir `shipmentStepFor`).
  final int step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 1; i <= 5; i++) ...[
            if (i > 1) const SizedBox(width: DonySpacing.xxs),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < step
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
