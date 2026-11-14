import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte en fin de fil d'une conversation de question : rappelle le trajet et
/// propose de faire une demande, ce qui lève la limite de messages.
class InquiryBookingCard extends StatelessWidget {
  final String routeLabel;
  final String detailLine;
  final VoidCallback onBook;

  const InquiryBookingCard({
    super.key,
    required this.routeLabel,
    required this.detailLine,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final subtitle = detailLine.isEmpty
        ? routeLabel
        : '$routeLabel · $detailLine';
    return Container(
      key: const Key('inquiry-booking-card'),
      margin: const EdgeInsets.only(
        top: DonySpacing.md,
        bottom: DonySpacing.xs,
      ),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: DonyIcon('plane', size: 16, color: cs.primary),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.inquiryBookingCardTitle,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('inquiry-booking-button'),
            label: l.listingMakeRequestButton,
            onPressed: onBook,
          ),
        ],
      ),
    );
  }
}
