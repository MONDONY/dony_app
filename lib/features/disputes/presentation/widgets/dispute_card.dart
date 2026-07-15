import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_status_chip.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisputeCard extends StatelessWidget {
  const DisputeCard({super.key, required this.dispute, required this.onTap});
  final DisputeModel dispute;
  final VoidCallback onTap;

  String get _otherPartyLine {
    final name = dispute.otherPartyName;
    if (name == null) {
      return 'Envoi supprimé';
    }
    final prefix = dispute.myRole == 'SENDER' ? 'Voyageur' : 'Expéditeur';
    return '$prefix : $name';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final df = DateFormat('d MMM yyyy', 'fr');
    final dep = dispute.departureCity;
    final arr = dispute.arrivalCity;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      disputeTypeLabel(dispute.type),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DisputeStatusChip(status: dispute.status),
                ],
              ),
              if (dep != null && arr != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${cityFlag(dep) ?? ''} $dep → $arr ${cityFlag(arr) ?? ''}'
                      .trim(),
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                [
                  _otherPartyLine,
                  if (dispute.weightKg != null)
                    'Envoi ${dispute.weightKg!.toStringAsFixed(dispute.weightKg! % 1 == 0 ? 0 : 1)} kg',
                ].join(' · '),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                dispute.isResolved && dispute.resolvedAt != null
                    ? 'Ouvert le ${df.format(dispute.createdAt)} · Résolu le ${df.format(dispute.resolvedAt!)}'
                    : 'Ouvert le ${df.format(dispute.createdAt)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (dispute.refundFrozen && dispute.isOpen) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Remboursement gelé le temps de l\'instruction — réponse sous 72 h.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
