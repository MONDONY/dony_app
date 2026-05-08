import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Helper pour afficher un bottom sheet standardisé dony.
///
/// Usage :
/// ```dart
/// DonyBottomSheet.show(
///   context,
///   title: 'Trier par',
///   stickyBottom: DonyButton(label: 'Confirmer', onPressed: ...),
///   child: SortOptions(),
/// );
/// ```
abstract final class DonyBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    Widget? stickyBottom,
    bool isDismissible = true,
    bool showHandle = true,
    bool isScrollControlled = true,
    bool isDanger = false,
    double? heightFraction,
    Widget Function(Widget)? wrapper,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      constraints: heightFraction != null
          ? BoxConstraints(
              minHeight: screenHeight * heightFraction,
              maxHeight: screenHeight * heightFraction,
            )
          : null,
      builder: (ctx) {
        final Widget content = _DonyBottomSheetContent(
          title: title,
          subtitle: subtitle,
          showHandle: showHandle,
          isDanger: isDanger,
          expand: heightFraction != null,
          stickyBottom: stickyBottom,
          child: child,
        );
        return wrapper != null ? wrapper(content) : content;
      },
    );
  }
}

class _DonyBottomSheetContent extends StatelessWidget {
  const _DonyBottomSheetContent({
    required this.child,
    this.title,
    this.subtitle,
    this.stickyBottom,
    this.showHandle = true,
    this.isDanger = false,
    this.expand = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? stickyBottom;
  final bool showHandle;
  final bool isDanger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final topMargin = mq.size.height * 0.1;

    final bgColor = isDanger ? cs.errorContainer : cs.surface;
    final handleColor = isDanger
        ? cs.error.withValues(alpha: 0.35)
        : DonyColors.neutral300;

    return Container(
      margin: expand ? EdgeInsets.zero : EdgeInsets.only(top: topMargin),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
        boxShadow: DonyShadow.sheet,
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
              ),
            ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, DonySpacing.base, DonySpacing.base, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: tt.headlineSmall?.copyWith(
                            color: isDanger ? cs.error : null,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            subtitle!,
                            style: tt.bodySmall?.copyWith(
                              color: DonyColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: DonyColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: DonySpacing.base),
          ] else
            const SizedBox(height: DonySpacing.sm),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                title != null ? 0 : DonySpacing.sm,
                DonySpacing.lg,
                stickyBottom != null ? DonySpacing.xl : DonySpacing.xl + bottomInset,
              ),
              child: child,
            ),
          ),
          if (stickyBottom != null)
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(color: DonyColors.neutral200, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                bottomInset + DonySpacing.base,
              ),
              child: stickyBottom!,
            ),
        ],
      ),
    );
  }
}
