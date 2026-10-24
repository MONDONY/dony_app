import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pastille de date entre deux jours d'une conversation : « Aujourd'hui »,
/// « Hier » ou la date complète.
class DonyChatDateSeparator extends StatelessWidget {
  const DonyChatDateSeparator({super.key, required this.date});

  final DateTime date;

  String _label(AppLocalizations l) {
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    // Jour calendaire, pas 24 h d'écart : un message d'hier 12 h lu à 1 h du
    // matin tombait sous les 24 h et s'affichait avec sa date complète.
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (day == today) return l.commonDateToday;
    if (day == yesterday) return l.commonDateYesterday;
    return DateFormat.yMMMMd(l.localeName).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Text(
            _label(context.l10n),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
