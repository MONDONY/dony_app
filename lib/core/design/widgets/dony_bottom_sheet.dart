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
    bool isDismissible = true,
    bool showHandle = true,
    bool isScrollControlled = true,
    Widget? stickyBottom,
    Widget Function(Widget child)? wrapper,
  }) {
    Widget content = _DonyBottomSheetContent(
      title: title,
      subtitle: subtitle,
      showHandle: showHandle,
      stickyBottom: stickyBottom,
      child: child,
    );

    if (wrapper != null) {
      content = wrapper(content);
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (_) => content,
    );
  }
}

class _DonyBottomSheetContent extends StatelessWidget {
  const _DonyBottomSheetContent({
    required this.child,
    this.title,
    this.subtitle,
    this.showHandle = true,
    this.stickyBottom,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showHandle;
  final Widget? stickyBottom;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.only(top: DonySpacing.huge),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
        boxShadow: DonyShadow.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DonyColors.neutral300,
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
                        Text(title!, style: tt.headlineSmall),
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
                stickyBottom != null ? DonySpacing.sm : DonySpacing.xl + bottomInset,
              ),
              child: child,
            ),
          ),
          if (stickyBottom != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                bottomPadding + DonySpacing.base,
              ),
              child: stickyBottom,
            ),
        ],
      ),
    );
  }
}
