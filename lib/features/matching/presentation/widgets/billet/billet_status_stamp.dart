import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Tampon de statut incliné affiché dans l'en-tête du billet.
class BilletStatusStamp extends StatelessWidget {
  final String status;
  const BilletStatusStamp({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (Color color, String label) = switch (status) {
      'AWAITING_PAYMENT' => (cs.warning, 'À payer'),
      'PENDING' || 'PAYMENT_ESCROWED' => (cs.warning, 'En attente'),
      'ACCEPTED' => (cs.success, 'Confirmé'),
      'HANDED_OVER' => (cs.primary, 'En route'),
      'IN_TRANSIT' => (cs.primary, 'En transit'),
      'COMPLETED' || 'DELIVERED' => (cs.success, 'Livré'),
      'REJECTED' => (cs.error, 'Refusé'),
      'CANCELLED' => (cs.onSurfaceVariant, 'Annulé'),
      _ => (cs.onSurfaceVariant, status),
    };

    return Transform.rotate(
      angle: -0.087, // −5° en radians
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
