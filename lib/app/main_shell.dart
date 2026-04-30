import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        border: Border(top: BorderSide(color: DonyColors.borderDefault)),
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
                child: StreamBuilder<int>(
                  stream: getIt<FirestoreChatRepository>().totalUnreadStream(
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return _NavItem(
                      icon: Icons.chat_bubble_rounded,
                      outlinedIcon: Icons.chat_bubble_outline_rounded,
                      label: 'Messages',
                      index: 3,
                      currentIndex: currentIndex,
                      onTap: () => onTap(3),
                      badgeCount: unreadCount,
                    );
                  },
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final int badgeCount;

  bool get _active => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _active ? DonyColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(DonyRadius.xl),
                ),
                child: Icon(
                  _active ? icon : outlinedIcon,
                  size: 22,
                  color: _active ? DonyColors.primary : DonyColors.textSubtle,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: _NavBadge(count: badgeCount),
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
