import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hub principal du parcours **sender** — tab 1 de la bottom nav quand
/// `ActiveRole.sender`.
///
/// Layout (match maquettes v3 `20-43-08` / `20-43-49` / `20-44-05`) :
/// - Header titre "Envoyer" + sous-titre dynamique + action top-right
/// - TabBar 3 onglets : Demandes · Envois · Négos
/// - TabBarView avec les 3 bodies extraits
/// - FAB Publier en bas droite → `PackageRequestCreateWizard.show()`
///
/// Le voyageur (`ActiveRole.traveler`) reste sur `AnnouncementListScreen`
/// inchangé (dispatch fait dans `MatchingManagementScreen`).
class EnvoyerHubScreen extends StatelessWidget {
  const EnvoyerHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<PackageRequestBloc>()..add(const FetchMyRequests()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<BidBloc>()..add(const BidMyListAutoRefreshRequested()),
        ),
        BlocProvider(
          create: (_) => getIt<NegotiationListBloc>()
            ..add(const NegotiationListFetchRequested()),
        ),
      ],
      child: const _EnvoyerHubView(),
    );
  }
}

class _EnvoyerHubView extends StatefulWidget {
  const _EnvoyerHubView();

  @override
  State<_EnvoyerHubView> createState() => _EnvoyerHubViewState();
}

class _EnvoyerHubViewState extends State<_EnvoyerHubView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _EnvoyerHubHeader(),
            _EnvoyerHubTabBar(controller: _tabController),
            const Divider(height: 1, thickness: 1, color: kBorder),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  MyPackageRequestsBody(),
                  ShipmentListBody(),
                  MyNegotiationsBody(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'envoyer-hub-fab',
        backgroundColor: kGreenPrimary,
        foregroundColor: Colors.white,
        onPressed: () => PackageRequestCreateWizard.show(context),
        tooltip: 'Publier une demande',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _EnvoyerHubHeader extends StatelessWidget {
  const _EnvoyerHubHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: BlocBuilder<PackageRequestBloc, PackageRequestState>(
        builder: (context, state) {
          final count = state.requests.length;
          return BlocBuilder<NegotiationListBloc, NegotiationListState>(
            buildWhen: (a, b) => a.activeCount != b.activeCount,
            builder: (context, negoState) {
              final negoCount = negoState.activeCount;
              final subtitle = _buildSubtitle(count, negoCount);
              return _HeaderRow(subtitle: subtitle);
            },
          );
        },
      ),
    );
  }

  static String _buildSubtitle(int demandes, int negos) {
    if (demandes == 0 && negos == 0) return 'Aucune demande en cours';
    final demandesPart = demandes == 1 ? '1 demande active' : '$demandes demandes actives';
    if (negos == 0) return demandesPart;
    final negosPart = negos == 1 ? '1 nouvelle négo' : '$negos nouvelles négos';
    return '$demandesPart · $negosPart';
  }

  static String _pluralizeDemandes(int count) {
    if (count == 1) return '1 demande active';
    return '$count demandes actives';
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Envoyer',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextSecondary,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 220.ms),
        ),
        _HeaderAction(onTap: () => PackageRequestCreateWizard.show(context))
            .animate()
            .fadeIn(delay: 80.ms),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Publier une demande',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: kTextPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── TabBar custom ────────────────────────────────────────────────────────────

class _EnvoyerHubTabBar extends StatelessWidget {
  const _EnvoyerHubTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: TabBar(
        controller: controller,
        indicatorColor: DonyColors.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: kTextPrimary,
        unselectedLabelColor: kTextSecondary,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabAlignment: TabAlignment.start,
        isScrollable: true,
        dividerColor: Colors.transparent,
        tabs: [
          _CountedTab(
            label: 'Demandes',
            counterBuilder: (context) {
              return BlocBuilder<PackageRequestBloc, PackageRequestState>(
                buildWhen: (a, b) => a.requests.length != b.requests.length,
                builder: (_, state) => _Counter(value: state.requests.length),
              );
            },
          ),
          _CountedTab(
            label: 'Envois',
            counterBuilder: (context) {
              return BlocBuilder<BidBloc, BidState>(
                buildWhen: (a, b) =>
                    _envoisActiveCount(a) != _envoisActiveCount(b),
                builder: (_, state) =>
                    _Counter(value: _envoisActiveCount(state)),
              );
            },
          ),
          _CountedTab(
            label: 'Négos',
            counterBuilder: (context) {
              return BlocBuilder<NegotiationListBloc, NegotiationListState>(
                buildWhen: (a, b) => a.activeCount != b.activeCount,
                builder: (_, state) => _Counter(value: state.activeCount),
              );
            },
          ),
        ],
      ),
    );
  }

  static int _envoisActiveCount(BidState state) {
    if (state is BidListLoaded) {
      return state.bids
          .where((b) =>
              b.status == 'ACCEPTED' ||
              b.status == 'PENDING' ||
              b.status == 'AWAITING_PAYMENT')
          .length;
    }
    return 0;
  }
}

class _CountedTab extends StatelessWidget {
  const _CountedTab({required this.label, required this.counterBuilder});
  final String label;
  final WidgetBuilder? counterBuilder;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (counterBuilder != null) ...[
            const SizedBox(width: 6),
            counterBuilder!(context),
          ],
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      return Text(
        '0',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kTextHint,
        ),
      );
    }
    return Text(
      '$value',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: DonyColors.primary,
      ),
    );
  }
}
