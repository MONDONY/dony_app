import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ShipmentListScreen extends StatefulWidget {
  const ShipmentListScreen({super.key});

  @override
  State<ShipmentListScreen> createState() => _ShipmentListScreenState();
}

class _ShipmentListScreenState extends State<ShipmentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final EnvoisRefreshNotifier _refreshNotifier;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
    // Chargement initial via auto-refresh (TTL check, pas de double appel si déjà chargé)
    context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
  }

  void _onTabRefreshRequested() {
    if (mounted) {
      context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
    }
  }

  @override
  void dispose() {
    _refreshNotifier.removeListener(_onTabRefreshRequested);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      floatingActionButton: Builder(
        builder: (context) {
          final authState = context.watch<AuthBloc>().state;
          if (authState is AuthAuthenticated && authState.user.isTraveler) {
            return _SendFab();
          }
          return const SizedBox.shrink();
        },
      ),
      body: BlocBuilder<BidBloc, BidState>(
        builder: (context, state) {
          if (state is BidLoading || state is BidInitial) {
            return const _LoadingView();
          }
          if (state is BidError) {
            return _ErrorView(message: state.message);
          }
          if (state is BidListLoaded) {
            final bids = state.bids;
            final inProgress =
                bids.where((b) => b.status == 'ACCEPTED').toList();
            final upcoming =
                bids.where((b) => b.status == 'PENDING').toList();
            final past = bids
                .where((b) =>
                    b.status == 'COMPLETED' ||
                    b.status == 'REJECTED' ||
                    b.status == 'CANCELLED')
                .toList();

            return Stack(
              children: [
                RefreshIndicator(
                  color: DonyColors.blue400,
                  onRefresh: () async => context
                      .read<BidBloc>()
                      .add(const BidMyListAutoRefreshRequested(force: true)),
                  child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: _EnvoisHeader(
                      inProgressCount: inProgress.length,
                      upcomingCount: upcoming.length,
                      activeShipment:
                          inProgress.isNotEmpty ? inProgress.first : null,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      _SegmentedTabs(controller: _tabController),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _ShipmentListView(
                      key: const PageStorageKey('tab_inprogress'),
                      bids: inProgress,
                      emptyMessage: 'Aucun envoi en cours',
                      emptySubtitle:
                          'Vos colis acceptés par un voyageur apparaîtront ici.',
                      emptyIcon: Icons.local_shipping_outlined,
                    ),
                    _ShipmentListView(
                      key: const PageStorageKey('tab_upcoming'),
                      bids: upcoming,
                      emptyMessage: 'Aucune demande en attente',
                      emptySubtitle:
                          'Trouvez un voyageur et faites votre premier envoi.',
                      emptyIcon: Icons.hourglass_empty_rounded,
                    ),
                    _ShipmentListView(
                      key: const PageStorageKey('tab_past'),
                      bids: past,
                      emptyMessage: 'Aucun historique',
                      emptySubtitle:
                          'Vos livraisons terminées apparaîtront ici.',
                      emptyIcon: Icons.history_rounded,
                    ),
                  ],
                ),
              ),
                ),
                if (state.isRefreshing)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: DonyColors.blue400,
                    minHeight: 2,
                  ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _EnvoisHeader extends StatefulWidget {
  final int inProgressCount;
  final int upcomingCount;
  final BidModel? activeShipment;

  const _EnvoisHeader({
    required this.inProgressCount,
    required this.upcomingCount,
    this.activeShipment,
  });

  @override
  State<_EnvoisHeader> createState() => _EnvoisHeaderState();
}

class _EnvoisHeaderState extends State<_EnvoisHeader> {
  final _savedService = getIt<SavedTripsService>();

  void _openSavedTrips() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedTripsSheet(
        savedService: _savedService,
        onChanged: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedCount = _savedService.getSavedTrips().length;
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: DonyColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Mes envois',
                    style: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: DonyColors.dark900,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                ),
                // Icône trajets sauvegardés
                GestureDetector(
                  onTap: _openSavedTrips,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: savedCount > 0 ? DonyColors.blue100 : DonyColors.grey50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DonyColors.grey100),
                        ),
                        child: Icon(
                          savedCount > 0
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: savedCount > 0 ? DonyColors.blue400 : DonyColors.grey400,
                          size: 20,
                        ),
                      ),
                      if (savedCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: DonyColors.blue400,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$savedCount',
                                style: GoogleFonts.sora(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(delay: 60.ms),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                _StatChip(
                  count: widget.inProgressCount,
                  label: 'en cours',
                  color: DonyColors.success,
                  bgColor: const Color(0xFFECFDF3),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  count: widget.upcomingCount,
                  label: 'en attente',
                  color: DonyColors.warning,
                  bgColor: const Color(0xFFFFF8E7),
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),
          ),
          if (widget.activeShipment != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _ActiveShipmentBanner(bid: widget.activeShipment!),
            )
                .animate()
                .fadeIn(delay: 120.ms)
                .slideY(begin: 0.05, curve: Curves.easeOutCubic),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bgColor;

  const _StatChip({
    required this.count,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveShipmentBanner extends StatelessWidget {
  final BidModel bid;

  const _ActiveShipmentBanner({required this.bid});

  double get _progress => bid.voyageurConfirmed ? 0.72 : 0.35;
  String get _progressLabel =>
      bid.voyageurConfirmed ? 'En transit' : 'Remise à effectuer';

  @override
  Widget build(BuildContext context) {
    final shortDesc = bid.description.length > 36
        ? '${bid.description.substring(0, 36)}…'
        : bid.description;

    return GestureDetector(
      onTap: () async {
        await context.push('/bids/${bid.id}', extra: bid);
        if (context.mounted) {
          context.read<BidBloc>().add(BidMyListRequested());
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DonyColors.blue600, DonyColors.blue400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: DonyColors.blue400.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'COLIS EN TRANSIT',
                    style: GoogleFonts.sora(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              shortDesc,
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.flight_takeoff_rounded,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 6),
                Text(
                  '${bid.departureCity ?? '—'} → ${bid.arrivalCity ?? '—'}',
                  style: GoogleFonts.sora(
                      fontSize: 13, color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  '${bid.weightKg} kg',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _progressLabel,
              style: GoogleFonts.sora(
                  fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segmented tab bar ────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  const _SegmentedTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DonyColors.grey50,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DonyColors.grey100),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DonyColors.blue600, DonyColors.blue400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.zero,
          padding: const EdgeInsets.all(3),
          labelColor: Colors.white,
          unselectedLabelColor: DonyColors.grey400,
          labelStyle: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'En cours'),
            Tab(text: 'À venir'),
            Tab(text: 'Passés'),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _TabBarDelegate(this.child);

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ── List view ────────────────────────────────────────────────────────────────

class _ShipmentListView extends StatelessWidget {
  final List<BidModel> bids;
  final String emptyMessage;
  final String emptySubtitle;
  final IconData emptyIcon;

  const _ShipmentListView({
    super.key,
    required this.bids,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return _EmptyView(
        icon: emptyIcon,
        title: emptyMessage,
        subtitle: emptySubtitle,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: bids.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ShipmentCard(bid: bids[i], index: i),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _ShipmentCard extends StatelessWidget {
  final BidModel bid;
  final int index;

  const _ShipmentCard({required this.bid, required this.index});

  (String, Color) get _statusInfo => switch (bid.status) {
        'PENDING' => ('En attente', DonyColors.warning),
        'ACCEPTED' => ('Accepté', DonyColors.success),
        'REJECTED' => ('Refusé', DonyColors.error),
        'CANCELLED' => ('Annulé', DonyColors.grey200),
        'COMPLETED' => ('Livré', DonyColors.blue400),
        _ => (bid.status, DonyColors.grey400),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusInfo;

    return GestureDetector(
      onTap: () async {
        await context.push('/bids/${bid.id}', extra: bid);
        if (context.mounted) {
          context.read<BidBloc>().add(BidMyListRequested());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DonyColors.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusBadge(label: label, color: color),
                          const Spacer(),
                          Text(
                            '#${bid.id.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.sora(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: DonyColors.grey200,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bid.description.length > 52
                            ? '${bid.description.substring(0, 52)}…'
                            : bid.description,
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DonyColors.dark900,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _RouteRow(
                        departure: bid.departureCity ?? '—',
                        arrival: bid.arrivalCity ?? '—',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.scale_outlined,
                            label: '${bid.weightKg} kg',
                          ),
                          if (bid.contentCategory != null) ...[
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.category_outlined,
                              label: bid.contentCategory!,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: DonyColors.grey400),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('dd MMM yyyy', 'fr')
                                .format(bid.createdAt),
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              color: DonyColors.grey400,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: DonyColors.blue100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Voir',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: DonyColors.blue400,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 12, color: DonyColors.blue400),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: 50 * index))
          .slideY(begin: 0.05, curve: Curves.easeOutCubic),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.sora(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String departure;
  final String arrival;

  const _RouteRow({required this.departure, required this.arrival});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: DonyColors.blue400,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            departure,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DonyColors.dark900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(height: 1, color: DonyColors.grey100),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.flight_takeoff_rounded,
              size: 14, color: DonyColors.blue400),
        ),
        Expanded(
          child: Container(height: 1, color: DonyColors.grey100),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            arrival,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DonyColors.dark900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: DonyColors.blue400, width: 2),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DonyColors.grey50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: DonyColors.grey400),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: DonyColors.grey400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Loading / Error ──────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: DonyColors.blue100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: DonyColors.blue400),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DonyColors.dark900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.sora(
                fontSize: 13,
                color: DonyColors.grey400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DonyColors.blue600, DonyColors.blue400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: DonyColors.blue400.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Rechercher un trajet',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:
          CircularProgressIndicator(color: DonyColors.blue400, strokeWidth: 2.5),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDED),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 32, color: DonyColors.error),
            ),
            const SizedBox(height: 20),
            Text(
              'Erreur de chargement',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DonyColors.dark900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.sora(
                fontSize: 14,
                color: DonyColors.grey400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.read<BidBloc>().add(BidMyListRequested()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: DonyColors.blue100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Réessayer',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.blue400,
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

// ── FAB ──────────────────────────────────────────────────────────────────────

class _SendFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DonyColors.blue600, DonyColors.blue400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: DonyColors.blue400.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Envoyer un colis',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet trajets sauvegardés ─────────────────────────────────────────

class _SavedTripsSheet extends StatefulWidget {
  final SavedTripsService savedService;
  final VoidCallback onChanged;

  const _SavedTripsSheet({
    required this.savedService,
    required this.onChanged,
  });

  @override
  State<_SavedTripsSheet> createState() => _SavedTripsSheetState();
}

class _SavedTripsSheetState extends State<_SavedTripsSheet> {
  late List<AnnouncementModel> _trips;

  @override
  void initState() {
    super.initState();
    _trips = widget.savedService.getSavedTrips();
  }

  Future<void> _remove(String id) async {
    await widget.savedService.removeTrip(id);
    setState(() => _trips = widget.savedService.getSavedTrips());
    widget.onChanged();
  }

  String _initials(AnnouncementModel a) {
    final name = a.traveler?.displayName;
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.grey100,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Titre
          Row(
            children: [
              const Icon(Icons.bookmark_rounded, color: DonyColors.blue400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Trajets sauvegardés',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DonyColors.dark900,
                ),
              ),
              const Spacer(),
              if (_trips.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DonyColors.blue100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_trips.length}',
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.blue400,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_trips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.bookmark_border_rounded,
                        size: 48, color: DonyColors.grey200),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun trajet sauvegardé',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DonyColors.grey400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Appuie sur 🔖 dans le profil d\'un voyageur pour sauvegarder.',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: DonyColors.grey200,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = _trips[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: DonyColors.grey50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: DonyColors.grey100),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [DonyColors.blue600, DonyColors.blue300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials(a),
                            style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        '${a.departureCity} → ${a.arrivalCity}',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DonyColors.dark900,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('d MMM yyyy', 'fr').format(a.departureDate)} · '
                        '${a.availableKg.toStringAsFixed(0)} kg · '
                        '${a.pricePerKg.toStringAsFixed(0)} €/kg',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          color: DonyColors.grey400,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Bouton voir
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/search/${a.id}', extra: a);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: DonyColors.blue400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Voir',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Bouton supprimer
                          IconButton(
                            icon: const Icon(Icons.bookmark_remove_rounded,
                                color: DonyColors.grey200, size: 20),
                            onPressed: () => _remove(a.id),
                            tooltip: 'Retirer',
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 40 * i));
                },
              ),
            ),
        ],
      ),
    );
  }
}