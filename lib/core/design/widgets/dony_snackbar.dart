import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum DonySnackbarType { info, success, warning, error }

abstract final class DonySnackbar {
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (bg, fg, accent, accentSoft) = switch (type) {
      DonySnackbarType.info => (
          cs.inverseSurface,
          cs.onInverseSurface,
          cs.info,
          cs.infoLight,
        ),
      DonySnackbarType.success => (
          cs.success,
          DonyColors.white,
          DonyColors.white,
          DonyColors.white.withValues(alpha: 0.18),
        ),
      DonySnackbarType.warning => (
          cs.warning,
          DonyColors.white,
          DonyColors.white,
          DonyColors.white.withValues(alpha: 0.22),
        ),
      DonySnackbarType.error => (
          cs.error,
          cs.onError,
          cs.onError,
          cs.onError.withValues(alpha: 0.18),
        ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: DonySpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null && title.isNotEmpty)
                      Text(
                        title,
                        style: tt.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    if (title != null && title.isNotEmpty)
                      const SizedBox(height: 2),
                    Text(
                      message,
                      style: tt.bodySmall?.copyWith(
                        color: fg,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          duration: duration,
          behavior: SnackBarBehavior.floating,
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
}
