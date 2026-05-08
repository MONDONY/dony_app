import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  StreamSubscription<void>? _fcmSub;

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    if (index == 1) {
      getIt<EnvoisRefreshNotifier>().requestRefresh();
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<NotificationBloc>().add(const NotificationsLoadRequested());
      _fcmSub = getIt<NotificationService>().newNotificationStream.listen((_) {
        if (mounted) {
          context.read<NotificationBloc>().add(const NotificationsLoadRequested());
        }
      });
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: _DonyBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
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
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated
            ? authState.user
            : authState is AuthProfileUpdated
                ? authState.user
                : null;
        final isTraveler = user?.isTraveler ?? false;
        final isSender = user?.isSender ?? false;
        // Priorité voyageur en cas de dual-role (cohérent avec home_screen.dart)
        final showTravelerNav = isTraveler;
        final isDualRole = isTraveler && isSender;

        // Tab 1 — Envoyer (sender) ou Trajets (traveler)
        final tab1Label = showTravelerNav ? 'Trajets' : 'Envoyer';
        final tab1Icon = showTravelerNav
            ? Icons.send_rounded
            : Icons.arrow_circle_right_rounded;
        final tab1IconOutlined = showTravelerNav
            ? Icons.send_outlined
            : Icons.arrow_circle_right_outlined;

        // Tab 2 — Suivi (libellé fixe, icône role-aware)
        final tab2Icon = showTravelerNav
            ? Icons.qr_code_scanner_rounded
            : Icons.track_changes_rounded;

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
              // 1 — Envoyer (sender) | Trajets (traveler)
              Expanded(
                child: _NavItem(
                  icon: tab1Icon,
                  outlinedIcon: tab1IconOutlined,
                  label: tab1Label,
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: () => onTap(1),
                ),
              ),
              // 2 — Suivi (QR scan pour voyageur, recherche pour expéditeur)
              Expanded(
                child: _NavItem(
                  icon: tab2Icon,
                  outlinedIcon: tab2Icon,
                  label: 'Suivi',
                  index: 2,
                  currentIndex: currentIndex,
                  onTap: () {
                    if (isDualRole) {
                      onTap(2);
                    } else if (showTravelerNav) {
                      context.push('/tracking/scan');
                    } else if (isSender) {
                      context.push('/tracking/search');
                    } else {
                      onTap(2);
                    }
                  },
                ),
              ),
              // 3 — Messages
              Expanded(
                child: StreamBuilder<int>(
                  stream: getIt<FirestoreChatRepository>().totalUnreadStream(
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                  builder: (context, snapshot) {
                    return _NavItem(
                      icon: Icons.chat_bubble_rounded,
                      outlinedIcon: Icons.chat_bubble_outline_rounded,
                      label: 'Messages',
                      index: 3,
                      currentIndex: currentIndex,
                      onTap: () => onTap(3),
                      badgeCount: snapshot.data ?? 0,
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
      },
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    _active ? icon : outlinedIcon,
                    key: ValueKey('${index}_${_active ? 'a' : 'i'}'),
                    size: 22,
                    color: _active ? DonyColors.primary : DonyColors.neutral700,
                  ),
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
