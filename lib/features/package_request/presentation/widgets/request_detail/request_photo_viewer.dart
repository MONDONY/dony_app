import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Photos du colis en plein écran, balayables.
abstract final class RequestPhotoViewer {
  static Future<void> show(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      // Fond porté par DonyPhotoDismiss : il s'estompe pendant le glissement
      // vers le bas (FLUTTER-GR).
      barrierColor: Colors.transparent,
      builder: (ctx) => DonyPhotoDismiss(
        background: Colors.black87,
        onDismiss: () => Navigator.of(ctx).pop(),
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: urls.length,
              itemBuilder: (_, i) => DonyZoomablePhoto(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.contain,
                    // Fond du visionneur figé en noir quel que soit le thème :
                    // couleurs fixes claires, pas cs.X (illisibles sur ce fond
                    // sombre en thème clair).
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => const Center(
                      child: DonyIcon(
                        'image-off',
                        key: Key('request-photo-viewer-error'),
                        size: 40,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + DonySpacing.xs,
              right: DonySpacing.sm,
              child: DonyPhotoCloseButton(
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
