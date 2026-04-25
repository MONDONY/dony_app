import 'package:dony/app/theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<BidBloc>().add(BidMyListRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
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

            return RefreshIndicator(
              color: kGreenPrimary,
              onRefresh: () async =>
                  context.read<BidBloc>().add(BidMyListRequested()),
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
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _EnvoisHeader extends StatelessWidget {
  final int inProgressCount;
  final int upcomingCount;
  final BidModel? activeShipment;

  const _EnvoisHeader({
    required this.inProgressCount,
    required this.upcomingCount,
    this.activeShipment,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Mes envois',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                _StatChip(
                  count: inProgressCount,
                  label: 'en cours',
                  color: kSuccess,
                  bgColor: const Color(0xFFECFDF3),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  count: upcomingCount,
                  label: 'en attente',
                  color: kWarning,
                  bgColor: const Color(0xFFFFF8E7),
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),
          ),
          if (activeShipment != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _ActiveShipmentBanner(bid: activeShipment!),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
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
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kGreenPrimary.withValues(alpha: 0.28),
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
                    style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  '${bid.weightKg} kg',
                  style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
      color: kBackground,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
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
          unselectedLabelColor: kTextSecondary,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
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
        'PENDING' => ('En attente', kWarning),
        'ACCEPTED' => ('Accepté', kSuccess),
        'REJECTED' => ('Refusé', kError),
        'CANCELLED' => ('Annulé', kTextHint),
        'COMPLETED' => ('Livré', kGreenPrimary),
        _ => (bid.status, kTextSecondary),
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
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: kTextHint,
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
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
                              size: 12, color: kTextSecondary),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('dd MMM yyyy', 'fr')
                                .format(bid.createdAt),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: kTextSecondary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kGreenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Voir',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kGreenPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 12, color: kGreenPrimary),
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
        style: GoogleFonts.plusJakartaSans(
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
            color: kGreenPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            departure,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(height: 1, color: kBorder),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.flight_takeoff_rounded,
              size: 14, color: kGreenPrimary),
        ),
        Expanded(
          child: Container(height: 1, color: kBorder),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            arrival,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
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
            border: Border.all(color: kGreenPrimary, width: 2),
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
        color: kBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: kTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
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
                color: kGreenLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: kGreenPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: kTextSecondary,
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
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kGreenPrimary.withValues(alpha: 0.28),
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
                      style: GoogleFonts.plusJakartaSans(
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
          CircularProgressIndicator(color: kGreenPrimary, strokeWidth: 2.5),
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
                  size: 32, color: kError),
            ),
            const SizedBox(height: 20),
            Text(
              'Erreur de chargement',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
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
                  color: kGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Réessayer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kGreenPrimary,
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
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kGreenPrimary.withValues(alpha: 0.35),
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
              style: GoogleFonts.plusJakartaSans(
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