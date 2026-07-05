import 'dart:async';
import 'dart:ui';

import 'package:dony/app/widgets/dony_nav_item.dart';
import 'package:dony/app/widgets/dony_nav_orb.dart';
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
            // Le contenu passe DERRIÈRE la bottom nav flottante (île
            // glass) : pas de bande opaque qui masque la liste. Scaffold
            // injecte la hauteur de la nav dans MediaQuery.padding.bottom
            // du body, donc les écrans en SafeArea réservent l'espace.
            extendBody: true,
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

/// Bottom nav « île flottante » : barre arrondie détachée du bord, en glass
/// (BackdropFilter), avec une pastille pleine sur l'onglet actif et un orb
/// central glossy (onglet Suivi / scan QR) en relief. Theme-aware : couleurs et
/// translucidité dérivées du [ColorScheme] / brightness courants.
class _DonyBottomNav extends StatelessWidget {
  const _DonyBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Opacité relevée (0.74/0.82 → 0.90) : la barre glass se fondait dans les
    // fonds chargés (carte, listes colorées) derrière — cf. audit UX bottom nav.
    final islandBg = cs.surface.withValues(alpha: 0.90);
    final islandBorder = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.white.withValues(alpha: 0.65);

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
            // Tab 1 — Activités (libellé+icône figés ; le contenu s'adapte au
            // profil dans MatchingManagementScreen — Phase 2)
            // 'zap' remplacé par 'layout-grid' : l'éclair se lisait
            // « action rapide/boost », pas « mes trajets » — cf. audit UX bottom nav.
            const tab1Label = 'Activités';
            const tab1IconAsset = 'layout-grid';

            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                16,
                14,
                bottomPadding > 0 ? bottomPadding : 14,
              ),
              child: SizedBox(
                // 76 → 86 : +10 pour le libellé désormais toujours visible
                // sous chaque icône (barre 64 → 74).
                height: 86,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Barre île (glass) alignée en bas
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.50)
                                  : DonyColors.ink800.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                              spreadRadius: -6,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                            child: Container(
                              height: 74,
                              decoration: BoxDecoration(
                                color: islandBg,
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(color: islandBorder),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) => Stack(
                                  children: [
                                    _SlidingNavIndicator(
                                      currentIndex: currentIndex,
                                      barWidth: constraints.maxWidth,
                                      color: cs.primary,
                                    ),
                                    Row(
                                      children: [
                                        // 0 — Accueil
                                        Expanded(
                                          child: DonyNavItem(
                                            iconAsset: 'search',
                                            label: 'Rechercher',
                                            index: 0,
                                            currentIndex: currentIndex,
                                            onTap: () => onTap(0),
                                          ),
                                        ),
                                        // 1 — Activités
                                        Expanded(
                                          child: DonyNavItem(
                                            iconAsset: tab1IconAsset,
                                            label: tab1Label,
                                            index: 1,
                                            currentIndex: currentIndex,
                                            onTap: () => onTap(1),
                                          ),
                                        ),
                                        // 2 — Suivi : remplacé par l'orb central (overlay)
                                        const Expanded(
                                          child: SizedBox.shrink(),
                                        ),
                                        // 3 — Messages
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final uid = FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid;
                                              if (uid == null || uid.isEmpty) {
                                                // Pendant le sign-out : pas de stream
                                                // Firestore (path vide invalide).
                                                return DonyNavItem(
                                                  iconAsset: 'message-circle',
                                                  label: 'Messages',
                                                  index: 3,
                                                  currentIndex: currentIndex,
                                                  onTap: () => onTap(3),
                                                );
                                              }
                                              return StreamBuilder<int>(
                                                stream:
                                                    getIt<
                                                          FirestoreChatRepository
                                                        >()
                                                        .totalUnreadStream(uid),
                                                builder: (context, snapshot) {
                                                  return DonyNavItem(
                                                    iconAsset: 'message-circle',
                                                    label: 'Messages',
                                                    index: 3,
                                                    currentIndex: currentIndex,
                                                    onTap: () => onTap(3),
                                                    badgeCount:
                                                        snapshot.data ?? 0,
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        // 4 — Moi (photo de profil style Facebook)
                                        Expanded(
                                          child: DonyNavItem(
                                            iconAsset: 'user',
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Orb central (onglet Suivi / scan QR) en relief
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 22,
                      child: Center(
                        child: DonyNavOrb(
                          active: currentIndex == 2,
                          onTap: () => onTap(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Pastille bleue partagée, glissante, peinte derrière la [Row] d'items de
/// [_DonyBottomNav] — remplace le fondu indépendant par item pour une
/// transition de focus continue d'un onglet à l'autre (audit UX bottom nav).
/// Masquée sur les slots 2 (orb) et 4 (avatar) : ces deux-là ont déjà leur
/// propre traitement d'état actif (halo / anneau) qui ne se marie pas avec
/// une pilule pleine.
class _SlidingNavIndicator extends StatelessWidget {
  const _SlidingNavIndicator({
    required this.currentIndex,
    required this.barWidth,
    required this.color,
  });

  final int currentIndex;
  final double barWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final itemWidth = barWidth / 5;
    final left =
        itemWidth * currentIndex + (itemWidth - DonyNavItem.pillWidth) / 2;
    final visible = currentIndex != 2 && currentIndex != 4;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      left: left,
      top: DonyNavItem.pillTopInset,
      width: DonyNavItem.pillWidth,
      height: DonyNavItem.pillHeight,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: visible ? 1 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
