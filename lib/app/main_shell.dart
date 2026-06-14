import 'dart:async';
import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_disabled_banner.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_rejected_banner.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  StreamSubscription<void>? _fcmSub;
  bool _ratingPromptShown = false;

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    if (index == 1) {
      getIt<EnvoisRefreshNotifier>().requestRefresh();
    }
    if (index == 0) {
      // Accueil : la liste des bids de l'expéditeur est mise en cache au premier
      // montage (home reste vivant dans le nav shell). Si un voyageur refuse une
      // demande à distance, le cache reste sur « en attente ». Force un refresh à
      // chaque (ré)sélection de l'onglet pour refléter le vrai statut.
      context.read<BidBloc>().add(
        const BidMyListAutoRefreshRequested(force: true),
      );
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<NotificationBloc>().add(const NotificationsLoadRequested());
      context.read<RatingBloc>().add(const PendingRatingChecked());
      context.read<StripeAccountBloc>().add(const StripeAccountStatusLoaded());
      _fcmSub = getIt<NotificationService>().newNotificationStream.listen((_) {
        if (mounted) {
          context.read<NotificationBloc>().add(
            const NotificationsLoadRequested(),
          );
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<StripeAccountBloc>().add(
        const StripeAccountStatusRefreshed(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RatingBloc, RatingState>(
          listener: (context, state) {
            if (state is PendingRatingFound && !_ratingPromptShown) {
              _ratingPromptShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                RatingBottomSheet.show(
                  context,
                  bidId: state.bidId,
                  travelerName: state.otherPartyName,
                  isTravelerRating: state.isTravelerRating,
                );
              });
            }
          },
        ),
      ],
      child: BlocBuilder<StripeAccountBloc, StripeAccountState>(
        buildWhen: (prev, curr) {
          if (prev is StripeAccountReady && curr is StripeAccountReady) {
            return prev.accountStatus.isDisabled !=
                    curr.accountStatus.isDisabled ||
                prev.accountStatus.isRejected != curr.accountStatus.isRejected;
          }
          return prev.runtimeType != curr.runtimeType;
        },
        builder: (context, accountState) {
          Widget? banner;
          if (accountState is StripeAccountReady) {
            if (accountState.accountStatus.isDisabled) {
              banner = const AccountDisabledBanner();
            } else if (accountState.accountStatus.isRejected) {
              banner = const AccountRejectedBanner();
            }
          }
          return Scaffold(
            body: Column(
              children: [
                ?banner,
                Expanded(child: widget.navigationShell),
              ],
            ),
            bottomNavigationBar: _DonyBottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
            ),
          );
        },
      ),
    );
  }
}

class _DonyBottomNav extends StatelessWidget {
  const _DonyBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (p, c) =>
          (p is AuthAuthenticated) != (c is AuthAuthenticated) ||
          (c is AuthAuthenticated &&
              (p as AuthAuthenticated?)?.user.isProAccount !=
                  c.user.isProAccount) ||
          (c is AuthProfileUpdated),
      builder: (context, authState) {
        UserModel? authUser;
        if (authState is AuthAuthenticated) authUser = authState.user;
        if (authState is AuthProfileUpdated) authUser = authState.user;
        final isProAccount = authUser?.isProAccount ?? false;

        return BlocBuilder<ActiveRoleCubit, ActiveRole>(
          builder: (context, activeRole) {
            final isTraveler = activeRole == ActiveRole.traveler;

            // Tab 1 — Activités (libellé+icône figés ; le contenu s'adapte au profil
            // dans MatchingManagementScreen — Phase 2)
            const tab1Label = 'Activités';
            const tab1Icon = Icons.bolt_rounded;
            const tab1IconOutlined = Icons.bolt_outlined;

            // Tab 2 — Suivi (libellé + icône figés ; contenu adapté au profil
            // dans SuiviScreen — voir spec Phase 3). Icône « cible/radar » =
            // sens suivi/tracking neutre (ni scan ni colis).
            const tab2Icon = Icons.track_changes_rounded;

            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xB8FFFFFF),
                    border: Border(
                      top: BorderSide(color: Color(0x99FFFFFF), width: 1),
                    ),
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
                          // 2 — Suivi (toujours in-shell ; SuiviScreen adapte le contenu au profil)
                          Expanded(
                            child: _NavItem(
                              icon: tab2Icon,
                              outlinedIcon: tab2Icon,
                              label: 'Suivi',
                              index: 2,
                              currentIndex: currentIndex,
                              onTap: () => onTap(2),
                            ),
                          ),
                          // 3 — Messages
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                final messagesItem = _NavItem(
                                  icon: Icons.chat_bubble_rounded,
                                  outlinedIcon:
                                      Icons.chat_bubble_outline_rounded,
                                  label: 'Messages',
                                  index: 3,
                                  currentIndex: currentIndex,
                                  onTap: () => onTap(3),
                                );
                                if (uid == null || uid.isEmpty) {
                                  // Pendant le sign-out : pas de stream Firestore (path vide invalide).
                                  return messagesItem;
                                }
                                return StreamBuilder<int>(
                                  stream: getIt<FirestoreChatRepository>()
                                      .totalUnreadStream(uid),
                                  builder: (context, snapshot) {
                                    return _NavItem(
                                      icon: Icons.chat_bubble_rounded,
                                      outlinedIcon:
                                          Icons.chat_bubble_outline_rounded,
                                      label: 'Messages',
                                      index: 3,
                                      currentIndex: currentIndex,
                                      onTap: () => onTap(3),
                                      badgeCount: snapshot.data ?? 0,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          // 4 — Moi (photo de profil style Facebook)
                          Expanded(
                            child: _NavItem(
                              icon: Icons.person_rounded,
                              outlinedIcon: Icons.person_outline_rounded,
                              label: 'Moi',
                              index: 4,
                              currentIndex: currentIndex,
                              onTap: () => onTap(4),
                              isPro: isProAccount,
                              avatarUrl: authUser?.avatarUrl,
                              avatarName: authUser?.displayName,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
          // Icône + label centrés dans l'espace restant
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
