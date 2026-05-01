import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Utility class for responsive layout helpers used throughout the dony design system.
abstract final class DonyLayout {
  /// Returns the horizontal padding for the current screen width.
  /// Uses a wider padding on tablets/large screens.
  static double hPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return DonySpacing.xxl; // tablet: 32pt
    return DonySpacing.lg; // phone: 20pt
  }

  /// Returns the keyboard-induced bottom inset to avoid overlap with inputs.
  static double keyboardPadding(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom;
  }

  /// Returns the current screen width.
  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  /// Wraps [child] in a centered max-width container for tablet layouts.
  /// On phones (< 600pt), returns [child] unchanged.
  static Widget constrained(BuildContext context, Widget child) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }
}
