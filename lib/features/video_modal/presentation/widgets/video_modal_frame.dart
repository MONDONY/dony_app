import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_route_filter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Habillage d'un modal : feuille du bas, carte centrée ou plein écran.
///
/// Dans les trois cas le contenu défile s'il est long et les boutons restent
/// fixes en bas, empilés en pleine largeur. La feuille passe par
/// `DonyBottomSheet` (boutons dans `stickyBottom`) ; la carte et le plein
/// écran portent une croix toujours visible, dont la réponse est
/// [closeResult] ; toucher à côté ou le retour système rendent `null`.
abstract final class VideoModalFrame {
  /// Marge entre la carte centrée et les bords de l'écran.
  static const dialogInset = DonySpacing.lg;

  static Future<T?> show<T>(
    BuildContext context, {
    required VideoModalLayout layout,
    required int? sizePercent,
    required String analyticsName,
    required Widget child,
    required Widget buttons,
    required T closeResult,

    /// Le contenu est une affiche : elle remplit toute la place quand la
    /// hauteur est fixée (taille choisie, plein écran).
    bool poster = false,
  }) {
    final routeSettings = RouteSettings(
      name: '$kAnalyticsSheetRoutePrefix$analyticsName',
    );
    switch (layout) {
      case VideoModalLayout.bottomSheet:
        return DonyBottomSheet.show<T>(
          context,
          analyticsName: analyticsName,
          maxHeightFraction: sizePercent == null ? null : sizePercent / 100,
          stickyBottom: buttons,
          child: child,
        );
      case VideoModalLayout.centered:
        return showDialog<T>(
          context: context,
          routeSettings: routeSettings,
          builder: (_) => _CenteredModal<T>(
            sizePercent: sizePercent,
            poster: poster,
            closeResult: closeResult,
            buttons: buttons,
            child: child,
          ),
        );
      case VideoModalLayout.fullscreen:
        return showGeneralDialog<T>(
          context: context,
          routeSettings: routeSettings,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          transitionDuration: DonyDuration.base,
          pageBuilder: (_, _, _) => _FullscreenModal<T>(
            poster: poster,
            closeResult: closeResult,
            buttons: buttons,
            child: child,
          ),
          transitionBuilder: (_, animation, _, page) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: DonyCurve.enter),
            child: page,
          ),
        );
    }
  }
}

/// Croix de fermeture, alignée à droite, toujours visible.
class _CloseBar<T> extends StatelessWidget {
  const _CloseBar({required this.closeResult});

  final T closeResult;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xs),
        child: IconButton(
          key: const Key('video-modal-close'),
          tooltip: context.l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(closeResult),
          icon: DonyIcon('x', size: 20, color: cs.onSurfaceVariant),
          style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Zone défilante (ou qui remplit la place, pour une affiche) puis boutons
/// fixes.
class _ModalBody<T> extends StatelessWidget {
  const _ModalBody({
    required this.expand,
    required this.scroll,
    required this.poster,
    required this.closeResult,
    required this.buttons,
    required this.child,
    this.footerSafeBottom = 0,
  });

  /// Prend toute la hauteur offerte (sinon épouse le contenu).
  final bool expand;

  /// Le contenu défile ; sinon (affiche) il remplit la place.
  final bool scroll;

  /// Marge latérale autour d'une affiche.
  final bool poster;
  final T closeResult;
  final Widget buttons;
  final Widget child;

  /// Zone sûre du bas à ajouter sous les boutons (plein écran).
  final double footerSafeBottom;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = poster
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            child: child,
          )
        : child;
    final Widget area = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Material(type: MaterialType.transparency, child: content),
          )
        : content;
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CloseBar<T>(closeResult: closeResult),
        if (expand) Expanded(child: area) else Flexible(child: area),
        Container(
          key: const Key('video-modal-footer'),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outline)),
          ),
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.md,
            DonySpacing.lg,
            DonySpacing.base + footerSafeBottom,
          ),
          child: buttons,
        ),
      ],
    );
  }
}

class _CenteredModal<T> extends StatelessWidget {
  const _CenteredModal({
    required this.sizePercent,
    required this.poster,
    required this.closeResult,
    required this.buttons,
    required this.child,
  });

  final int? sizePercent;
  final bool poster;
  final T closeResult;
  final Widget buttons;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    // Hauteur disponible pour la carte : l'écran moins les marges, la zone
    // sûre et le clavier.
    final available = math.max(
      0.0,
      mq.size.height -
          mq.viewPadding.vertical -
          mq.viewInsets.bottom -
          2 * VideoModalFrame.dialogInset,
    );
    final wanted = sizePercent == null
        ? available
        : mq.size.height * sizePercent! / 100;
    final maxHeight = math.min(available, wanted);
    // Affiche avec une taille choisie : elle remplit la carte.
    final fill = poster && sizePercent != null;
    final body = _ModalBody<T>(
      expand: fill,
      scroll: !fill,
      poster: poster,
      closeResult: closeResult,
      buttons: buttons,
      child: child,
    );
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(VideoModalFrame.dialogInset),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: ConstrainedBox(
        key: const Key('video-modal-card'),
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          minHeight: fill ? maxHeight : 0,
          maxWidth: 480,
        ),
        child: body,
      ),
    );
  }
}

class _FullscreenModal<T> extends StatelessWidget {
  const _FullscreenModal({
    required this.poster,
    required this.closeResult,
    required this.buttons,
    required this.child,
  });

  final bool poster;
  final T closeResult;
  final Widget buttons;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    return Material(
      key: const Key('video-modal-fullscreen'),
      color: cs.surface,
      child: Padding(
        padding: EdgeInsets.only(top: mq.viewPadding.top),
        child: _ModalBody<T>(
          expand: true,
          scroll: !poster,
          poster: poster,
          footerSafeBottom: mq.viewPadding.bottom,
          closeResult: closeResult,
          buttons: buttons,
          child: child,
        ),
      ),
    );
  }
}
