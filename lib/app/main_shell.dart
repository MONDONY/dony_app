import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    if (index == 1) {
      getIt<EnvoisRefreshNotifier>().requestRefresh();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _DonyBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

class _DonyBottomNav extends StatelessWidget {
  const _DonyBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.white,
        border: Border(top: BorderSide(color: DonyColors.grey100)),
        boxShadow: [
          BoxShadow(
            color: DonyColors.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              // 0 — Accueil
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  outlinedIcon: Icons.home_outlined,
                  label: 'Accueil',
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: () => onTap(0),
                ),
              ),
              // 1 — Envoyer
              Expanded(
                child: _NavItem(
                  icon: Icons.arrow_circle_right_rounded,
                  outlinedIcon: Icons.arrow_circle_right_outlined,
                  label: 'Envoyer',
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: () => onTap(1),
                ),
              ),
              // 2 — Trajets
              Expanded(
                child: _NavItem(
                  icon: Icons.send_rounded,
                  outlinedIcon: Icons.send_outlined,
                  label: 'Trajets',
                  index: 2,
                  currentIndex: currentIndex,
                  onTap: () => onTap(2),
                ),
              ),
              // 3 — Messages
              Expanded(
                child: _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  outlinedIcon: Icons.chat_bubble_outline_rounded,
                  label: 'Messages',
                  index: 3,
                  currentIndex: currentIndex,
                  onTap: () => onTap(3),
                ),
              ),
              // 4 — Moi
              Expanded(
                child: _NavItem(
                  icon: Icons.person_rounded,
                  outlinedIcon: Icons.person_outline_rounded,
                  label: 'Moi',
                  index: 4,
                  currentIndex: currentIndex,
                  onTap: () => onTap(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  bool get _active => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _active ? DonyColors.green100 : Colors.transparent,
              borderRadius: BorderRadius.circular(DonyRadius.xl),
            ),
            child: Icon(
              _active ? icon : outlinedIcon,
              size: 22,
              color: _active ? DonyColors.green400 : DonyColors.grey400,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
              color: _active ? DonyColors.green400 : DonyColors.grey400,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
