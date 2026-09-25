import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_status_chip.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisputeCard extends StatelessWidget {
  const DisputeCard({super.key, required this.dispute, required this.onTap});
  final DisputeModel dispute;
  final VoidCallback onTap;

  String _otherPartyLine(AppLocalizations l) {
    final name = dispute.otherPartyName;
    if (name == null) {
      return l.disputeShipmentDeleted;
    }
    return l.disputeOtherParty(dispute.myRole, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final df = DateFormat.yMMMd(l.localeName);
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
                      disputeTypeLabel(l, dispute.type),
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
                  _otherPartyLine(l),
                  if (dispute.weightKg != null)
                    l.disputeParcelWeight(
                      disputeWeightLabel(l, dispute.weightKg!),
                    ),
                ].join(' · '),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                dispute.isResolved && dispute.resolvedAt != null
                    ? l.disputeOpenedAndResolved(
                        df.format(dispute.createdAt),
                        df.format(dispute.resolvedAt!),
                      )
                    : l.disputeOpenedOn(df.format(dispute.createdAt)),
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
                          l.disputeCardFrozenNotice,
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
