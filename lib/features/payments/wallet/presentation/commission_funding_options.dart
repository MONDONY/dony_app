import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/commission_funding_alternative.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Devise du trajet d'un « solde insuffisant » : champ `bidCurrency` du 409,
/// sinon celle du détail de conversion, sinon la devise du solde affiché.
String? commissionTripCurrency({
  String? bidCurrency,
  CommissionShortfall? breakdown,
  String? currency,
}) => bidCurrency ?? breakdown?.bidCurrency ?? currency?.toUpperCase();

/// Libellé du bouton de recharge : « Recharger en EUR » quand la devise du
/// trajet est connue. Recharger dans une autre devise ne couvrait pas la
/// commission et renvoyait le voyageur en boucle sur le même refus
/// (FLUTTER-CG).
String commissionTopupLabel(
  AppLocalizations l, {
  required String? tripCurrency,
  required String fallback,
}) => tripCurrency == null
    ? fallback
    : l.walletShortfallTopupInCurrency(tripCurrency);

/// Options « Payer avec mon solde XOF » d'un solde insuffisant : chaque autre
/// portefeuille qui couvre seul le reste, avec le montant prélevé au taux du
/// jour et l'avertissement sur ce taux. Rien n'est rendu sans alternative.
class CommissionFundingOptions extends StatelessWidget {
  const CommissionFundingOptions({
    super.key,
    required this.alternatives,
    required this.onSelected,
  });

  final List<CommissionFundingAlternative> alternatives;

  /// Reçoit le code ISO du portefeuille choisi.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (alternatives.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final alternative in alternatives) ...[
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: l.walletShortfallPayWithCurrency(alternative.currency),
            variant: DonyButtonVariant.secondary,
            iconAsset: 'wallet',
            onPressed: () => onSelected(alternative.currency),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.walletShortfallAlternativeApprox(
              formatPriceIn(alternative.requiredAmount, alternative.currency),
            ),
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ],
        const SizedBox(height: DonySpacing.sm),
        Text(
          l.walletShortfallRateDisclaimer,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
