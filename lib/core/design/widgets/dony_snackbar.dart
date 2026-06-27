import 'package:dony/core/design/design_system.dart';
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
      DonySnackbarType.error => (
          cs.error,
          cs.onError,
          Icons.error_outline,
        ),
    };

    final resolvedIcon = icon ?? defaultIcon;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Stack(
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
                            color: title != null
                                ? fg.withValues(alpha: 0.85)
                                : fg,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: bg,
          duration: duration,
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
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: fg,
                  onPressed: onAction ?? () {},
                )
              : null,
        ),
      );
  }

  static bool _isDuplicate(String key, DateTime now) {
    final last = _lastShown[key];
    if (last == null) {
      return false;
    }
    return now.difference(last) < const Duration(milliseconds: 400);
  }
}
