import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class PendingDeletionBanner extends StatelessWidget {
  final DateTime deletionRequestedAt;
  final VoidCallback onReactivate;

  const PendingDeletionBanner({
    super.key,
    required this.deletionRequestedAt,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final deletionDate = deletionRequestedAt.add(const Duration(days: 30));
    final d = deletionDate.day.toString().padLeft(2, '0');
    final m = deletionDate.month.toString().padLeft(2, '0');
    final y = deletionDate.year;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.errorLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.sm),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suppression planifiée le $d/$m/$y',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onReactivate,
                  child: Text(
                    'Annuler la suppression',
                    style: tt.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
