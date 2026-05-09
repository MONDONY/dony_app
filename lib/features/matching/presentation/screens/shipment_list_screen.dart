import 'dart:ui';

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
import 'package:dony/features/matching/presentation/widgets/search_form_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
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

  // Cache the last loaded lists so checkout's BidLoading doesn't wipe the UI.
  List<BidModel> _inProgress = [];
  List<BidModel> _upcoming = [];
  List<BidModel> _past = [];
  bool _hasData = false;
  bool _isRefreshing = false;

  // ID of the bid currently going through checkout — drives button loading state.
  String? _payingBidId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
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

  void _startPayment(BidModel bid) {
    setState(() => _payingBidId = bid.id);
    context.read<BidBloc>().add(BidCheckoutRequested(
      announcementId: bid.announcementId,
      weightKg: bid.weightKg,
      declaredValueEur: bid.declaredValueEur,
      description: bid.description,
      contentCategory: bid.contentCategory ?? '',
      recipientName: bid.recipientName ?? '',
      recipientPhone: bid.recipientPhone ?? '',
    ));
  }

  Future<void> _presentPaymentSheet(
    BuildContext context,
    CheckoutPaymentSheetReady state,
  ) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: state.clientSecret,
          merchantDisplayName: 'Dony',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (!context.mounted) return;
      context.read<BidBloc>().add(BidConfirmPaymentRequested(state.bidId));
      context.push('/bids/${state.bidId}?from=payment');
    } on StripeException catch (e) {
      if (!context.mounted) return;
      setState(() => _payingBidId = null);
      if (e.error.code != FailureCode.Canceled) {
        DonySnackbar.show(context,
            message: 'Erreur de paiement: ${e.error.message}',
            type: DonySnackbarType.error);
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _payingBidId = null);
      DonySnackbar.show(context,
          message: 'Erreur: ${e.toString()}', type: DonySnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(
          listener: (context, state) {
            if (state is BidListLoaded) {
              final bids = state.bids;
              setState(() {
                _inProgress = bids.where((b) => b.status == 'ACCEPTED').toList();
                _upcoming = bids
                    .where((b) =>
                        b.status == 'PENDING' || b.status == 'AWAITING_PAYMENT')
                    .toList();
                _past = bids
                    .where((b) =>
                        b.status == 'COMPLETED' ||
                        b.status == 'REJECTED' ||
                        b.status == 'CANCELLED' ||
                        b.status == 'NO_SHOW' ||
                        b.status == 'EXPIRED' ||
                        b.status == 'PARCEL_REFUSED')
                    .toList();
                _hasData = true;
                _isRefreshing = state.isRefreshing;
              });
            } else if (state is BidCheckoutReady) {
              context.read<PaymentBloc>().add(BidCheckoutPaymentRequested(
                clientSecret: state.response.clientSecret,
                publishableKey: state.response.publishableKey,
                bidId: state.response.bidId,
              ));
            } else if (state is BidDeleted) {
              DonySnackbar.show(context,
                  message: 'Envoi supprimé', type: DonySnackbarType.success);
              context.read<BidBloc>().add(const BidMyListAutoRefreshRequested(force: true));
            } else if (state is BidError && _payingBidId != null) {
              setState(() => _payingBidId = null);
              DonySnackbar.show(context,
                  message: state.message, type: DonySnackbarType.error);
            }
          },
        ),
        BlocListener<PaymentBloc, PaymentState>(
          listener: (context, state) async {
            if (state is CheckoutPaymentSheetReady) {
              await _presentPaymentSheet(context, state);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Builder(
          builder: (context) {
            final authState = context.watch<AuthBloc>().state;
            if (authState is AuthAuthenticated && authState.user.isTraveler) {
              return _SendFab();
            }
            return const SizedBox.shrink();
          },
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: _AuroraMeshBackground()),
            BlocBuilder<BidBloc, BidState>(
          builder: (context, state) {
            if (!_hasData && (state is BidLoading || state is BidInitial)) {
              return const _LoadingView();
            }
            if (!_hasData && state is BidError) {
              return _ErrorView(message: state.message);
            }

            return Stack(
              children: [
                NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: _EnvoisHeader(
                        inProgressCount: _inProgress.length,
                        upcomingCount: _upcoming.length,
                        activeShipment:
                            _inProgress.isNotEmpty ? _inProgress.first : null,
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
                        bids: _inProgress,
                        emptyMessage: 'Aucun envoi en cours',
                        emptySubtitle:
                            'Vos colis acceptés par un voyageur apparaîtront ici.',
                        emptyIcon: Icons.local_shipping_outlined,
                        onRefresh: () async => context
                            .read<BidBloc>()
                            .add(const BidMyListAutoRefreshRequested(force: true)),
                      ),
                      _ShipmentListView(
                        key: const PageStorageKey('tab_upcoming'),
                        bids: _upcoming,
                        emptyMessage: 'Aucune demande en attente',
                        emptySubtitle:
                            'Trouvez un voyageur et faites votre premier envoi.',
                        emptyIcon: Icons.hourglass_empty_rounded,
                        payingBidId: _payingBidId,
                        onPayTap: _startPayment,
                        onRefresh: () async => context
                            .read<BidBloc>()
                            .add(const BidMyListAutoRefreshRequested(force: true)),
                      ),
                      _ShipmentListView(
                        key: const PageStorageKey('tab_past'),
                        bids: _past,
                        emptyMessage: 'Aucun historique',
                        emptySubtitle:
                            'Vos livraisons terminées apparaîtront ici.',
                        emptyIcon: Icons.history_rounded,
                        onRefresh: () async => context
                            .read<BidBloc>()
                            .add(const BidMyListAutoRefreshRequested(force: true)),
                        onDelete: (bid) => context
                            .read<BidBloc>()
                            .add(BidDeleteRequested(bid.id)),
                      ),
                    ],
                  ),
                ),
                if (_isRefreshing)
                  const LinearProgressIndicator(
                    color: DonyColors.primary,
                    minHeight: 2,
                  ),
              ],
            );
          },
        ),
          ],
        ),
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
    DonyBottomSheet.show<void>(
      context,
      child: _SavedTripsSheet(
        savedService: _savedService,
        onChanged: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final savedCount = _savedService.getSavedTrips().length;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + DonySpacing.sm),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, DonySpacing.sm, DonySpacing.base, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Mes envois',
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(DonyRadius.md),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.92)),
                              boxShadow: [
                                BoxShadow(
                                  color: DonyColors.primary.withValues(alpha: 0.10),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              savedCount > 0
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: savedCount > 0
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      if (savedCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$savedCount',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimary,
                                  fontSize: 10,
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
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, 0, DonySpacing.lg, 0),
            child: Row(
              children: [
                _StatChip(
                  count: widget.inProgressCount,
                  label: 'en cours',
                  color: DonyColors.success,
                  bgColor: DonyColors.successLight,
                ),
                const SizedBox(width: DonySpacing.sm),
                _StatChip(
                  count: widget.upcomingCount,
                  label: 'en attente',
                  color: DonyColors.warning,
                  bgColor: DonyColors.warningLight,
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),
          ),
          if (widget.activeShipment != null) ...[
            const SizedBox(height: DonySpacing.lg),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg, 0, DonySpacing.lg, 0),
              child: _ActiveShipmentBanner(bid: widget.activeShipment!),
            )
                .animate()
                .fadeIn(delay: 120.ms)
                .slideY(begin: 0.05, curve: Curves.easeOutCubic),
          ],
          const SizedBox(height: DonySpacing.lg),
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
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DonySpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
              boxShadow: [
                BoxShadow(
                  color: DonyColors.primary.withValues(alpha: 0.09),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'COLIS EN TRANSIT',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: cs.onSurface,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              shortDesc,
              style: tt.headlineMedium?.copyWith(
                color: cs.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.flight_takeoff_rounded,
                    color: cs.onSurfaceVariant, size: 13),
                const SizedBox(width: 6),
                Text(
                  '${bid.departureCity ?? '—'} → ${bid.arrivalCity ?? '—'}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${bid.weightKg} kg',
                  style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.base),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _progressLabel,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
              ],
            ),
          ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, 10, DonySpacing.lg, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
            ),
            child: TabBar(
              controller: controller,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [DonyColors.blue700, cs.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.zero,
              padding: const EdgeInsets.all(3),
              labelColor: cs.onPrimary,
              unselectedLabelColor: cs.onSurfaceVariant,
              labelStyle: tt.labelMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: tt.labelMedium?.copyWith(
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
  final String? payingBidId;
  final void Function(BidModel)? onPayTap;
  final Future<void> Function()? onRefresh;
  final void Function(BidModel)? onDelete;

  const _ShipmentListView({
    super.key,
    required this.bids,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.emptyIcon,
    this.payingBidId,
    this.onPayTap,
    this.onRefresh,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final child = bids.isEmpty
        ? _EmptyView(icon: emptyIcon, title: emptyMessage, subtitle: emptySubtitle)
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(h, DonySpacing.base, h, 100),
            itemCount: bids.length,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
            itemBuilder: (_, i) {
              final bid = bids[i];
              final card = _ShipmentCard(
                bid: bid,
                index: i,
                isPaymentLoading: payingBidId == bid.id,
                onPayTap: onPayTap != null ? () => onPayTap!(bid) : null,
              );
              if (onDelete == null) return card;
              return Dismissible(
                key: ValueKey('dismiss_${bid.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => onDelete!(bid),
                background: _DeleteBackground(),
                child: card,
              );
            },
          );

    if (onRefresh == null) return child;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: DonyColors.primary,
      child: child,
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final confirmed = await DonyDialog.show(
    context,
    title: 'Supprimer cet envoi ?',
    message: 'Il sera retiré de votre historique. Cette action est irréversible.',
    confirmLabel: 'Supprimer',
    variant: DonyDialogVariant.destructive,
    icon: Icons.delete_outline_rounded,
  );
  return confirmed == true;
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: DonySpacing.xl),
      decoration: BoxDecoration(
        color: DonyColors.error,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete_outline_rounded,
              color: DonyColors.white, size: 26),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Supprimer',
            style: tt.labelSmall?.copyWith(color: DonyColors.white),
          ),
        ],
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _ShipmentCard extends StatelessWidget {
  final BidModel bid;
  final int index;
  final bool isPaymentLoading;
  final VoidCallback? onPayTap;

  const _ShipmentCard({
    required this.bid,
    required this.index,
    this.isPaymentLoading = false,
    this.onPayTap,
  });

  ({String label, DonyBadgeType type, Color barColor}) _statusInfo(
      ColorScheme cs) =>
      switch (bid.status) {
        'AWAITING_PAYMENT' => (
            label: 'Paiement requis',
            type: DonyBadgeType.error,
            barColor: DonyColors.warning,
          ),
        'PENDING' => (
            label: 'En attente',
            type: DonyBadgeType.warning,
            barColor: DonyColors.warning,
          ),
        'ACCEPTED' => (
            label: 'Accepté',
            type: DonyBadgeType.success,
            barColor: DonyColors.success,
          ),
        'REJECTED' => (
            label: 'Refusé',
            type: DonyBadgeType.error,
            barColor: cs.error,
          ),
        'CANCELLED' => (
            label: 'Annulé',
            type: DonyBadgeType.error,
            barColor: cs.outline,
          ),
        'COMPLETED' => (
            label: 'Livré',
            type: DonyBadgeType.success,
            barColor: cs.primary,
          ),
        'NO_SHOW' => (
            label: 'Voyageur absent',
            type: DonyBadgeType.error,
            barColor: cs.outline,
          ),
        'EXPIRED' => (
            label: 'Expiré',
            type: DonyBadgeType.error,
            barColor: cs.outline,
          ),
        'PARCEL_REFUSED' => (
            label: 'Colis refusé',
            type: DonyBadgeType.error,
            barColor: cs.error,
          ),
        _ => (
            label: bid.status,
            type: DonyBadgeType.info,
            barColor: cs.onSurfaceVariant,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = _statusInfo(cs);

    return GestureDetector(
      onTap: () async {
        await context.push('/bids/${bid.id}', extra: bid);
        if (context.mounted) {
          context.read<BidBloc>().add(BidMyListRequested());
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
              boxShadow: DonyShadow.sm,
            ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: info.barColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DonyBadge(label: info.label, type: info.type),
                          const Spacer(),
                          Text(
                            '#${bid.id.substring(0, 8).toUpperCase()}',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.outline,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.md),
                      Text(
                        bid.description.length > 52
                            ? '${bid.description.substring(0, 52)}…'
                            : bid.description,
                        style: tt.titleLarge?.copyWith(
                          color: cs.onSurface,
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
                            const SizedBox(width: DonySpacing.sm),
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
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('dd MMM yyyy', 'fr')
                                .format(bid.createdAt),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (bid.status == 'AWAITING_PAYMENT' &&
                              onPayTap != null)
                            GestureDetector(
                              onTap: isPaymentLoading ? null : onPayTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.md, vertical: 6),
                                decoration: BoxDecoration(
                                  color: DonyColors.warning,
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.sm),
                                ),
                                child: isPaymentLoading
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: DonyColors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.payment_rounded,
                                              size: 12,
                                              color: DonyColors.white),
                                          const SizedBox(width: DonySpacing.xs),
                                          Text(
                                            'Payer maintenant',
                                            style: tt.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: DonyColors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.md, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.sm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Voir',
                                    style: tt.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: DonySpacing.xs),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 12, color: cs.primary),
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
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index))
        .slideY(begin: 0.05, curve: Curves.easeOutCubic),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String departure;
  final String arrival;

  const _RouteRow({required this.departure, required this.arrival});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            departure,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(height: 1, color: cs.outline),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.flight_takeoff_rounded,
              size: 14, color: cs.primary),
        ),
        Expanded(
          child: Container(height: 1, color: cs.outline),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            arrival,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
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
            border: Border.all(color: cs.primary, width: 2),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: DonyColors.bgApp,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aurora Mesh Background ───────────────────────────────────────────────────

class _AuroraMeshBackground extends StatelessWidget {
  const _AuroraMeshBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFEDF5FF),
                Color(0xFFF2F0FF),
                Color(0xFFF7F3ED),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: [0.0, 0.4, 1.0],
            ),
          ),
        ),
        // Orbe bleu nord-est
        Positioned(
          top: -80,
          right: -60,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x240B5FFF),
                    Color(0x146C63FF),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.4, 0.7],
                ),
              ),
            ),
          ),
        ),
        // Orbe terracotta ouest
        Positioned(
          top: 120,
          left: -80,
          child: IgnorePointer(
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x17D96A3A),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.65],
                ),
              ),
            ),
          ),
        ),
        // Orbe vert sud-est
        Positioned(
          bottom: 100,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x0F22C55E),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.65],
                ),
              ),
            ),
          ),
        ),
      ],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: cs.primary),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              title,
              style: tt.titleLarge?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            GestureDetector(
              onTap: () async {
                final params = await SearchFormBottomSheet.show(context);
                if (params != null && context.mounted) {
                  context.push('/search', extra: params);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.xl, vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DonyColors.blue700, DonyColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: DonyColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded,
                        color: DonyColors.textOnBrand, size: 16),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      'Rechercher un trajet',
                      style: tt.labelLarge?.copyWith(
                        color: DonyColors.textOnBrand,
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
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 32, color: cs.error),
            ),
            const SizedBox(height: DonySpacing.lg),
            Text(
              'Erreur de chargement',
              style: tt.titleLarge?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            GestureDetector(
              onTap: () => context.read<BidBloc>().add(BidMyListRequested()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.lg, vertical: DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Réessayer',
                  style: tt.labelLarge?.copyWith(color: cs.primary),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () async {
        final params = await SearchFormBottomSheet.show(context);
        if (params != null && context.mounted) {
          context.push('/search', extra: params);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DonyColors.blue700, cs.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: cs.onPrimary, size: 20),
            const SizedBox(width: DonySpacing.sm),
            Text(
              'Envoyer un colis',
              style: tt.labelLarge?.copyWith(color: cs.onPrimary),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Titre
          Row(
            children: [
              Icon(Icons.bookmark_rounded, color: cs.primary, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Trajets sauvegardés',
                style: tt.headlineMedium?.copyWith(color: cs.onSurface),
              ),
              const Spacer(),
              if (_trips.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_trips.length}',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),

          if (_trips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border_rounded,
                        size: 48, color: cs.outline),
                    const SizedBox(height: DonySpacing.md),
                    Text(
                      'Aucun trajet sauvegardé',
                      style: tt.titleLarge?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Appuie sur 🔖 dans le profil d\'un voyageur pour sauvegarder.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.outline,
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
                      color: DonyColors.bgApp,
                      borderRadius: BorderRadius.circular(DonyRadius.lg),
                      border: Border.all(color: cs.outline),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.fromLTRB(14, DonySpacing.sm, DonySpacing.sm, DonySpacing.sm),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [DonyColors.blue700, DonyColors.blue300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials(a),
                            style: tt.labelLarge?.copyWith(
                              color: DonyColors.textOnBrand,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        '${a.departureCity} → ${a.arrivalCity}',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('d MMM yyyy', 'fr').format(a.departureDate)} · '
                        '${a.availableKg.toStringAsFixed(0)} kg · '
                        '${a.pricePerKg.toStringAsFixed(0)} €/kg',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Bouton voir
                          GestureDetector(
                            onTap: () {
                              context.pop();
                              showTravelerAnnouncementSheet(
                                  context, announcement: a);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.sm),
                              ),
                              child: Text(
                                'Voir',
                                style: tt.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          // Bouton supprimer
                          IconButton(
                            icon: Icon(Icons.bookmark_remove_rounded,
                                color: cs.outline, size: 20),
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
    );
  }
}
