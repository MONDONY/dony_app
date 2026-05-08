import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum DonySnackbarType { info, success, warning, error }

abstract final class DonySnackbar {
  static void show(
    BuildContext context, {
    required String message,
    DonySnackbarType type = DonySnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final cs = Theme.of(context).colorScheme;

    final (bg, fg) = switch (type) {
      DonySnackbarType.info    => (cs.inverseSurface,  cs.onInverseSurface),
      DonySnackbarType.success => (DonyColors.success, DonyColors.white),
      DonySnackbarType.warning => (DonyColors.warning, DonyColors.white),
      DonySnackbarType.error   => (cs.error,           cs.onError),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: fg)),
          backgroundColor: bg,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sm),
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
