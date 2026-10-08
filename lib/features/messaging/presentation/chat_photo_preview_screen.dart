import 'dart:typed_data';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Aperçu plein écran d'une photo avant envoi dans le chat (FLUTTER-B4).
///
/// Ouvert par `context.push<bool>('/chat/photo-preview', extra: bytes)` ;
/// rend `true` sur « Envoyer », `false` (ou rien, retour système) sinon.
/// Pas de légende : une photo est envoyée seule.
class ChatPhotoPreviewScreen extends StatelessWidget {
  const ChatPhotoPreviewScreen({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final padding = MediaQuery.of(context).padding;
    return Scaffold(
      // Fond figé en noir quel que soit le thème : couleurs claires fixes.
      backgroundColor: Colors.black,
      body: Semantics(
        label: l.chatPhotoPreviewTitle,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.memory(
                    bytes,
                    key: const Key('chat-photo-preview-image'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            Positioned(
              top: padding.top + DonySpacing.xs,
              left: DonySpacing.xs,
              child: IconButton(
                tooltip: l.commonClose,
                onPressed: () => context.pop(false),
                icon: const DonyIcon('x', color: Colors.white),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    DonySpacing.md + padding.bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const Key('chat-photo-preview-cancel'),
                          onPressed: () => context.pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(l.commonCancel),
                        ),
                      ),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: DonyButton(
                          key: const Key('chat-photo-preview-send'),
                          label: l.commonSend,
                          iconAsset: 'send',
                          onPressed: () => context.pop(true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
