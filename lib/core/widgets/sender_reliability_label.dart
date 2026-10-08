import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « ⚠ 2 annulations ou absences » : fiabilité d'un expéditeur, là où un
/// voyageur le juge (demande reçue, fiche et carte de la demande, profil
/// public) — FLUTTER-E0/E6.
///
/// Compte les annulations faites après l'acceptation d'un voyageur et les
/// absences confirmées au rendez-vous de remise. Rien n'est affiché à zéro ni
/// sur un back qui ne fournit pas encore le champ ([count] nul) : le libellé
/// signale un risque, il ne décerne pas de bon point.
class SenderReliabilityLabel extends StatelessWidget {
  const SenderReliabilityLabel({super.key, required this.count});

  final int? count;

  static bool isVisible(int? count) => count != null && count > 0;

  @override
  Widget build(BuildContext context) {
    if (!isVisible(count)) return const SizedBox.shrink();
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Tooltip(
      message: l.senderReliabilityTooltip,
      child: Semantics(
        label:
            '${l.senderReliabilityLabel(count!)}. ${l.senderReliabilityTooltip}',
        excludeSemantics: true,
        child: Row(
          key: const Key('sender-reliability-label'),
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('triangle-alert', size: 13, color: cs.warning),
            const SizedBox(width: DonySpacing.xxs),
            Flexible(
              child: Text(
                l.senderReliabilityLabel(count!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  color: cs.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
