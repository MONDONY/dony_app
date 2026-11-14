import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Remplace le composeur quand le demandeur a épuisé ses messages avant
/// réservation : explication terracotta et bouton « Faire une demande ».
class InquiryLockedBar extends StatelessWidget {
  final VoidCallback onBook;

  const InquiryLockedBar({super.key, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      key: const Key('inquiry-locked-bar'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DonyIcon(
                    'lock',
                    size: 16,
                    color: cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    l.inquiryLockedExplanation,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('inquiry-booking-button'),
            label: l.listingMakeRequestButton,
            iconAsset: 'send',
            onPressed: onBook,
          ),
        ],
      ),
    );
  }
}
