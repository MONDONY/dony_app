import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart'
    show formatConversationTime;
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route ouverte par un tap sur la ligne épinglée : le fil directement quand
/// l'utilisateur a exactement une conversation non résolue (le résumé la
/// place alors dans [latestTicket]), la liste `/support` sinon.
String supportTileRoute(
  int openTicketCount,
  SupportSummaryTicket? latestTicket,
) {
  if (openTicketCount == 1 && latestTicket != null) {
    return '/support/tickets/${latestTicket.id}';
  }
  return '/support';
}

/// Texte d'aperçu de la ligne : « Yadony : … » ou « Vous : … » selon
/// l'auteur du dernier message, l'invitation par défaut sans aperçu. Les
/// retours à la ligne sont aplatis pour tenir sur une ligne.
String supportPreviewText(
  AppLocalizations l, {
  required String? preview,
  required bool fromAdmin,
}) {
  final flat = (preview ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return l.supportConversationDefaultPreview;
  return fromAdmin
      ? l.supportPreviewFromTeam(flat)
      : l.supportPreviewFromUser(flat);
}

/// Ligne épinglée « Support Yadony » en tête de la liste des conversations.
///
/// Affichée même sans ticket (aperçu d'invitation). Avec un résumé serveur
/// ([latestTicket]), elle montre l'aperçu et l'heure du dernier message ; un
/// tap ouvre la route de [supportTileRoute]. Sans résumé (back antérieur),
/// elle garde l'invitation et ouvre `/support`. Le badge ne s'affiche qu'à
/// partir de 1.
class SupportConversationTile extends StatelessWidget {
  const SupportConversationTile({
    super.key,
    required this.unreadCount,
    this.latestTicket,
    this.openTicketCount = 0,
    this.onReturned,
  });

  final int unreadCount;

  /// Dernière conversation résumée par le back, null sans conversation ou
  /// sur un back antérieur au résumé.
  final SupportSummaryTicket? latestTicket;

  /// Conversations non résolues.
  final int openTicketCount;

  /// Appelé au retour de l'écran ouvert, pour rafraîchir aperçu et compteur.
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasUnread = unreadCount > 0;
    final latest = latestTicket;
    final previewText = supportPreviewText(
      l,
      preview: latest?.lastMessagePreview,
      fromAdmin: latest?.lastMessageFromAdmin ?? false,
    );
    final lastAt = latest?.lastMessageAt;
    final timeLabel = lastAt == null ? null : formatConversationTime(l, lastAt);
    final semanticsLabel = [
      l.supportBrandName,
      previewText,
      ?timeLabel,
      if (hasUnread) l.supportUnreadSemantics(unreadCount),
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: hasUnread
            ? Color.alphaBlend(cs.primary.withValues(alpha: 0.06), cs.surface)
            : cs.surface,
        child: InkWell(
          onTap: () async {
            await context.push(supportTileRoute(openTicketCount, latest));
            onReturned?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Icône d'aide distincte, à la place de l'avatar utilisateur
                _SupportAvatar(cs: cs),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.supportBrandName,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeLabel != null) ...[
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              timeLabel,
                              style: tt.labelSmall?.copyWith(
                                color: hasUnread
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              previewText,
                              style: tt.bodySmall?.copyWith(
                                color: hasUnread
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: DonySpacing.xs),
                            _UnreadBadge(count: unreadCount, cs: cs, tt: tt),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar icône support ───────────────────────────────────────────────────────

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Center(
        child: DonyIcon('circle-help', size: 22, color: cs.onPrimaryContainer),
      ),
    );
  }
}

// ── Pastille non-lus ───────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.cs, required this.tt});

  final int count;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
