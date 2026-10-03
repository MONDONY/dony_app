import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Photo de profil en grand (FLUTTER-9Y), zoomable, avec « Modifier la
/// photo » en bas. Rend `true` quand l'utilisateur veut la changer : c'est
/// l'écran appelant qui ouvre alors la galerie.
abstract final class ProfilePhotoViewer {
  static Future<bool> show(BuildContext context, {required String url}) async {
    if (getIt.isRegistered<AnalyticsService>()) {
      unawaited(
        getIt<AnalyticsService>().logEvent(AnalyticsEvents.profilePhotoViewed),
      );
    }
    final change = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      useSafeArea: false,
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    key: const Key('profile-photo-viewer-image'),
                    imageUrl: url,
                    fit: BoxFit.contain,
                    // Fond figé en noir quel que soit le thème : couleurs
                    // claires fixes, pas cs.X (illisibles sur ce fond).
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => const Center(
                      child: DonyIcon(
                        'image-off',
                        size: 40,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: pad.top + DonySpacing.sm,
              right: DonySpacing.sm,
              child: IconButton(
                tooltip: ctx.l10n.commonClose,
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => Navigator.of(ctx).pop(false),
                icon: const DonyIcon('x', color: Colors.white),
              ),
            ),
            Positioned(
              left: DonySpacing.lg,
              right: DonySpacing.lg,
              bottom: pad.bottom + DonySpacing.lg,
              child: DonyButton(
                key: const Key('profile-photo-viewer-change'),
                label: ctx.l10n.profileEditChangePhotoLabel,
                iconAsset: 'camera',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        );
      },
    );
    return change ?? false;
  }
}
