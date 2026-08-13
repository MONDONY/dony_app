import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// AppBar standardisé Yadony.
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
    this.leadingIcon,
    this.leadingIconAsset,
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

  /// Override l'icône du bouton retour (ex: Icons.close_rounded pour les modals).
  final IconData? leadingIcon;

  /// Override l'icône retour via un SVG Lucide (`assets/icons/<nom>.svg`).
  /// Prioritaire sur [leadingIcon].
  final String? leadingIconAsset;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AppBar(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.headlineMedium,
      ),
      centerTitle: false,
      scrolledUnderElevation: 0,
      leading: showBackButton
          ? DonyAppBarBackButton(
              onBack: onBack,
              leadingIcon: leadingIcon,
              leadingIconAsset: leadingIconAsset,
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      bottom:
          bottom ??
          const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
    );
  }
}

/// Bouton retour stylé Yadony (carré [ColorScheme.primaryContainer] + chevron).
/// À placer en `leading` d'une AppBar custom pour rester cohérent avec
/// [DonyAppBar] (qui l'utilise en interne).
class DonyAppBarBackButton extends StatelessWidget {
  const DonyAppBarBackButton({
    super.key,
    this.onBack,
    this.leadingIcon,
    this.leadingIconAsset,
  });

  final VoidCallback? onBack;
  final IconData? leadingIcon;
  final String? leadingIconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: leadingIcon != null ? 'Fermer' : 'Retour',
      onPressed: () {
        HapticFeedback.lightImpact();
        if (onBack != null) {
          onBack!();
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
        ),
        child: leadingIconAsset != null
            ? DonyIcon(leadingIconAsset!, size: 20, color: cs.primary)
            : Icon(
                leadingIcon ?? Icons.chevron_left_rounded,
                size: 20,
                color: cs.primary,
              ),
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
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Retour',
              onPressed:
                  onBack ??
                  () {
                    HapticFeedback.lightImpact();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: cs.primary,
                ),
              ),
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          0,
          DonySpacing.lg,
          DonySpacing.base,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.headlineMedium,
        ),
        collapseMode: CollapseMode.pin,
      ),
      bottom:
          bottom ??
          PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: Theme.of(context).colorScheme.outline,
              height: 1,
            ),
          ),
    );
  }
}
