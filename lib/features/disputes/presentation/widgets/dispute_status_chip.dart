import 'package:dony/core/design/tokens/color_tokens.dart'; // DonyStatusColors extension
import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:flutter/material.dart';

class DisputeStatusChip extends StatelessWidget {
  const DisputeStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = status == 'RESOLVED';
    final fg = resolved ? cs.success : cs.warning;
    final bg = resolved ? cs.successLight : cs.warningLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            disputeStatusLabel(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
