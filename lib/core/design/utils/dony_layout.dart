import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Utility class for responsive layout helpers used throughout the Yadony design system.
abstract final class DonyLayout {
  /// Returns true when the screen width is < 600 (phone/compact).
  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600;
  }

  /// Returns true when the screen width is between 600 and 839 (small tablet).
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 840;
  }

  /// Returns true when the screen width is >= 840 (large tablet / desktop).
  static bool isExpanded(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 840;
  }

  /// Returns the horizontal padding for the current screen width.
  /// Uses wider padding on larger screens:
  /// - compact (< 600): 20pt
  /// - medium (600–839): 32pt
  /// - expanded (>= 840): 48pt
  static double hPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 840) return DonySpacing.huge; // expanded: 48pt
    if (width >= 600) return DonySpacing.xxl;  // medium: 32pt
    return DonySpacing.lg; // compact: 20pt
  }

  /// Returns the keyboard-induced bottom inset to avoid overlap with inputs.
  static double keyboardPadding(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom;
  }

  /// Returns the system bottom safe-area padding (e.g. home indicator on iOS).
  static double bottomSafe(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom;
  }

  /// Returns the current screen width.
  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  /// Returns the current screen height.
  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  /// Returns the maximum content width for the current breakpoint.
  /// - compact: double.infinity (full width)
  /// - medium/expanded: 560pt (centered card layout)
  static double maxContentWidth(BuildContext context) {
    if (isCompact(context)) return double.infinity;
    return 560;
  }

  /// Wraps [child] in a centered max-width container for tablet layouts.
  /// On phones (< 600pt), returns [child] unchanged.
  static Widget constrained(BuildContext context, Widget child) {
    if (isCompact(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }
}
