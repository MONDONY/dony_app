import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RematchBottomSheet extends StatelessWidget {
  const RematchBottomSheet({super.key, required this.cancellation});

  final CancellationModel cancellation;

  /// Ouvre la BS si <= 4 suggestions, sinon plein écran.
  static void showOrNavigate(
      BuildContext context, CancellationModel cancellation) {
    if (cancellation.rematchSuggestions.length <= 4) {
      final count = cancellation.rematchSuggestions.length;
      DonyBottomSheet.show(
        context,
        title: count == 0
            ? 'Aucune alternative disponible'
            : '$count alternative${count > 1 ? 's' : ''} trouvée${count > 1 ? 's' : ''}',
        child: RematchBottomSheet(cancellation: cancellation),
      );
    } else {
      context.push('/cancellations/rematch', extra: cancellation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final suggestions = cancellation.rematchSuggestions;

    if (suggestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DonySpacing.lg),
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Aucun voyageur disponible sur ce corridor pour l\'instant.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      );
    }

    final _dateFmt = DateFormat('d MMM yyyy', 'fr_FR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...suggestions.map((suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${suggestion.departureCity} → ${suggestion.arrivalCity}',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xxs),
                          Text(
                            _dateFmt.format(suggestion.departureDate),
                            style: tt.bodySmall?.copyWith(
                              color: DonyColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xxs),
                          Row(
                            children: [
                              Text(
                                '${suggestion.availableKg.toStringAsFixed(1)} kg dispo',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: DonySpacing.xs),
                              Text('·', style: tt.labelSmall),
                              const SizedBox(width: DonySpacing.xs),
                              Text(
                                '${suggestion.pricePerKg.toStringAsFixed(0)} €/kg',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    DonyButton(
                      label: 'Voir',
                      variant: DonyButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(
                            '/announcements/${suggestion.announcementId}');
                      },
                    ),
                  ],
                ),
              ),
            )),
        if (suggestions.length >= 4) ...[
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Voir toutes les alternatives',
            variant: DonyButtonVariant.ghost,
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/cancellations/rematch', extra: cancellation);
            },
          ),
        ],
      ],
    );
  }
}
