import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter/material.dart';

/// Image d'un modal déjà téléchargée et décodée : l'afficher est immédiat.
class VideoModalImage {
  const VideoModalImage({required this.provider, required this.aspectRatio});

  final ImageProvider provider;

  /// Largeur sur hauteur de l'image d'origine.
  final double aspectRatio;
}

/// Précharge l'image d'un modal (`url` -> image prête).
typedef VideoModalImageLoader = Future<VideoModalImage?> Function(String url);

/// Délai maximal du préchargement : au-delà, le modal passe sans image
/// (bannière) ou n'est pas affiché (affiche).
const videoModalImageTimeout = Duration(seconds: 3);

/// Télécharge et décode l'image avec le cache réseau de l'app
/// (`cached_network_image`). Rend `null` en cas d'échec ou de délai dépassé,
/// sans jamais lever : un modal ne doit jamais casser l'app.
Future<VideoModalImage?> loadVideoModalImage(
  String url, {
  Duration timeout = videoModalImageTimeout,
  @visibleForTesting ImageProvider Function(String url)? providerFor,
}) async {
  final ImageProvider provider;
  final ImageStream stream;
  try {
    provider =
        providerFor?.call(url) ??
        CachedNetworkImageProvider(
          url,
          cacheKey: DonyImage.stableCacheKey(url),
        );
    stream = provider.resolve(ImageConfiguration.empty);
  } on Object {
    return null;
  }
  final done = Completer<VideoModalImage?>();
  final listener = ImageStreamListener(
    (info, _) {
      if (done.isCompleted) return;
      final w = info.image.width;
      final h = info.image.height;
      done.complete(
        w > 0 && h > 0
            ? VideoModalImage(provider: provider, aspectRatio: w / h)
            : null,
      );
    },
    onError: (_, _) {
      if (!done.isCompleted) done.complete(null);
    },
  );
  stream.addListener(listener);
  try {
    return await done.future.timeout(timeout, onTimeout: () => null);
  } finally {
    stream.removeListener(listener);
  }
}

BoxFit _boxFit(VideoModalImageFit fit) =>
    fit == VideoModalImageFit.contain ? BoxFit.contain : BoxFit.cover;

/// Image d'un modal avec son texte alternatif. Jamais de texte ni de dégradé
/// par-dessus.
class VideoModalImageView extends StatelessWidget {
  const VideoModalImageView({
    super.key,
    required this.image,
    required this.fit,
    required this.semanticLabel,
  });

  final VideoModalImage image;
  final VideoModalImageFit fit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: Image(
      key: const Key('video-modal-image'),
      image: image.provider,
      fit: _boxFit(fit),
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

/// Bannière au-dessus du titre : rapport largeur sur hauteur de l'image,
/// borné entre 1 et 2,4 pour ne pas manger tout le modal ni rester filiforme.
class VideoModalBanner extends StatelessWidget {
  const VideoModalBanner({
    super.key,
    required this.image,
    required this.fit,
    required this.semanticLabel,
  });

  final VideoModalImage image;
  final VideoModalImageFit fit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      key: const Key('video-modal-banner'),
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      child: AspectRatio(
        aspectRatio: image.aspectRatio.clamp(1.0, 2.4),
        child: ColoredBox(
          color: cs.surfaceContainerHighest,
          child: VideoModalImageView(
            image: image,
            fit: fit,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}

/// Affiche : remplit la place qu'on lui donne quand la hauteur est bornée
/// (plein écran, taille fixée), sinon garde le rapport de l'image.
class VideoModalPoster extends StatelessWidget {
  const VideoModalPoster({
    super.key,
    required this.image,
    required this.fit,
    required this.semanticLabel,
  });

  final VideoModalImage image;
  final VideoModalImageFit fit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final view = VideoModalImageView(
      image: image,
      fit: fit,
      semanticLabel: semanticLabel,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        return ColoredBox(
          key: const Key('video-modal-poster'),
          color: cs.surfaceContainerHighest,
          child: bounded
              ? view
              : AspectRatio(
                  aspectRatio: image.aspectRatio.clamp(0.4, 2.4),
                  child: view,
                ),
        );
      },
    );
  }
}
