import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({
    super.key,
    this.onShowTrips,
    this.showBackButton = false,
  });

  /// Si non nul, un bouton « Mes trajets » apparaît dans le header du hub,
  /// permettant au voyageur occasionnel d'accéder à ses trajets depuis la vue
  /// expéditeur (modèle additif Phase 1).
  final VoidCallback? onShowTrips;

  /// Affiche un bouton retour dans le header quand l'écran est ouvert via
  /// `context.push` (depuis Mes trajets), et non comme racine d'onglet.
  final bool showBackButton;

  @override
  State<EnvoyerHubScreen> createState() => _EnvoyerHubScreenState();
}

class _EnvoyerHubScreenState extends State<EnvoyerHubScreen> {
  @override
  void initState() {
    super.initState();
    getIt<PackageRequestBloc>().add(const FetchMyRequests());
    getIt<NegotiationListBloc>().add(const NegotiationListFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<PackageRequestBloc>()),
        BlocProvider(
          create: (_) =>
              getIt<BidBloc>()..add(const BidMyListAutoRefreshRequested(force: true)),
        ),
        BlocProvider.value(value: getIt<NegotiationListBloc>()),
      ],
      child: _EnvoyerTabsView(
        onShowTrips: widget.onShowTrips,
        showBackButton: widget.showBackButton,
      ),
    );
  }
}

// ── Tabbed view ───────────────────────────────────────────────────────────────

class _EnvoyerTabsView extends StatefulWidget {
  const _EnvoyerTabsView({this.onShowTrips, this.showBackButton = false});

  final VoidCallback? onShowTrips;
  final bool showBackButton;

  @override
  State<_EnvoyerTabsView> createState() => _EnvoyerTabsViewState();
}

class _EnvoyerTabsViewState extends State<_EnvoyerTabsView>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  static const _screens = [
    AnalyticsEvents.envoyerEnvoisScreen,
    AnalyticsEvents.envoyerDemandesScreen,
  ];

  // Dernier compte de badge vu pour l'onglet Envois (index 0).
  // L'onglet Demandes (index 1) suit plutôt les négos via _lastSeenNego* ci-dessous.
  // Initialisé à -1 : la première visite marque tout comme vu sans afficher de badge.
  final _lastSeen = [-1, -1];

  // Pour les Négos on suit à la fois le nombre de threads et la somme des
  // roundsCount afin de détecter aussi les nouvelles contre-propositions.
  int _lastSeenNegoThreads = -1;
  int _lastSeenNegoRounds = -1;

  // Snapshot du dernier état connu des négos (pour détecter les changements
  // et afficher les notifications in-app).
  NegotiationListState? _prevNegoState;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this)
      ..addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(getIt<AnalyticsService>().logScreen(_screens.first));
      _markSeen(0);
    });
  }

  void _markSeen(int index) {
    if (index == 1) {
      // Onglet Demandes : les offres/contre-propositions reçues y sont
      // désormais surfacées (badge + détail de chaque demande), on les marque
      // donc comme vues à l'ouverture de l'onglet.
      final s = context.read<NegotiationListBloc>().state;
      final threads = s.threads;
      final rounds = threads.fold(0, (sum, t) => sum + t.roundsCount);
      if (_lastSeenNegoThreads != threads.length ||
          _lastSeenNegoRounds != rounds) {
        setState(() {
          _lastSeenNegoThreads = threads.length;
          _lastSeenNegoRounds = rounds;
        });
      }
    } else {
      final badge = _currentBadge(index);
      if (_lastSeen[index] != badge) {
        setState(() => _lastSeen[index] = badge);
      }
    }
  }

  int _currentBadge(int index) {
    switch (index) {
      case 0:
        final s = context.read<BidBloc>().state;
        return s is BidListLoaded
            ? s.bids.where((b) => b.status == 'AWAITING_PAYMENT').length
            : 0;
      default:
        return 0;
    }
  }

  /// Badge Demandes = nouvelles offres + nouvelles contre-propositions depuis
  /// la dernière visite de l'onglet Demandes.
  int get _negoBadge {
    if (_controller.index == 1) {
      return 0;
    }
    if (_lastSeenNegoThreads < 0) {
      return 0;
    }
    final s = context.read<NegotiationListBloc>().state;
    final threads = s.threads;
    final rounds = threads.fold(0, (sum, t) => sum + t.roundsCount);
    final newThreads = (threads.length - _lastSeenNegoThreads).clamp(0, 999);
    final newRounds = (rounds - _lastSeenNegoRounds).clamp(0, 999);
    return newThreads + newRounds;
  }

  /// Badge pour onglets 0 et 1.
  int badgeFor(int index, int currentCount) {
    if (_controller.index == index) {
      return 0;
    }
    final last = _lastSeen[index];
    if (last < 0) {
      return 0;
    }
    return (currentCount - last).clamp(0, 999);
  }

  // ── Notifications in-app négociations ────────────────────────────────────────

  void _onNegoStateChanged(
    BuildContext context,
    NegotiationListState next,
  ) {
    final prev = _prevNegoState;
    _prevNegoState = next;

    // Pas de notification au premier chargement (prev == null). Ne pas tester
    // prev.threads.isEmpty : cela supprimait la notification de la toute
    // première offre reçue (transition liste vide → 1 thread).
    if (prev == null) {
      return;
    }
    // On est sur l'onglet Demandes : l'utilisateur voit déjà les changements.
    if (_controller.index == 1) {
      return;
    }

    final prevById = {for (final t in prev.threads) t.id: t};

    for (final t in next.threads) {
      final p = prevById[t.id];

      if (p == null) {
        // Nouvelle négociation (nouveau thread).
        final name = t.travelerName ?? 'Un voyageur';
        _showNegoNotification(
          context,
          message: '$name t\'a fait une offre à ${PriceDisplay.eur(t.grossPriceEur ?? PriceDisplay.grossFromNet(t.currentPriceEur))}',
          type: DonySnackbarType.info,
        );
        continue;
      }

      // Contre-proposition : roundsCount a augmenté.
      if (t.roundsCount > p.roundsCount &&
          t.status == NegotiationThreadStatus.open) {
        final name = t.travelerName ?? 'Un voyageur';
        _showNegoNotification(
          context,
          message: '$name a fait une contre-proposition : ${PriceDisplay.eur(t.grossPriceEur ?? PriceDisplay.grossFromNet(t.currentPriceEur))}',
          type: DonySnackbarType.warning,
        );
        continue;
      }

      // Proposition acceptée.
      if (p.status != NegotiationThreadStatus.accepted &&
          t.status == NegotiationThreadStatus.accepted) {
        final name = t.travelerName ?? 'Le voyageur';
        _showNegoNotification(
          context,
          message: '$name a accepté ta proposition ! 🎉',
          type: DonySnackbarType.success,
        );
      }
    }
  }

  void _showNegoNotification(
    BuildContext context, {
    required String message,
    required DonySnackbarType type,
  }) {
    if (!mounted) {
      return;
    }
    DonySnackbar.show(context, message: message, type: type);
  }

  // ─────────────────────────────────────────────────────────────────────────────

  static const _staleDuration = Duration(seconds: 60);

  bool _isStale(DateTime fetchedAt) =>
      DateTime.now().difference(fetchedAt) > _staleDuration;

  void _onTab() {
    if (_controller.indexIsChanging) {
      return;
    }
    final index = _controller.index;
    unawaited(getIt<AnalyticsService>().logScreen(_screens[index]));
    // Refresh forcé (silencieux) si les données ont > 60 s : reflète un statut
    // changé hors de l'app (ex. trajet annulé par le voyageur) que le TTL
    // d'auto-refresh du bloc masquerait sinon jusqu'à 3 min.
    switch (index) {
      case 0:
        final bidState = context.read<BidBloc>().state;
        final bidFetchedAt =
            bidState is BidListLoaded ? bidState.fetchedAt : DateTime(2000);
        if (_isStale(bidFetchedAt)) {
          context
              .read<BidBloc>()
              .add(const BidMyListAutoRefreshRequested(force: true));
        }
      case 1:
        // Onglet Demandes : rafraîchir les demandes ET les négos (les offres
        // reçues sont surfacées ici via le badge et le détail).
        if (_isStale(context.read<PackageRequestBloc>().state.fetchedAt)) {
          context.read<PackageRequestBloc>().add(const RefreshMyRequests());
        }
        if (_isStale(context.read<NegotiationListBloc>().state.fetchedAt)) {
          context
              .read<NegotiationListBloc>()
              .add(const NegotiationListRefreshRequested());
        }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _markSeen(index);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTab);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onNew() async {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated
        ? authState.user
        : authState is AuthProfileUpdated
            ? authState.user
            : null;

    if (user == null || !user.isKycVerified) {
      await KycRequiredBottomSheet.show(
        context,
        kycStatus: user?.kycStatus ?? 'NOT_STARTED',
      );
      return;
    }

    await PackageRequestCreateWizard.show(context);
    if (mounted) {
      context.read<PackageRequestBloc>().add(const RefreshMyRequests());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NegotiationListBloc, NegotiationListState>(
          listenWhen: (prev, next) =>
              next.status == NegotiationListStatus.loaded && prev != next,
          listener: (ctx, next) {
            _onNegoStateChanged(ctx, next);
            if (_controller.index == 1 && mounted) {
              _markSeen(1);
            }
          },
        ),
        BlocListener<PackageRequestBloc, PackageRequestState>(
          listenWhen: (_, next) =>
              next.status == PackageRequestListStatus.loaded,
          listener: (_, _) {
            if (_controller.index == 1 && mounted) {
              _markSeen(1);
            }
          },
        ),
        BlocListener<BidBloc, BidState>(
          listenWhen: (_, next) => next is BidListLoaded,
          listener: (_, _) {
            if (_controller.index == 0 && mounted) {
              _markSeen(0);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F6),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _EnvoyerHeader(
                onNew: _onNew,
                onShowTrips: widget.onShowTrips,
                showBackButton: widget.showBackButton,
              ),
              _EnvoyerSegmented(
                controller: _controller,
                badgeForIndex: badgeFor,
                negoBadge: _negoBadge,
              ),
              Expanded(
                child: TabBarView(
                  controller: _controller,
                  children: [
                    ShipmentListBody(
                      onSwitchToDemandes: () => _controller.animateTo(1),
                    ),
                    const MyPackageRequestsBody(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _EnvoyerHeader extends StatelessWidget {
  const _EnvoyerHeader({
    required this.onNew,
    this.onShowTrips,
    this.showBackButton = false,
  });

  final VoidCallback onNew;

  /// Si non nul, affiche la pill « Mes trajets » pour les voyageurs
  /// occasionnels (modèle additif Phase 1).
  final VoidCallback? onShowTrips;

  /// Affiche un bouton retour quand le hub est ouvert via `context.push`.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: Row(
        children: [
          if (showBackButton)
            const DonyAppBarBackButton(
              key: Key('envoyer-back'),
            ),
          Text(
            'Envoyer',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: cs.onSurface,
                  height: 1.1,
                ),
          ),
          const Spacer(),
          if (onShowTrips != null) ...[
            HeaderPill(
              key: const Key('show-trips-pill'),
              label: 'Mes trajets',
              iconAsset: 'plane-takeoff',
              style: HeaderPillStyle.soft,
              onTap: onShowTrips!,
            ),
            const SizedBox(width: DonySpacing.xs),
          ],
          HeaderPill(
            label: '+ Nouveau',
            onTap: onNew,
          ),
        ],
      ),
    );
  }
}

// ── Segmented control (sliding capsule) ──────────────────────────────────────

class _EnvoyerSegmented extends StatelessWidget {
  const _EnvoyerSegmented({
    required this.controller,
    required this.badgeForIndex,
    required this.negoBadge,
  });

  final TabController controller;

  /// Badge pour l'onglet Envois (index 0).
  final int Function(int index, int currentCount) badgeForIndex;

  /// Badge précalculé pour l'onglet Demandes — nouvelles offres + contre-propositions reçues.
  final int negoBadge;

  @override
  Widget build(BuildContext context) {
    // BlocBuilder NegotiationList : reconstruit la barre quand les négos
    // changent (le badge Demandes en dépend, calculé par le parent).
    return BlocBuilder<NegotiationListBloc, NegotiationListState>(
      builder: (context, _) => BlocBuilder<BidBloc, BidState>(
        builder: (context, bidState) {
          // Compte brut pour le badge Envois (action immédiate demandée).
          final envoisRaw = bidState is BidListLoaded
              ? bidState.bids
                  .where((b) => b.status == 'AWAITING_PAYMENT')
                  .length
              : 0;

          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                0,
                DonySpacing.lg,
                DonySpacing.sm,
              ),
              child: _SlidingSegmented(
                controller: controller,
                envoisBadge: badgeForIndex(0, envoisRaw),
                negoBadge: negoBadge,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sliding capsule segmented control — two equal tabs with an animated white
/// capsule that slides between Envois (left) and Demandes (right).
class _SlidingSegmented extends StatelessWidget {
  const _SlidingSegmented({
    required this.controller,
    required this.envoisBadge,
    required this.negoBadge,
  });

  final TabController controller;
  final int envoisBadge;
  final int negoBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRight = controller.index == 1;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: DonyColors.neutral100,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final capsuleWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Sliding white capsule
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: isRight
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: capsuleWidth,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md - 2),
                    boxShadow: const [
                      BoxShadow(
                        color: DonyColors.shadow,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels row (on top of capsule)
              Row(
                children: [
                  Expanded(
                    child: _SegLabel(
                      label: 'Envois',
                      badge: envoisBadge,
                      active: !isRight,
                      onTap: () => controller.animateTo(0),
                    ),
                  ),
                  Expanded(
                    child: _SegLabel(
                      label: 'Demandes',
                      badge: negoBadge,
                      active: isRight,
                      onTap: () => controller.animateTo(1),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel({
    required this.label,
    required this.badge,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showBadge = badge > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? cs.onSurface : cs.onSurfaceVariant,
              ),
              child: Text(label),
            ),
          ),
          if (showBadge)
            Positioned(
              top: -2,
              right: 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(badge),
                  constraints: const BoxConstraints(minWidth: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: DonyColors.danger500,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                    border: Border.all(
                      color: DonyColors.neutral100,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
