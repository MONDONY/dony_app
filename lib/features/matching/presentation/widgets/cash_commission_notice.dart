import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Encart informatif affiché quand le voyageur active le paiement en espèces
/// à la publication d'un trajet.
///
/// Rappelle la règle métier : un colis en espèces ne peut être accepté que si
/// la commission Yadony est prélevable — sur le wallet en priorité, sinon sur une
/// carte enregistrée. À défaut, le voyageur devra recharger son wallet ou
/// ajouter une carte valide au moment d'accepter le bid.
class CashCommissionNotice extends StatelessWidget {
  const CashCommissionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('info', size: 18, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(
                    text:
                        'Vous ne pourrez accepter un colis en espèces que si la commission Yadony peut être prélevée ',
                  ),
                  TextSpan(
                    text: 'sur votre portefeuille en priorité',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '. À défaut, il faudra le recharger ou enregistrer une carte valide au moment d’accepter.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
