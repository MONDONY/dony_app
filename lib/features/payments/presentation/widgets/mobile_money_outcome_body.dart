import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Issue sans attente d'un paiement mobile money : « Pas encore validé »
/// (échéance passée), échec final ou erreur technique. Icône dans une
/// pastille, titre, texte.
class MobileMoneyOutcomeBody extends StatelessWidget {
  const MobileMoneyOutcomeBody({
    super.key,
    required this.iconAsset,
    required this.message,
    this.title,
    this.warning = false,
  });

  final String iconAsset;
  final String? title;
  final String message;

  /// Pastille ambre (rien n'est perdu) plutôt que rouge (échec).
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tone = warning ? cs.warning : cs.error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(child: DonyIcon(iconAsset, color: tone, size: 26)),
            ),
            const SizedBox(height: DonySpacing.base),
            if (title case final String t) ...[
              Text(
                t,
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
