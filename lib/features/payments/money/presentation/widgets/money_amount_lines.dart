import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:flutter/material.dart';

const kTabularFigures = [FontFeature.tabularFigures()];

/// Montants d'un total, une ligne par devise : jamais additionnés entre
/// devises. Chiffres tabulaires pour éviter les sauts au rafraîchissement.
class MoneyAmountLines extends StatelessWidget {
  const MoneyAmountLines({
    super.key,
    required this.amounts,
    this.style,
    this.alignEnd = true,
  });

  final List<MoneyAmount> amounts;
  final TextStyle? style;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    if (amounts.isEmpty) return const SizedBox.shrink();
    final textStyle = (style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: kTabularFigures,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        for (final a in amounts)
          Text(
            formatMoney(a.amount, a.currency),
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: textStyle,
          ),
      ],
    );
  }
}
