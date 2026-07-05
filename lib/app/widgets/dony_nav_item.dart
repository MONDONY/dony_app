import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Item de la bottom navigation bar dony (île flottante).
///
/// L'état actif est signalé par deux choses : (1) une pastille bleue
/// PARTAGÉE et glissante, peinte par le parent (`_DonyBottomNav` dans
/// `main_shell.dart`) derrière la [Row] d'items — donne la transition
/// « focus qui glisse » d'un onglet à l'autre au lieu d'un fondu indépendant
/// par item (audit UX bottom nav) — et (2) la couleur de l'icône/libellé de
/// CET item ([onPrimary]/[primary] actif, [onSurfaceVariant] inactif).
/// [pillWidth]/[pillHeight]/[pillTopInset] sont exposés pour que le parent
/// positionne son indicateur exactement sous l'icône, sans dépendre des
/// métriques de police (fragile, varie selon plateforme).
///
/// En mode avatar ([avatarName] renseigné), affiche la photo de profil (style
/// Facebook) avec un anneau primary à l'état actif — pas de pastille partagée
/// sur ce slot (le cercle avatar ne se marie pas avec une pilule).
///
/// Le libellé est toujours affiché sous l'icône. Rendu visuel exclu de
/// l'arbre sémantique ([ExcludeSemantics]) pour éviter la double annonce
/// avec le [Semantics.label] déjà posé sur tout l'item. Public pour pouvoir
/// être testé isolément.
class DonyNavItem extends StatelessWidget {
  const DonyNavItem({
    super.key,
    this.icon,
    this.outlinedIcon,
    this.iconAsset,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
    this.isPro = false,
    this.avatarUrl,
    this.avatarName,
  }) : assert(
         avatarName != null ||
             iconAsset != null ||
             (icon != null && outlinedIcon != null),
         'DonyNavItem requiert iconAsset, ou (icon + outlinedIcon), ou avatarName',
       );

  final IconData? icon;
  final IconData? outlinedIcon;

  /// Nom d'un SVG Lucide dans `assets/icons/` (sans extension). Prioritaire sur
  /// [icon]/[outlinedIcon] : Lucide n'a qu'une variante par icône, l'état
  /// actif/inactif est porté par la couleur (blanc sur la pastille active).
  final String? iconAsset;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isPro;

  /// Si renseigné, l'onglet affiche la photo de profil (style Facebook) au lieu
  /// de l'icône — anneau primary quand actif, initiales en repli sans photo.
  final String? avatarUrl;
  final String? avatarName;

  /// Largeur de la pastille icône — partagée avec l'indicateur glissant du parent.
  static const double pillWidth = 52;

  /// Hauteur de la pastille icône — idem.
  static const double pillHeight = 36;

  /// Offset vertical FIXE (non calculé/centré) entre le haut du slot et le
  /// haut de la pastille. Garantit que l'indicateur partagé du parent tombe
  /// pile sous l'icône, peu importe les métriques réelles de la police
  /// (labelSmall) qui varient légèrement selon iOS/Android.
  static const double pillTopInset = 11;

  bool get _active => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAvatar = avatarName != null;

    return Semantics(
      button: true,
      selected: _active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: pillTopInset),
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (isAvatar) _buildAvatar(cs) else _buildIconPill(cs),
                if (badgeCount > 0)
                  Positioned(
                    right: 2,
                    top: -2,
                    child: _NavBadge(count: badgeCount, ringColor: cs.surface),
                  ),
                if (isPro && !isAvatar)
                  Positioned(
                    right: 1,
                    top: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: DonyColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: const DonyIcon(
                        'star',
                        color: DonyColors.white,
                        size: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _active ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: _active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Icône seule — le fond (pastille bleue quand actif) est peint par le
  /// parent via l'indicateur partagé glissant, pas ici (cf. doc de classe).
  Widget _buildIconPill(ColorScheme cs) {
    final iconColor = _active ? cs.onPrimary : cs.onSurfaceVariant;
    final Widget iconWidget = iconAsset != null
        ? DonyIcon(
            iconAsset!,
            key: ValueKey('${index}_${_active ? 'a' : 'i'}'),
            size: 22,
            color: iconColor,
          )
        : Icon(
            _active ? icon : outlinedIcon,
            key: ValueKey('${index}_${_active ? 'a' : 'i'}'),
            size: 22,
            color: iconColor,
          );

    return SizedBox(
      width: pillWidth,
      height: pillHeight,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: iconWidget,
        ),
      ),
    );
  }

  /// Photo de profil + anneau primary à l'état actif — mode avatar.
  Widget _buildAvatar(ColorScheme cs) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _active ? cs.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: DonyAvatar(
        name: avatarName!,
        imageUrl: avatarUrl,
        size: DonyAvatarSize.xs,
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  final int count;
  final Color ringColor;
  const _NavBadge({required this.count, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: DonyColors.error,
        borderRadius: const BorderRadius.all(Radius.circular(DonyRadius.full)),
        border: Border.all(color: ringColor, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DonyColors.white,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
