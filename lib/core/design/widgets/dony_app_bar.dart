import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar standardisé dony.
///
/// Deux variantes :
/// - [DonyAppBarVariant.compact] — barre fine 56px (écrans secondaires)
/// - [DonyAppBarVariant.large]   — barre expansible avec grand titre (écrans principaux)
enum DonyAppBarVariant { compact, large }

class DonyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DonyAppBar({
    super.key,
    required this.title,
    this.variant = DonyAppBarVariant.compact,
    this.onBack,
    this.showBackButton = true,
    this.actions,
    this.bottom,
  }) : assert(
         variant == DonyAppBarVariant.compact,
         'Use DonySliverAppBar for the large variant inside a CustomScrollView.',
       );

  final String title;
  final DonyAppBarVariant variant;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        56 + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AppBar(
      title: Text(title, style: tt.headlineMedium),
      centerTitle: false,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              onPressed: onBack ?? () {
                if (context.canPop()) context.pop();
                else context.go('/home');
              },
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      bottom: bottom ??
          const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
    );
  }
}

/// Variante SliverAppBar avec grand titre expansible (écrans principaux).
class DonySliverAppBar extends StatelessWidget {
  const DonySliverAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton = false,
    this.actions,
    this.bottom,
    this.expandedHeight = 110,
  });

  final String title;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              onPressed: onBack ?? () {
                if (context.canPop()) context.pop();
                else context.go('/home');
              },
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.base,
        ),
        title: Text(title, style: tt.headlineMedium),
        collapseMode: CollapseMode.pin,
      ),
      bottom: bottom ??
          PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: DonyColors.borderDefault, height: 1),
          ),
    );
  }
}
