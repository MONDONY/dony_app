import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Helper pour afficher un bottom sheet standardisé Yadony.
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
    bool enableDrag = true,
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
      enableDrag: enableDrag,
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
        : cs.onSurfaceVariant.withValues(alpha: 0.4);

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
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.base,
                0,
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
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    // `maybePop` consulte `PopScope`, contrairement à `pop` :
                    // une feuille qui protège une saisie en cours ne se fait
                    // donc plus vider par sa propre croix.
                    onPressed: () => Navigator.maybePop(context),
                    icon: const DonyIcon('x', size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
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
              // Faire défiler la feuille referme le clavier : sans ça, une
              // saisie en cours garde le clavier collé par-dessus les champs
              // suivants et les listes d'autocomplétion.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                title != null ? 0 : DonySpacing.sm,
                DonySpacing.lg,
                stickyBottom != null
                    ? DonySpacing.xl
                    : DonySpacing.xl + bottomInset,
              ),
              // Material ancestor so ListTiles in sheet content paint ink above
              // the sheet's colored Container (Flutter 3.44 ListTile assertion).
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
          if (stickyBottom != null)
            Container(
              key: const Key('donyBottomSheetFooter'),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(top: BorderSide(color: cs.outline)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              // bottomInset gère le padding vertical (viewInsets + viewPadding).
              // SafeArea(top:false, bottom:false) protège uniquement les encoches
              // latérales/découpes (left/right par défaut) sur foldables et certains
              // Android ; les insets haut/bas sont gérés manuellement ci-dessus.
              padding: EdgeInsets.fromLTRB(
                0,
                DonySpacing.md,
                0,
                bottomInset + DonySpacing.base,
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.lg,
                  ),
                  child: stickyBottom,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
