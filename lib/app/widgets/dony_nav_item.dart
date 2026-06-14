import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Item de la bottom navigation bar dony.
///
/// Affiche soit une icône (filled si actif, outlined sinon), soit — quand
/// [avatarName] est renseigné — la photo de profil de l'utilisateur (style
/// Facebook) avec un anneau bleu à l'état actif et les initiales en repli si
/// aucune photo. Public pour pouvoir être testé isolément.
class DonyNavItem extends StatelessWidget {
  const DonyNavItem({
    super.key,
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
    this.isPro = false,
    this.avatarUrl,
    this.avatarName,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isPro;

  /// Si renseigné, l'onglet affiche la photo de profil (style Facebook) au lieu
  /// de l'icône — anneau bleu quand actif, initiales en repli sans photo.
  final String? avatarUrl;
  final String? avatarName;

  bool get _active => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Barre indicatrice en haut (style Coclis)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 3,
            decoration: BoxDecoration(
              color: _active ? DonyColors.primary : Colors.transparent,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
          ),
          // Icône/avatar + label centrés dans l'espace restant
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.md,
                        vertical: DonySpacing.xs,
                      ),
                      child: avatarName != null
                          ? AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _active
                                      ? DonyColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: DonyAvatar(
                                name: avatarName!,
                                imageUrl: avatarUrl,
                                size: DonyAvatarSize.xs,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: Icon(
                                _active ? icon : outlinedIcon,
                                key: ValueKey(
                                  '${index}_${_active ? 'a' : 'i'}',
                                ),
                                size: 22,
                                color: _active
                                    ? DonyColors.primary
                                    : DonyColors.textSubtle,
                              ),
                            ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: _NavBadge(count: badgeCount),
                      ),
                    if (isPro && avatarName == null)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: DonyColors.warning,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: DonyColors.white,
                            size: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DonySpacing.xxs),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
                    color: _active ? DonyColors.primary : DonyColors.textSubtle,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  final int count;
  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: DonyColors.error,
        borderRadius: BorderRadius.all(Radius.circular(DonyRadius.sm)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DonyColors.white,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
