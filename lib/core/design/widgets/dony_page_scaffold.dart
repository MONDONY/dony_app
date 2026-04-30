import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Scaffold standardisé pour les écrans secondaires dony.
///
/// - [DonyAppBar] avec back button
/// - Fond [DonyColors.bgApp]
/// - Padding horizontal adaptatif (responsive via [DonyLayout])
/// - Bottom padding = safe area + keyboard inset (keyboard ne cache jamais les inputs)
/// - Max-width centré sur tablette
class DonyPageScaffold extends StatelessWidget {
  const DonyPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.showBackButton = true,
    this.appBarActions,
    this.appBarBottom,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding,
    this.scrollable = true,
    this.resizeToAvoidBottomInset = true,
    this.stickyBottom,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget>? appBarActions;
  final PreferredSizeWidget? appBarBottom;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsets? padding;
  final bool scrollable;
  final bool resizeToAvoidBottomInset;

  /// Widget épinglé en bas (ex: bouton CTA principal).
  /// Toujours visible au-dessus du clavier.
  final Widget? stickyBottom;

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final effectivePadding = padding ??
        EdgeInsets.fromLTRB(h, DonySpacing.xl, h, DonySpacing.lg);

    Widget content = scrollable
        ? SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: effectivePadding.copyWith(
              // Ajouter l'inset clavier en bas pour que l'input reste visible
              bottom: effectivePadding.bottom +
                  DonyLayout.keyboardPadding(context),
            ),
            child: DonyLayout.constrained(context, body),
          )
        : Padding(
            padding: effectivePadding,
            child: DonyLayout.constrained(context, body),
          );

    Widget scaffold = Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: DonyColors.bgApp,
      appBar: DonyAppBar(
        title: title,
        onBack: onBack,
        showBackButton: showBackButton,
        actions: appBarActions,
        bottom: appBarBottom,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: stickyBottom == null
          ? content
          : Column(
              children: [
                Expanded(child: content),
                _StickyBottomBar(child: stickyBottom!),
              ],
            ),
    );

    return scaffold;
  }
}

/// Barre fixe en bas avec fond blanc, ombre douce, et respect du safe area.
class _StickyBottomBar extends StatelessWidget {
  const _StickyBottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.surface,
        border: Border(top: BorderSide(color: DonyColors.borderDefault)),
        boxShadow: DonyShadows.sticky,
      ),
      padding: EdgeInsets.fromLTRB(
        DonyLayout.hPadding(context),
        DonySpacing.md,
        DonyLayout.hPadding(context),
        DonySpacing.md + bottom,
      ),
      child: DonyLayout.constrained(context, child),
    );
  }
}
