import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum DonySnackbarType { info, success, warning, error }

abstract final class DonySnackbar {
  static final Map<String, DateTime> _lastShown = {};

  /// Vide le cache de déduplication. À utiliser dans les tests uniquement.
  @visibleForTesting
  static void clearDedup() => _lastShown.clear();

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData? icon,
    DonySnackbarType type = DonySnackbarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final dedupKey = '${type.name}:$message';
    final now = DateTime.now();
    _lastShown.removeWhere(
      (_, dt) => now.difference(dt) > const Duration(seconds: 5),
    );
    if (_isDuplicate(dedupKey, now)) {
      return;
    }
    _lastShown[dedupKey] = now;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Avec l'option « garder les messages affichés », le message ne disparaît
    // plus tout seul : quatre secondes ne suffisent pas à qui lit lentement ou
    // navigue au lecteur d'écran (WCAG 2.2.1). Une action de fermeture
    // explicite remplace la disparition automatique.
    final persistent = context.a11y.persistentMessages;
    final effectiveDuration = persistent
        ? const Duration(minutes: 10)
        : duration;
    final effectiveActionLabel =
        actionLabel ?? (persistent ? context.l10n.commonClose : null);

    final (bg, fg, defaultIcon) = switch (type) {
      DonySnackbarType.info => (
        cs.inverseSurface,
        cs.onInverseSurface,
        Icons.info_outline,
      ),
      DonySnackbarType.success => (
        cs.success,
        DonyColors.white,
        Icons.check_circle_outline,
      ),
      DonySnackbarType.warning => (
        cs.warning,
        DonyColors.white,
        Icons.warning_amber_rounded,
      ),
      DonySnackbarType.error => (cs.error, cs.onError, Icons.error_outline),
    };

    final resolvedIcon = icon ?? defaultIcon;

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6],
              ),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(resolvedIcon, color: fg, size: 18),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null && title.isNotEmpty) ...[
                    Text(
                      title,
                      style: tt.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: tt.bodySmall?.copyWith(
                      color: title != null ? fg.withValues(alpha: 0.85) : fg,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    // Depuis une feuille ou une fenêtre modale, le snackbar du Scaffold de la
    // page s'affiche SOUS la feuille : invisible. Les erreurs du serveur et les
    // confirmations y passaient inaperçues (FLUTTER-4W : « je ne peux pas
    // confirmer », FLUTTER-4P). On l'affiche alors en haut de l'écran,
    // par-dessus la feuille.
    // Seulement si la feuille est encore la route active : après un `pop()`
    // suivi d'un message (motif courant « fermer puis confirmer »), la feuille
    // s'en va et le snackbar de la page redevient visible.
    final modal = ModalRoute.of(context);
    if (modal is PopupRoute && modal.isCurrent) {
      _showAboveModal(
        context,
        content: content,
        background: bg,
        foreground: fg,
        duration: effectiveDuration,
        actionLabel: effectiveActionLabel,
        onAction: onAction,
      );
      return;
    }

    // Messenger capturé à l'affichage : l'action « Fermer » est tapée plus
    // tard, quand le contexte appelant (tuile, volet) peut être démonté
    // (même classe de crash que FLUTTER-GN).
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: content,
          backgroundColor: bg,
          duration: effectiveDuration,
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          margin: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.lg,
          ),
          dismissDirection: DismissDirection.horizontal,
          action: effectiveActionLabel != null
              ? SnackBarAction(
                  label: effectiveActionLabel,
                  textColor: fg,
                  onPressed:
                      onAction ??
                      (persistent ? messenger.hideCurrentSnackBar : () {}),
                )
              : null,
        ),
      );
  }

  static OverlayEntry? _modalEntry;

  static void _hideAboveModal() {
    final entry = _modalEntry;
    _modalEntry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static void _showAboveModal(
    BuildContext context, {
    required Widget content,
    required Color background,
    required Color foreground,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _hideAboveModal();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ModalToast(
        content: content,
        background: background,
        foreground: foreground,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: () {
          if (identical(_modalEntry, entry)) _modalEntry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _modalEntry = entry;
    overlay.insert(entry);
  }

  static bool _isDuplicate(String key, DateTime now) {
    final last = _lastShown[key];
    if (last == null) {
      return false;
    }
    return now.difference(last) < const Duration(milliseconds: 400);
  }
}

/// Message affiché en haut de l'écran, au-dessus d'une feuille modale. Son
/// minuteur vit dans l'état du widget : il s'arrête avec lui, sans rester en
/// suspens quand l'écran est démonté.
class _ModalToast extends StatefulWidget {
  const _ModalToast({
    required this.content,
    required this.background,
    required this.foreground,
    required this.duration,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
  });

  final Widget content;
  final Color background;
  final Color foreground;
  final Duration duration;
  final VoidCallback onDismissed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ModalToast> createState() => _ModalToastState();
}

class _ModalToastState extends State<_ModalToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _anim.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + DonySpacing.sm;
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Positioned(
      top: top,
      left: DonySpacing.base,
      right: DonySpacing.base,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(curve),
          child: Semantics(
            liveRegion: true,
            child: Material(
              key: const Key('dony-snackbar-above-modal'),
              color: widget.background,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                onTap: _close,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: widget.content),
                      if (widget.actionLabel != null)
                        TextButton(
                          onPressed: () {
                            widget.onAction?.call();
                            unawaited(_close());
                          },
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(color: widget.foreground),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
