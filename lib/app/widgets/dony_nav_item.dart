import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Item de la bottom navigation bar dony (île flottante).
///
/// État actif = pastille pleine (fond [ColorScheme.primary], icône [onPrimary]).
/// État inactif = icône discrète ([onSurfaceVariant]). En mode avatar
/// ([avatarName] renseigné), affiche la photo de profil (style Facebook) avec un
/// anneau primary à l'état actif et les initiales en repli sans photo.
///
/// Le libellé n'est pas rendu visuellement (design sans texte) mais reste exposé
/// via [Semantics] pour l'accessibilité. Public pour pouvoir être testé isolément.
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
        child: Center(
          child: Stack(
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
        ),
      ),
    );
  }

  /// Pastille pleine (fond primary actif, icône blanche) — mode icône.
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 52,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _active ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _active
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: iconWidget,
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
