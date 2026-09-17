import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Photos du colis en plein écran, balayables.
abstract final class RequestPhotoViewer {
  static Future<void> show(BuildContext context, {required List<String> urls, int initialIndex = 0}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(child: CachedNetworkImage(imageUrl: urls[i], fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: MediaQuery.of(ctx).padding.top + 8,
            right: 8,
            child: IconButton(
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const DonyIcon('x', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
