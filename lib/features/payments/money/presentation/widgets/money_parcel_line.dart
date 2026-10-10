import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_amount_lines.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Ligne compacte d'un colis : **code** · détails · état, montant à droite.
/// Un tap ouvre le colis (`/bids/:id`).
class MoneyParcelLine extends StatelessWidget {
  const MoneyParcelLine({
    super.key,
    required this.item,
    required this.onTap,
    this.details = const [],
    this.status,
    this.tone = MoneyTone.neutral,
    this.textColor,
  });

  final MoneyItemModel item;
  final VoidCallback onTap;

  /// Fragments après le code (trajet, contrepartie…).
  final List<String> details;

  /// État court, coloré selon [tone].
  final String? status;
  final MoneyTone tone;

  /// Couleur du texte (lignes sur fond teinté, ex. litige).
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final base = tt.bodyMedium?.copyWith(color: textColor ?? cs.onSurface);
    final statusColor = switch (tone) {
      MoneyTone.positive => cs.success,
      MoneyTone.info => cs.primary,
      MoneyTone.attention => textColor ?? cs.onSurface,
      MoneyTone.neutral => textColor ?? cs.onSurfaceVariant,
    };
    final code = item.trackingNumber;
    final amount = item.amount;
    final spans = <InlineSpan>[];
    void add(InlineSpan span) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' · '));
      spans.add(span);
    }

    if (code != null) {
      add(
        TextSpan(
          text: code,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: kTabularFigures,
          ),
        ),
      );
    }
    for (final d in details) {
      add(TextSpan(text: d));
    }
    final statusText = status;
    if (statusText != null) {
      add(
        TextSpan(
          text: statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: tone == MoneyTone.neutral
                ? FontWeight.w400
                : FontWeight.w600,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      onTapHint: l.moneyOpenParcelHint,
      child: DonyPressable(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          key: Key('money-line-${item.bidId}'),
          color: Colors.transparent,
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.md - 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(TextSpan(children: spans), style: base),
                ),
                if (amount != null) ...[
                  const SizedBox(width: DonySpacing.sm),
                  Text(
                    formatMoney(amount, item.currency),
                    style: base?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
