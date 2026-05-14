import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class CommissionCardEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const CommissionCardEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_outlined, size: 96, color: cs.onSurfaceVariant),
          const SizedBox(height: DonySpacing.base),
          Text(
            'Aucune carte enregistrée',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Pour accepter des paiements en espèces, enregistrez une carte sur laquelle nous prélèverons notre commission (12 %) à chaque bid accepté.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(label: 'Ajouter une carte', onPressed: onAdd),
        ],
      ),
    );
  }
}
