import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Nombre de messages restants avant réservation, au-dessus du composeur
/// d'une conversation de question : une pastille par message permis (pleine =
/// restant), puis le texte. Passe en terracotta (`secondaryContainer`) quand
/// il en reste trois ou moins.
class InquiryQuotaBar extends StatelessWidget {
  /// Seuil à partir duquel la barre prévient (terracotta).
  static const int lowThreshold = 3;

  final int remaining;
  final int limit;

  const InquiryQuotaBar({
    super.key,
    required this.remaining,
    required this.limit,
  });

  bool get _low => remaining <= lowThreshold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filledColor = _low ? cs.secondary : cs.primary;
    final textColor = _low ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    final filled = remaining.clamp(0, limit);
    return Container(
      key: const Key('inquiry-quota-bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _low ? cs.secondaryContainer : cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < limit; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    child: Container(
                      key: Key(
                        i < filled ? 'inquiry-dot-filled' : 'inquiry-dot-used',
                      ),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < filled ? filledColor : cs.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Text(
              context.l10n.inquiryQuotaRemaining(remaining),
              style: tt.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
