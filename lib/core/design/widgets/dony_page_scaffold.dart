import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Scaffold standardisé pour les écrans secondaires dony.
///
/// Fournit automatiquement :
/// - [DonyAppBar] avec back button
/// - Fond [DonyColors.bgApp]
/// - Padding horizontal + bottom safe area
///
/// Pour les écrans principaux (avec SliverAppBar),
/// construire le CustomScrollView directement.
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

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.fromLTRB(
          DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
        );

    final content = scrollable
        ? SingleChildScrollView(
            padding: effectivePadding,
            child: body,
          )
        : Padding(padding: effectivePadding, child: body);

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: DonyAppBar(
        title: title,
        onBack: onBack,
        showBackButton: showBackButton,
        actions: appBarActions,
        bottom: appBarBottom,
      ),
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
