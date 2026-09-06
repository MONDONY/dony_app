import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ligne épinglée « Support Yadony » en tête de la liste des conversations.
///
/// Affichée même sans ticket (aperçu d'invitation). Un tap pousse vers
/// `/support` (liste des tickets). Le badge ne s'affiche qu'à partir de 1.
class SupportConversationTile extends StatelessWidget {
  const SupportConversationTile({
    super.key,
    required this.unreadCount,
    required this.preview,
  });

  final int unreadCount;

  /// Aperçu du dernier message. Si vide, affiche l'invitation par défaut.
  final String preview;

  static const _defaultPreview = 'Une question ? Notre équipe vous répond ici.';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasUnread = unreadCount > 0;
    final previewText = preview.isEmpty ? _defaultPreview : preview;

    return Material(
      color: hasUnread
          ? Color.alphaBlend(cs.primary.withValues(alpha: 0.06), cs.surface)
          : cs.surface,
      child: InkWell(
        onTap: () => context.push('/support'),
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
                            'Support Yadony',
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
        child: DonyIcon('help-circle', size: 22, color: cs.onPrimaryContainer),
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
