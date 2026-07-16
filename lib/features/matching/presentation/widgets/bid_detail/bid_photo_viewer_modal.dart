import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/widgets/dony_image.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:flutter/material.dart';

/// Visionneuse modale (carte arrondie, pas plein écran) des photos d'un colis.
/// Swipe + dots + compteur, fermeture par ✕ ou tap hors carte.
class BidPhotoViewerModal extends StatefulWidget {
  final List<BidPhoto> photos;
  final int initialIndex;

  const BidPhotoViewerModal({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<BidPhoto> photos,
    int initialIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => BidPhotoViewerModal(photos: photos, initialIndex: initialIndex),
    );
  }

  @override
  State<BidPhotoViewerModal> createState() => _BidPhotoViewerModalState();
}

class _BidPhotoViewerModalState extends State<BidPhotoViewerModal> {
  late final PageController _controller;
  late final ValueNotifier<int> _index;

  @override
  void initState() {
    super.initState();
    _index = ValueNotifier<int>(widget.initialIndex);
    _controller = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (getIt.isRegistered<AnalyticsService>()) {
        unawaited(getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.bidPhotosViewed,
          properties: {'photo_count': widget.photos.length},
        ));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.photos.length;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorbe les taps dans la carte
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _index,
                        builder: (_, i, _) => Text(
                          'Photo ${i + 1} / $count',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: count,
                        onPageChanged: (i) => _index.value = i,
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: widget.photos[i].url,
                          cacheKey: DonyImage.stableCacheKey(widget.photos[i].url),
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Center(
                            child: CircularProgressIndicator(
                              color: cs.primary,
                            ),
                          ),
                          errorWidget: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: _index,
                      builder: (_, current, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < count; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3.5),
                              width: i == current ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == current
                                    ? cs.primary
                                    : cs.outline.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
