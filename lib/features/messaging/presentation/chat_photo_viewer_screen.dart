import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/data/chat_image_cache.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Photo du chat à ouvrir en plein écran (extra de `/chat/photo`).
class ChatPhotoViewerArgs {
  const ChatPhotoViewerArgs({
    required this.conversationId,
    required this.messageId,
  });

  final String conversationId;
  final String messageId;
}

/// Visionneuse plein écran d'une photo du chat (FLUTTER-B4), variante
/// `full`, zoomable. Même facture que `RequestPhotoViewer` : fond noir figé,
/// bouton de fermeture en haut. 410 → « Photo expirée ».
class ChatPhotoViewerScreen extends StatelessWidget {
  const ChatPhotoViewerScreen({super.key, required this.args, this.cache});

  final ChatPhotoViewerArgs args;

  /// Injecté en test ; `getIt` sinon.
  final ChatImageCache? cache;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = cache ?? getIt<ChatImageCache>();
    final listenable = store.watch(
      conversationId: args.conversationId,
      messageId: args.messageId,
      variant: ChatImageVariant.full,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<ChatImageLoad>(
              valueListenable: listenable,
              builder: (context, load, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                child: switch (load) {
                  ChatImageReady(:final bytes) => InteractiveViewer(
                    key: const Key('chat-photo-viewer-image'),
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  ChatImageLoading() => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  ChatImageExpired() => _ViewerMessage(
                    key: const Key('chat-photo-viewer-expired'),
                    icon: 'image-off',
                    text: l.chatPhotoExpired,
                  ),
                  ChatImageFailed() => GestureDetector(
                    key: const Key('chat-photo-viewer-retry'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => store.retry(
                      conversationId: args.conversationId,
                      messageId: args.messageId,
                      variant: ChatImageVariant.full,
                    ),
                    child: _ViewerMessage(
                      icon: 'refresh-cw',
                      text: l.chatPhotoTapToRetry,
                    ),
                  ),
                },
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + DonySpacing.xs,
            right: DonySpacing.xs,
            child: IconButton(
              tooltip: l.commonClose,
              onPressed: () => context.pop(),
              icon: const DonyIcon('x', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({super.key, required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(icon, size: 40, color: Colors.white70),
          const SizedBox(height: DonySpacing.sm),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
