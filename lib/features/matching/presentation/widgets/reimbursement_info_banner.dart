import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bandeau informatif remplaçant l'ancien champ « valeur déclarée ». Explique
/// la politique de remboursement dony (plafond configurable, sous conditions,
/// jamais automatique) et renvoie vers le détail des conditions (FAQ).
class ReimbursementInfoBanner extends StatelessWidget {
  const ReimbursementInfoBanner({super.key, this.onSeeConditions});

  /// Optionnel : override de l'action « Voir conditions » (sinon navigue FAQ).
  final VoidCallback? onSeeConditions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En cas de perte confirmée après recherche, dony rembourse '
                  "jusqu'à $donyReimbursementCapLabel € sous conditions.",
                  style:
                      textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onSeeConditions ??
                      () => context.push('/profile/help/faq'),
                  child: Text(
                    'Voir conditions',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
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
