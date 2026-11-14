import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Note centrée dans le fil d'une question avant réservation (consigne de
/// départ, limite atteinte) : discrète, hors bulle.
class InquiryNote extends StatelessWidget {
  final String text;

  const InquiryNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Container(
        key: const Key('inquiry-note'),
        margin: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
