import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';

class PriceHintWidget extends StatelessWidget {
  final double? marketMedianPrice;
  final PriceWarning? warning;
  final String? corridor;
  final SupportedCurrency? currency;

  const PriceHintWidget({
    super.key,
    this.marketMedianPrice,
    this.warning,
    this.corridor,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (warning == PriceWarning.tooLow) {
      return _buildHintCard(
        cs: cs,
        tt: tt,
        iconAsset: 'triangle-alert',
        iconColor: cs.warning,
        bgColor: cs.warningLight,
        message: 'Prix bas : risque de méfiance de l\'expéditeur',
      );
    }

    if (warning == PriceWarning.tooHigh) {
      return _buildHintCard(
        cs: cs,
        tt: tt,
        iconAsset: 'triangle-alert',
        iconColor: cs.warning,
        bgColor: cs.warningLight,
        message: 'Prix élevé : peu de demandes attendues',
      );
    }

    if (marketMedianPrice != null) {
      final corridorStr = corridor != null ? '$corridor : ' : '';
      return _buildHintCard(
        cs: cs,
        tt: tt,
        iconAsset: 'lightbulb',
        iconColor: cs.warning,
        bgColor: cs.warningLight,
        leading: 'Marché $corridorStr',
        highlight:
            '${CurrencyFormatter.formatOrPlain(marketMedianPrice!, currency)}/kg',
        message: ' · Votre prix est compétitif.',
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHintCard({
    required ColorScheme cs,
    required TextTheme tt,
    IconData? icon,
    String? iconAsset,
    required Color iconColor,
    required Color bgColor,
    String? leading,
    String? highlight,
    String? message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconAsset != null
              ? DonyIcon(iconAsset, size: 16, color: iconColor)
              : Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: highlight != null
                ? RichText(
                    text: TextSpan(
                      style: tt.bodySmall?.copyWith(color: cs.onSurface),
                      children: [
                        if (leading != null) TextSpan(text: leading),
                        TextSpan(
                          text: highlight,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (message != null) TextSpan(text: message),
                      ],
                    ),
                  )
                : Text(
                    message ?? '',
                    style: tt.bodySmall?.copyWith(color: cs.onSurface),
                  ),
          ),
        ],
      ),
    );
  }
}
