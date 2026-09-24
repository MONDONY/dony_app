import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Single entry point for showing errors to the user.
///
/// All BLoC listeners that previously did
///
///     DonySnackbar.show(context, message: state.message, type: ...)
///
/// should switch to
///
///     ErrorPresenter.show(context, state.error)
///
/// The presenter resolves the error through [ErrorCatalog] and picks the
/// appropriate UI (snackbar vs. dialog) based on the severity.
abstract final class ErrorPresenter {
  /// Show [error] using the right widget for its severity.
  ///
  /// - Returns the user choice for `critical` errors (dialog) — the optional
  ///   [actionLabel]/[onAction] turn into a confirm button.
  /// - Returns `null` immediately for `info`/`warning`/`error` (snackbar).
  ///
  /// [error] can be an [AppException], a [DioException], or anything else.
  static Future<bool?> show(
    BuildContext context,
    Object? error, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration snackbarDuration = const Duration(seconds: 4),
  }) async {
    final unwrapped = _unwrap(error);
    final l10n = context.l10n;
    final p = ErrorCatalog.lookup(unwrapped, l10n: l10n);

    // Always log raw details in debug — never in prod and never to the user.
    if (kDebugMode && unwrapped is AppException) {
      debugPrint(
        '[ErrorPresenter] code=${unwrapped.code} '
        'severity=${p.severity.name} raw="${unwrapped.message}"',
      );
    }

    if (p.severity == ErrorSeverity.critical) {
      return DonyDialog.show(
        context,
        title: p.title,
        message: p.message,
        confirmLabel: actionLabel ?? l10n.commonOk,
        cancelLabel: actionLabel != null ? l10n.commonClose : l10n.commonOk,
        variant: DonyDialogVariant.destructive,
        icon: p.icon,
      ).then((confirmed) {
        if (confirmed == true && onAction != null) onAction();
        return confirmed;
      });
    }

    DonySnackbar.show(
      context,
      title: p.title,
      message: p.message,
      icon: p.icon,
      type: _toSnackbarType(p.severity),
      duration: snackbarDuration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    return null;
  }

  /// Resolve [error] without showing anything. Useful when a screen wants to
  /// inline-render the error (e.g. an `AnnouncementError` widget). Pass
  /// `context.l10n` as [l10n] to follow the app language; without it the
  /// catalog falls back to [AppL10n.current].
  static ErrorPresentation resolve(Object? error, {AppLocalizations? l10n}) =>
      ErrorCatalog.lookup(_unwrap(error), l10n: l10n);

  static Object? _unwrap(Object? error) {
    if (error == null) return null;
    if (error is AppException) return error;
    return unwrapDioError(error);
  }

  static DonySnackbarType _toSnackbarType(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return DonySnackbarType.info;
      case ErrorSeverity.warning:
        return DonySnackbarType.warning;
      case ErrorSeverity.error:
      case ErrorSeverity.critical:
        return DonySnackbarType.error;
    }
  }
}
