import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/chat_image_cache.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

// ── Trombone (FLUTTER-B4) ─────────────────────────────────────────────────────

/// État du trombone de la saisie.
enum ChatAttachState {
  /// Photos permises : le tap ouvre le choix galerie / appareil photo.
  enabled,

  /// Demande en cours mais photos pas (encore) permises : grisé, le tap
  /// explique pourquoi.
  locked,

  /// Fil sans avenir pour une photo : rien n'est proposé.
  hidden,
}

/// Règle d'affichage du trombone :
/// - **masqué** si l'utilisateur ne peut pas écrire (fil en lecture seule,
///   copie supprimée), ou si la demande est terminée sans photo possible
///   (annulée, ou livrée et fenêtre de J+3 refermée) ;
/// - **actif** si le back dit `mediaAllowed` ;
/// - **grisé** sinon : demande en attente d'acceptation ou de paiement (aucun
///   statut affiché), ou back antérieur qui ne sert pas encore le champ.
ChatAttachState chatAttachStateFor(
  ConversationModel conversation, {
  required bool mediaAllowed,
  required bool readOnly,
}) {
  if (readOnly || conversation.readOnly || conversation.deletedBySelf) {
    return ChatAttachState.hidden;
  }
  if (mediaAllowed) return ChatAttachState.enabled;
  return switch (conversation.bidStatus) {
    'TRIP_CANCELLED' || 'DELIVERY_CONFIRMED' => ChatAttachState.hidden,
    _ => ChatAttachState.locked,
  };
}

/// Trombone à gauche du champ de saisie.
class ChatAttachButton extends StatelessWidget {
  const ChatAttachButton({
    super.key,
    required this.state,
    required this.onPick,
    required this.onLocked,
  });

  final ChatAttachState state;
  final VoidCallback onPick;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final enabled = state == ChatAttachState.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        label: enabled ? l.chatAttachPhotoTooltip : l.chatPhotoLockedSemantics,
        container: true,
        excludeSemantics: true,
        child: DonyPressable(
          onTap: enabled ? onPick : onLocked,
          child: SizedBox(
            key: const Key('chat-attach-button'),
            width: 38,
            height: 38,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.4,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.attach_file_rounded,
                size: 22,
                color: enabled ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Photo servie par le back ──────────────────────────────────────────────────

const double kChatPhotoSize = 200;

/// Contour discret de toute image (1 px, noir 10 % en clair, blanc 10 % en
/// sombre) : la photo garde son bord sur n'importe quel fond.
BoxDecoration chatPhotoOutline(BuildContext context, double radius) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.1),
    ),
  );
}

/// Miniature d'une photo du fil, chargée par l'API (clé `messageId:thumb`).
/// Tap : [onOpen] quand la photo est prête, nouvel essai après un échec.
class ChatServerImage extends StatelessWidget {
  const ChatServerImage({
    super.key,
    required this.conversationId,
    required this.messageId,
    required this.expired,
    required this.onOpen,
    this.cache,
  });

  final String conversationId;
  final String messageId;

  /// Purgée d'après le message Firestore : aucune requête.
  final bool expired;
  final VoidCallback onOpen;

  /// Injecté en test ; `getIt` sinon.
  final ChatImageCache? cache;

  static const double _radius = DonyRadius.card - 1;

  @override
  Widget build(BuildContext context) {
    if (expired) return const ChatPhotoExpired();
    final store = cache ?? getIt<ChatImageCache>();
    final listenable = store.watch(
      conversationId: conversationId,
      messageId: messageId,
      variant: ChatImageVariant.thumb,
    );
    return ValueListenableBuilder<ChatImageLoad>(
      valueListenable: listenable,
      builder: (context, load, _) {
        final child = switch (load) {
          ChatImageReady(:final bytes) => Semantics(
            button: true,
            label: context.l10n.chatPhotoOpenSemantics,
            child: GestureDetector(
              onTap: onOpen,
              child: Image.memory(
                bytes,
                key: const Key('chat-photo-ready'),
                width: kChatPhotoSize,
                height: kChatPhotoSize,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          ChatImageExpired() => const ChatPhotoExpired(),
          ChatImageFailed() => _RetryTile(
            onTap: () => store.retry(
              conversationId: conversationId,
              messageId: messageId,
              variant: ChatImageVariant.thumb,
            ),
          ),
          ChatImageLoading() => const _LoadingTile(),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          child: ClipRRect(
            key: ValueKey(load.runtimeType),
            borderRadius: BorderRadius.circular(_radius),
            child: Container(
              foregroundDecoration: chatPhotoOutline(context, _radius),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: kChatPhotoSize,
      height: kChatPhotoSize,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _RetryTile extends StatelessWidget {
  const _RetryTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      key: const Key('chat-photo-retry'),
      onTap: onTap,
      child: Container(
        width: kChatPhotoSize,
        height: kChatPhotoSize,
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.all(DonySpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyIcon('refresh-cw', size: 22, color: cs.onSurfaceVariant),
            const SizedBox(height: DonySpacing.xs),
            Text(
              context.l10n.chatPhotoTapToRetry,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Photo expirée » : le message reste, l'image n'est plus disponible.
class ChatPhotoExpired extends StatelessWidget {
  const ChatPhotoExpired({super.key, this.size = kChatPhotoSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card - 1),
      child: Container(
        key: const Key('chat-photo-expired'),
        width: size,
        height: size * 0.6,
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.all(DonySpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyIcon('image-off', color: cs.onSurfaceVariant),
            const SizedBox(height: DonySpacing.xs),
            Text(
              context.l10n.chatPhotoExpired,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo locale en cours d'envoi ─────────────────────────────────────────────

/// Bulle d'une photo pas encore arrivée dans le fil : aperçu local voilé,
/// « Envoi… » ou « Non envoyée » avec Réessayer / Supprimer.
class ChatPendingImageBubble extends StatelessWidget {
  const ChatPendingImageBubble({
    super.key,
    required this.image,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingChatImage image;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  static const double _radius = DonyRadius.card;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final failed = image.isFailed;
    return Padding(
      key: Key('chat-pending-${image.localId}'),
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.memory(
                      image.bytes,
                      width: kChatPhotoSize,
                      height: kChatPhotoSize,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Container(
                        width: kChatPhotoSize,
                        height: kChatPhotoSize,
                        color: cs.surfaceContainerHighest,
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        color: Colors.black.withValues(
                          alpha: failed ? 0.45 : 0.25,
                        ),
                      ),
                    ),
                    if (!failed)
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    else
                      const DonyIcon('circle-x', size: 28, color: Colors.white),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: chatPhotoOutline(context, _radius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              if (!failed)
                Text(
                  l.chatPhotoSending,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.chatPhotoNotSent,
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                    TextButton(
                      key: const Key('chat-pending-retry'),
                      onPressed: onRetry,
                      child: Text(l.commonRetry),
                    ),
                    TextButton(
                      key: const Key('chat-pending-discard'),
                      onPressed: onDiscard,
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                      child: Text(l.commonDelete),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
