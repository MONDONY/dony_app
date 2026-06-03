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

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this)
      ..addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(getIt<AnalyticsService>().logScreen(_screens.first));
    });
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
            _EnvoyerSegmented(controller: _controller),
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
  const _EnvoyerSegmented({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, reqState) =>
          BlocBuilder<NegotiationListBloc, NegotiationListState>(
        builder: (context, negoState) =>
            BlocBuilder<BidBloc, BidState>(
          builder: (context, bidState) {
            final envois = bidState is BidListLoaded
                ? bidState.bids
                    .where(
                      (b) =>
                          b.status == 'ACCEPTED' ||
                          b.status == 'PENDING' ||
                          b.status == 'AWAITING_PAYMENT',
                    )
                    .length
                : 0;

            final demandes = reqState.requests
                .where(
                  (r) =>
                      r.status == PackageRequestStatus.open ||
                      r.status == PackageRequestStatus.negotiating ||
                      r.status == PackageRequestStatus.accepted,
                )
                .length;

            final negos = negoState.activeCount;

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
                      count: envois,
                      active: controller.index == 0,
                      onTap: () => controller.animateTo(0),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    _Seg(
                      label: 'Demandes',
                      count: demandes,
                      active: controller.index == 1,
                      onTap: () => controller.animateTo(1),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    _Seg(
                      label: 'Négos',
                      count: negos,
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
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
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
      ),
    );
  }
}
