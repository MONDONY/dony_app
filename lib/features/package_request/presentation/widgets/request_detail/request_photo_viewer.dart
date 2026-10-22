import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Photos du colis en plein écran, balayables une à une. Avec plusieurs
/// photos, un compteur « 2 / 5 » dit où l'on en est.
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
        child: _RequestPhotoGallery(
          urls: urls,
          initialIndex: initialIndex,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

class _RequestPhotoGallery extends StatefulWidget {
  const _RequestPhotoGallery({
    required this.urls,
    required this.initialIndex,
    required this.onClose,
  });

  final List<String> urls;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<_RequestPhotoGallery> createState() => _RequestPhotoGalleryState();
}

class _RequestPhotoGalleryState extends State<_RequestPhotoGallery> {
  late final PageController _controller;
  late final ValueNotifier<int> _index;

  @override
  void initState() {
    super.initState();
    // Un rang hors liste ne doit jamais faire planter la galerie.
    final last = widget.urls.length - 1;
    final start = last < 0 ? 0 : widget.initialIndex.clamp(0, last);
    _index = ValueNotifier<int>(start);
    _controller = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _controller.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.urls.length;
    final top = MediaQuery.of(context).padding.top + DonySpacing.xs;
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: count,
          onPageChanged: (i) => _index.value = i,
          itemBuilder: (_, i) => DonyZoomablePhoto(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
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
        if (count > 1)
          Positioned(
            top: top,
            left: DonySpacing.md,
            child: ValueListenableBuilder<int>(
              valueListenable: _index,
              builder: (_, i, _) => Container(
                key: const Key('request-photo-viewer-counter'),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  '${i + 1} / $count',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: top,
          right: DonySpacing.sm,
          child: DonyPhotoCloseButton(onPressed: widget.onClose),
        ),
      ],
    );
  }
}
