import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Rappel en tête du fil : les messages et les photos sont effacés 3 jours
/// après la livraison du colis (back : ConversationMessagePurgeService).
///
/// Trois formes : la règle seule (colis pas encore livré, ou ancien back),
/// la date d'effacement (colis livré), puis le constat (fil déjà vidé).
class ChatRetentionBanner extends StatelessWidget {
  final ConversationModel conversation;

  const ChatRetentionBanner({super.key, required this.conversation});

  String _message(AppLocalizations l) {
    if (conversation.messagesPurged) return l.chatRetentionBannerPurged;
    final purgeAt = conversation.messagesPurgeAt;
    if (purgeAt == null) return l.chatRetentionBannerRule;
    final date = DateFormat.MMMMd(l.localeName).format(purgeAt.toLocal());
    return l.chatRetentionBannerScheduled(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final purged = conversation.messagesPurged;
    return Semantics(
      container: true,
      liveRegion: false,
      child: Container(
        width: double.infinity,
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: DonyIcon(
                purged ? 'info' : 'clock',
                size: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                _message(context.l10n),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
