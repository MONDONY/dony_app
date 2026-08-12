import 'dart:async';

import 'package:dony/app/widgets/dony_nav_item.dart';
import 'package:dony/app/widgets/dony_nav_orb.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
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

  /// Hauteur du contenu de la barre d'onglets, hors safe area.
  ///
  /// Le shell monte ses écrans avec `extendBody: true` : leur contenu passe
  /// donc *sous* la barre. Un écran scrollable doit réserver
  /// `navBarContentHeight + MediaQuery.paddingOf(context).bottom` en bas,
  /// sinon ses derniers éléments sont masqués par la barre.
  static const double navBarContentHeight = 66;

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  StreamSubscription<void>? _fcmSub;
  bool _ratingPromptShown = false;
  DateTime? _lastHomeRefreshAt;
  DateTime? _lastMessagesRefreshAt;

  // En dessous de ce délai, retaper un onglet ne redéclenche pas son refresh
  // réseau : un va-et-vient rapide entre Accueil/Activités/Messages tirait
  // sans throttle une salve par onglet (BidBloc, EnvoisRefreshNotifier,
  // ConversationListBloc), ce qui épuisait le rate-limit nginx en quelques
  // allers-retours et faisait échouer les chargements en cours partout à la
  // fois. Même principe que le throttle de ActivitesHubScreen._loadAll.
  static const _minTabReloadInterval = Duration(seconds: 3);

  bool _shouldThrottle(DateTime? lastRefreshAt) =>
      lastRefreshAt != null &&
      DateTime.now().difference(lastRefreshAt) < _minTabReloadInterval;

  /// Nom d'écran PostHog par onglet du shell. Les branches du
  /// StatefulShellRoute tournent sur leur propre Navigator que le
  /// PosthogObserver racine ne voit pas : sans ce log manuel, changer d'onglet
  /// n'émettait aucun $screen. On aligne les noms sur les chemins de route.
  static const List<String> _tabScreenNames = [
    '/home',
    '/announcements',
    '/tracking',
    '/messages',
    '/profile',
  ];

  void _logTabScreen(int index) {
    if (index < 0 || index >= _tabScreenNames.length) return;
    unawaited(getIt<AnalyticsService>().logScreen(_tabScreenNames[index]));
  }

  /// Recharge les compteurs qui allument le point d'attention de l'onglet
  /// Activités : demandes reçues (TravelerBidsBloc) + négociations actives
  /// (NegotiationListBloc). Les notifications non lues, troisième source, sont
  /// déjà rechargées à côté.
  void _loadActivityIndicators() {
    if (!mounted) {
      return;
    }
    context.read<TravelerBidsBloc>().add(
      const TravelerBidsRequested(force: true),
    );
    context.read<NegotiationListBloc>().add(
      const NegotiationListFetchRequested(),
    );
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    _logTabScreen(index);
    if (index == 1) {
      getIt<EnvoisRefreshNotifier>().requestRefresh();
    }
    if (index == 0 && !_shouldThrottle(_lastHomeRefreshAt)) {
      // Accueil : la liste des bids de l'expéditeur est mise en cache au premier
      // montage (home reste vivant dans le nav shell). Si un voyageur refuse une
      // demande à distance, le cache reste sur « en attente ». Force un refresh à
      // chaque (ré)sélection de l'onglet pour refléter le vrai statut.
      _lastHomeRefreshAt = DateTime.now();
      context.read<BidBloc>().add(
        const BidMyListAutoRefreshRequested(force: true),
      );
    }
    if (index == 3 && !_shouldThrottle(_lastMessagesRefreshAt)) {
      // Messages : ConversationListScreen ne charge qu'au premier montage
      // (StatefulNavigationShell garde l'écran vivant en IndexedStack) — sans
      // ce refresh, les nouveaux messages/conversations reçus pendant qu'on
      // était sur un autre onglet restent invisibles tant qu'on ne fait pas
      // un pull-to-refresh manuel.
      _lastMessagesRefreshAt = DateTime.now();
      getIt<ConversationListBloc>().add(const ConversationsLoadRequested());
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
      // Alimente le point d'attention de l'onglet Activités dès le démarrage,
      // sans attendre que l'utilisateur ouvre le hub.
      _loadActivityIndicators();
      // Onglet affiché au montage du shell (aucun tap ne l'a déclenché) : on
      // émet son $screen manuellement pour ne pas perdre la 1re vue.
      _logTabScreen(widget.navigationShell.currentIndex);
      _fcmSub = getIt<NotificationService>().newNotificationStream.listen((_) {
        if (mounted) {
          context.read<NotificationBloc>().add(
            const NotificationsLoadRequested(),
          );
          // Une push peut être une nouvelle demande reçue ou une offre de
          // négociation : rafraîchir les compteurs de l'onglet aussi.
          _loadActivityIndicators();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // Le bloc est un singleton DI : il peut être fermé (ex. logout) alors
    // que ce shell est encore mounted — mounted seul ne protège pas contre
    // ce cas, d'où le check isClosed avant le add().
    final stripeBloc = context.read<StripeAccountBloc>();
    if (!stripeBloc.isClosed) {
      stripeBloc.add(const StripeAccountStatusRefreshed());
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
            // Le contenu passe DERRIÈRE la bottom nav (bar ancrée dont le
            // fond s'étend sous le home indicator). Scaffold injecte la
            // hauteur de la nav dans MediaQuery.padding.bottom du body,
            // donc les écrans en SafeArea réservent l'espace.
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

/// Bottom nav « barre ancrée » : barre pleine opaque flush avec le bord de
/// l'écran (pas de marge, pas de glass) — plus lisible qu'une île translucide
/// sur les fonds chargés (carte, listes colorées) derrière. Une pastille
/// pleine glisse sous l'onglet actif ; l'orb glossy (onglet Suivi / scan QR)
/// est au même niveau que les 4 autres items, pas surélevé. Theme-aware :
/// couleurs dérivées du [ColorScheme] / brightness courants.
class _DonyBottomNav extends StatelessWidget {
  const _DonyBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Diamètre de l'orb inline — plus petit que [DonyNavOrb.defaultSize]
  /// pour tenir au même niveau que les icônes des autres items dans
  /// [MainShell.navBarContentHeight].
  static const double _orbInlineSize = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
            // Tab 1 — Activités (hub unique : depuis la Phase 2, le contenu ne
            // dépend plus du profil — cf. ActivitesHubScreen)
            // 'zap' remplacé par 'layout-grid' : l'éclair se lisait
            // « action rapide/boost », pas « mes trajets » — cf. audit UX bottom nav.
            const tab1Label = 'Activités';
            const tab1IconAsset = 'layout-grid';

            return DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : DonyColors.ink800.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                // Le fond coloré s'étend sous le home indicator ; seul le
                // contenu (icônes/libellés) respecte la safe area, comme
                // une tab bar iOS/Android native.
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: SizedBox(
                  height: MainShell.navBarContentHeight,
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
                            // 1 — Activités (point d'attention = demandes reçues
                            // + négociations actives + notifications non lues,
                            // même signal que les pastilles des cartes du hub)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final pendingRequests =
                                      context.select<TravelerBidsBloc, int>(
                                    (b) => b.state is TravelerBidsLoaded
                                        ? (b.state as TravelerBidsLoaded)
                                            .pendingCount
                                        : 0,
                                  );
                                  // Onglet : seulement quand c'est à
                                  // l'utilisateur de répondre (pas quand on
                                  // attend la partie adverse). La carte, elle,
                                  // reste allumée via activeCount.
                                  final activeNegos =
                                      context.select<NegotiationListBloc, int>(
                                    (b) => b.state.actionableCount,
                                  );
                                  final unreadNotifs =
                                      context.select<NotificationBloc, int>(
                                    (b) => b.state is NotificationLoaded
                                        ? (b.state as NotificationLoaded)
                                            .unreadCount
                                        : 0,
                                  );
                                  final hasNew = pendingRequests > 0 ||
                                      activeNegos > 0 ||
                                      unreadNotifs > 0;
                                  return DonyNavItem(
                                    iconAsset: tab1IconAsset,
                                    label: tab1Label,
                                    index: 1,
                                    currentIndex: currentIndex,
                                    onTap: () => onTap(1),
                                    showDot: hasNew,
                                  );
                                },
                              ),
                            ),
                            // 2 — Suivi / scan QR : orb au même niveau que
                            // les autres items, pas surélevé.
                            Expanded(
                              child: Center(
                                child: DonyNavOrb(
                                  size: _orbInlineSize,
                                  active: currentIndex == 2,
                                  onTap: () => onTap(2),
                                ),
                              ),
                            ),
                            // 3 — Messages
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
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
                                    stream: getIt<FirestoreChatRepository>()
                                        .totalUnreadStream(uid),
                                    builder: (context, snapshot) {
                                      return DonyNavItem(
                                        iconAsset: 'message-circle',
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
