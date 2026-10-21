import 'package:dony/app/system_back_dispatcher.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
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
    this.showFeedback = true,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
  }) : assert(
         variant == DonyAppBarVariant.compact,
         'Use DonySliverAppBar for the large variant inside a CustomScrollView.', // i18n-ignore
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

  /// Scarabée de signalement de bug ([DonyFeedbackButton]) en fin d'actions.
  /// Actif partout par défaut : le désactiver seulement pour un écran où un
  /// rapport n'a pas de sens (verrouillage, splash…).
  final bool showFeedback;

  /// Titre centré entre le retour et les actions (écran de résultats) ;
  /// aligné à gauche par défaut.
  final bool centerTitle;

  /// Fond imposé (écran dont l'en-tête se prolonge dans un bandeau de couleur,
  /// ex. profil public). Avec lui, [foregroundColor] teinte titre, retour et
  /// actions, et le filet du bas disparaît pour que barre et bandeau ne fassent
  /// qu'un. Les deux se donnent ensemble.
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final onColor = foregroundColor;

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: onColor,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: onColor == null
            ? tt.headlineMedium
            : tt.headlineMedium?.copyWith(color: onColor),
      ),
      centerTitle: centerTitle,
      scrolledUnderElevation: 0,
      leading: showBackButton
          ? DonyAppBarBackButton(
              onBack: onBack,
              leadingIcon: leadingIcon,
              leadingIconAsset: leadingIconAsset,
              onColor: onColor,
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      actions: withFeedbackButton(actions, showFeedback),
      bottom:
          bottom ??
          (backgroundColor != null
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1),
                )),
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
    this.onColor,
  });

  final VoidCallback? onBack;
  final IconData? leadingIcon;
  final String? leadingIconAsset;

  /// Couleur du chevron quand la barre a un fond imposé : le carré passe en
  /// voile translucide de cette couleur au lieu de `primaryContainer`.
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = onColor ?? cs.primary;
    final l = context.l10n;
    return IconButton(
      tooltip: leadingIcon != null ? l.commonClose : l.commonBack,
      onPressed: () {
        HapticFeedback.lightImpact();
        if (onBack != null) {
          onBack!();
        } else if (context.canPop()) {
          context.pop();
        } else {
          _goFallback(context);
        }
      },
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onColor == null
              ? cs.primaryContainer
              : onColor!.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
        ),
        child: leadingIconAsset != null
            ? DonyIcon(leadingIconAsset!, size: 20, color: iconColor)
            : Icon(
                leadingIcon ?? Icons.chevron_left_rounded,
                size: 20,
                color: iconColor,
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
    this.showFeedback = true,
  });

  final String title;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double expandedHeight;

  /// Scarabée de signalement de bug en fin d'actions, comme [DonyAppBar].
  final bool showFeedback;

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
              tooltip: context.l10n.commonBack,
              onPressed:
                  onBack ??
                  () {
                    HapticFeedback.lightImpact();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      _goFallback(context);
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
      actions: withFeedbackButton(actions, showFeedback),
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

/// Ajoute le [DonyFeedbackButton] en fin d'[actions] quand [showFeedback]
/// est vrai, sans doublon si l'appelant l'a déjà placé lui-même.
List<Widget>? withFeedbackButton(List<Widget>? actions, bool showFeedback) {
  if (!showFeedback) {
    return actions;
  }
  final current = actions ?? const <Widget>[];
  if (current.any((w) => w is DonyFeedbackButton)) {
    return current;
  }
  return [...current, const DonyFeedbackButton()];
}

/// Repli du bouton retour quand la pile est vide : le même que celui du retour
/// système Android (`backFallbackFor`), l'accueil à défaut.
void _goFallback(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  context.go(backFallbackFor(location) ?? '/home');
}
