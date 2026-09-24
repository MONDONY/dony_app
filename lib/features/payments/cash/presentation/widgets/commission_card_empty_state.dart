import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

class CommissionCardEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const CommissionCardEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DonyMascotteAnimated(
            type: DonyMascotteType.assis,
            size: DonyMascotteSize.lg,
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            l.commissionCardEmptyTitle,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            l.commissionCardEmptyBody(commissionPercentLabel(l)),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(label: l.commissionCardAddButton, onPressed: onAdd),
        ],
      ),
    );
  }
}
