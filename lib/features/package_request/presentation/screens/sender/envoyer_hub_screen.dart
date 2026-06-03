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
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({super.key});

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
              getIt<BidBloc>()..add(const BidMyListAutoRefreshRequested()),
        ),
        BlocProvider.value(value: getIt<NegotiationListBloc>()),
      ],
      child: const _EnvoyerTabsView(),
    );
  }
}

// ── Tabbed view ───────────────────────────────────────────────────────────────

class _EnvoyerTabsView extends StatefulWidget {
  const _EnvoyerTabsView();

  @override
  State<_EnvoyerTabsView> createState() => _EnvoyerTabsViewState();
}

class _EnvoyerTabsViewState extends State<_EnvoyerTabsView>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  static const _screens = [
    AnalyticsEvents.envoyerEnvoisScreen,
    AnalyticsEvents.envoyerDemandesScreen,
    AnalyticsEvents.envoyerNegosScreen,
  ];

  // Derniers comptes de badge vus par onglet.
  // Le badge ne s'affiche que si le compte courant > dernière valeur vue.
  // Initialisé à -1 pour que la première visite marque tout comme vu.
  final _lastSeen = [-1, -1, -1];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this)
      ..addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(getIt<AnalyticsService>().logScreen(_screens.first));
      // Marque l'onglet 0 comme vu dès l'ouverture.
      _markSeen(0);
    });
  }

  void _markSeen(int index) {
    // Récupère le compte badge courant depuis les blocs et le mémorise.
    final badge = _currentBadge(index);
    if (_lastSeen[index] != badge) {
      setState(() => _lastSeen[index] = badge);
    }
  }

  int _currentBadge(int index) {
    switch (index) {
      case 0:
        final s = context.read<BidBloc>().state;
        return s is BidListLoaded
            ? s.bids.where((b) => b.status == 'AWAITING_PAYMENT').length
            : 0;
      case 1:
        return context
            .read<PackageRequestBloc>()
            .state
            .requests
            .where((r) => r.status == PackageRequestStatus.negotiating)
            .length;
      case 2:
        return context.read<NegotiationListBloc>().state.activeCount;
      default:
        return 0;
    }
  }

  /// Retourne le nombre de nouveaux éléments à afficher sur le badge de l'onglet [index].
  /// Vaut 0 si l'onglet est actif ou si rien de nouveau depuis la dernière visite.
  int badgeFor(int index, int currentCount) {
    if (_controller.index == index) {
      return 0;
    }
    final last = _lastSeen[index];
    if (last < 0) {
      return 0; // premier chargement, pas encore de données
    }
    return currentCount > last ? currentCount - last : 0;
  }

  void _onTab() {
    if (_controller.indexIsChanging) {
      return;
    }
    final index = _controller.index;
    unawaited(getIt<AnalyticsService>().logScreen(_screens[index]));
    // Refresh le bloc de l'onglet qui devient visible.
    switch (index) {
      case 0:
        context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
      case 1:
        context.read<PackageRequestBloc>().add(const RefreshMyRequests());
      case 2:
        context
            .read<NegotiationListBloc>()
            .add(const NegotiationListRefreshRequested());
    }
    // Marque l'onglet comme vu après le refresh (post-frame pour lire
    // l'état mis à jour).
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F6),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _EnvoyerHeader(onNew: _onNew),
            _EnvoyerSegmented(
              controller: _controller,
              badgeForIndex: badgeFor,
            ),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: const [
                  ShipmentListBody(),
                  MyPackageRequestsBody(),
                  MyNegotiationsBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _EnvoyerHeader extends StatelessWidget {
  const _EnvoyerHeader({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            'Envoyer',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onNew,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: DonyColors.primary,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: DonyColors.primary.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    'Nouveau',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segmented control ─────────────────────────────────────────────────────────

class _EnvoyerSegmented extends StatelessWidget {
  const _EnvoyerSegmented({
    required this.controller,
    required this.badgeForIndex,
  });

  final TabController controller;

  /// Retourne le nombre de nouveaux éléments à afficher pour l'onglet [index].
  final int Function(int index, int currentCount) badgeForIndex;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, reqState) =>
          BlocBuilder<NegotiationListBloc, NegotiationListState>(
        builder: (context, negoState) =>
            BlocBuilder<BidBloc, BidState>(
          builder: (context, bidState) {
            // Counts globaux affichés dans le libellé du segment.
            final envoisTotal = bidState is BidListLoaded
                ? bidState.bids
                    .where(
                      (b) =>
                          b.status == 'ACCEPTED' ||
                          b.status == 'PENDING' ||
                          b.status == 'AWAITING_PAYMENT',
                    )
                    .length
                : 0;

            final demandesTotal = reqState.requests
                .where(
                  (r) =>
                      r.status == PackageRequestStatus.open ||
                      r.status == PackageRequestStatus.negotiating ||
                      r.status == PackageRequestStatus.accepted,
                )
                .length;

            final negosTotal = negoState.activeCount;

            // Comptes bruts pour le badge (action immédiate demandée).
            final envoisRaw = bidState is BidListLoaded
                ? bidState.bids
                    .where((b) => b.status == 'AWAITING_PAYMENT')
                    .length
                : 0;
            final demandesRaw = reqState.requests
                .where((r) => r.status == PackageRequestStatus.negotiating)
                .length;
            final negosRaw = negoState.activeCount;

            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  0,
                  DonySpacing.lg,
                  DonySpacing.sm,
                ),
                child: Row(
                  children: [
                    _Seg(
                      label: 'Envois',
                      count: envoisTotal,
                      badge: badgeForIndex(0, envoisRaw),
                      active: controller.index == 0,
                      onTap: () => controller.animateTo(0),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    _Seg(
                      label: 'Demandes',
                      count: demandesTotal,
                      badge: badgeForIndex(1, demandesRaw),
                      active: controller.index == 1,
                      onTap: () => controller.animateTo(1),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    _Seg(
                      label: 'Négos',
                      count: negosTotal,
                      badge: badgeForIndex(2, negosRaw),
                      active: controller.index == 2,
                      onTap: () => controller.animateTo(2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.count,
    required this.badge,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;

  /// Nombre d'éléments demandant une action immédiate (badge rouge).
  /// Masqué quand l'onglet est actif (l'utilisateur est déjà là).
  final int badge;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // badge est déjà 0 quand l'onglet est actif (calculé par badgeFor dans le parent).
    final showBadge = badge > 0;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              decoration: BoxDecoration(
                color: active ? DonyColors.primary : cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: active ? DonyColors.primary : cs.outlineVariant,
                ),
              ),
              child: Center(
                child: Text(
                  count > 0 ? '$label $count' : label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (showBadge)
              Positioned(
                top: -6,
                right: -4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(badge),
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DonyColors.danger500,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                      border: Border.all(
                        color: const Color(0xFFF0F2F6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
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
      ),
    );
  }
}
