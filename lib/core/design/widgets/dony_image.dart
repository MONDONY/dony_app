import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/tokens/animation_tokens.dart';
import 'package:flutter/material.dart';

/// Image réseau avec cache disque stable.
///
/// Les photos dony sont servies via des URLs S3 présignées dont les query
/// params (signature, date, expiration) changent à chaque fetch backend.
/// Ce widget dérive une clé de cache stable (URL sans query params) pour que
/// la même image ne soit téléchargée qu'une seule fois, quelle que soit la
/// signature courante — plus de re-téléchargement ni de clignotement à
/// chaque rebuild.
class DonyImage extends StatelessWidget {
  const DonyImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;

  /// Clé de cache stable : l'URL présignée sans ses query params volatils.
  static String stableCacheKey(String url) {
    final q = url.indexOf('?');
    return q == -1 ? url : url.substring(0, q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = CachedNetworkImage(
      imageUrl: url,
      cacheKey: stableCacheKey(url),
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: DonyDuration.base,
      fadeInCurve: DonyCurve.enter,
      fadeOutDuration: DonyDuration.micro,
      fadeOutCurve: DonyCurve.exit,
      placeholder: (context, _) =>
          placeholder?.call(context) ??
          ColoredBox(color: cs.surfaceContainerHighest),
      errorWidget: (context, _, __) =>
          errorWidget?.call(context) ??
          ColoredBox(
            color: cs.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ),
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
