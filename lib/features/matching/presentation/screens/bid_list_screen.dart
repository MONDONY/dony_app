import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ── Status constants ──────────────────────────────────────────────────────────
const _kPending   = 'PENDING';
const _kAccepted  = 'ACCEPTED';
const _kInTransit = 'IN_TRANSIT';
const _kCompleted = 'COMPLETED';
const _kRejected  = 'REJECTED';

// ─────────────────────────────────────────────────────────────────────────────
// BidListScreen — root widget, provides the BloC
// ─────────────────────────────────────────────────────────────────────────────

class BidListScreen extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final int initialTabIndex;

  const BidListScreen({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<BidBloc>()..add(BidListRequested(announcementId)),
      child: _BidListView(
        announcementId: announcementId,
        departureCityCode: departureCityCode,
        arrivalCityCode: arrivalCityCode,
        departureDate: departureDate,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidListView — StatefulWidget with TabController
// ─────────────────────────────────────────────────────────────────────────────

class _BidListView extends StatefulWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final int initialTabIndex;

  const _BidListView({
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
  });

  @override
  State<_BidListView> createState() => _BidListViewState();
}

class _BidListViewState extends State<_BidListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Bids currently being processed (accept in flight) — prevents double-tap.
  final _processingBidIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildSubtitle() {
    final parts = <String>[];
    if (widget.departureCityCode != null && widget.arrivalCityCode != null) {
      parts.add('${widget.departureCityCode} → ${widget.arrivalCityCode}');
    }
    if (widget.departureDate != null) {
      parts.add(DateFormat('EEE d MMMM', 'fr').format(widget.departureDate!));
    }
    return parts.join(' · ');
  }

  void _addProcessing(String bidId) =>
      setState(() => _processingBidIds.add(bidId));

  void _removeProcessing(String bidId) =>
      setState(() => _processingBidIds.remove(bidId));

  // ── BLoC listener ──────────────────────────────────────────────────────────

  void _onStateChange(BuildContext context, BidState state) {
    if (state is BidAccepted) {
      _removeProcessing(state.bid.id);
      DonySnackbar.show(context,
          message: 'Demande acceptée !', type: DonySnackbarType.success);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidRejected) {
      DonySnackbar.show(context, message: 'Demande refusée.');
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidDeleted) {
      DonySnackbar.show(context,
          message: 'Demande supprimée.', type: DonySnackbarType.success);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidNotFound) {
      DonySnackbar.show(
        context,
        message: 'Cette annonce n\'existe plus',
        type: DonySnackbarType.warning,
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else if (state is BidError) {
      // Clear all processing bids so user can retry
      if (_processingBidIds.isNotEmpty) {
        setState(() => _processingBidIds.clear());
      }
      ErrorPresenter.show(context, state.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = _buildSubtitle();

    return BlocConsumer<BidBloc, BidState>(
      listener: _onStateChange,
      builder: (context, state) {
        // Compute per-tab counts for AppBar title
        final allBids =
            state is BidListLoaded ? state.bids : <BidModel>[];
        final pendingBids =
            allBids.where((b) => b.status == _kPending).toList();
        final acceptedBids = allBids
            .where((b) =>
                b.status == _kAccepted ||
                b.status == _kInTransit ||
                b.status == _kCompleted)
            .toList();

        final isOnPendingTab = _tabController.index == 0;
        final titleCount =
            isOnPendingTab ? pendingBids.length : acceptedBids.length;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            leading: IconButton(
              tooltip: 'Retour',
              onPressed: () {
                if (context.canPop()) context.pop();
                else context.go('/home');
              },
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                ),
                child: Icon(Icons.chevron_left_rounded, size: 20, color: cs.primary),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: 200.ms,
                  child: Text(
                    titleCount > 0
                        ? '$titleCount demande${titleCount > 1 ? 's' : ''}'
                        : 'Demandes',
                    key: ValueKey('${_tabController.index}_$titleCount'),
                    style: tt.headlineLarge,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: DonySpacing.md),
                child: _ScannerChipButton(
                  onTap: () => context.push('/tracking/scan'),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize:
                  const Size.fromHeight(1 + kTextTabBarHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: cs.primary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    indicatorColor: cs.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: tt.labelLarge,
                    unselectedLabelStyle: tt.labelLarge,
                    tabs: [
                      Tab(
                        text: pendingBids.isNotEmpty
                            ? 'En attente (${pendingBids.length})'
                            : 'En attente',
                      ),
                      Tab(
                        text: acceptedBids.isNotEmpty
                            ? 'Acceptées (${acceptedBids.length})'
                            : 'Acceptées',
                      ),
                    ],
                  ),
                  Divider(height: 1, color: cs.outline),
                ],
              ),
            ),
          ),
          body: _buildBody(context, state, pendingBids, acceptedBids),
        );
      },
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    BidState state,
    List<BidModel> pendingBids,
    List<BidModel> acceptedBids,
  ) {
    if (state is BidLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (state is BidError) {
      // Only show full-page error if there's no data loaded yet.
      return _ErrorView(
        message: ErrorPresenter.resolve(state.error).message,
        onRetry: () => context
            .read<BidBloc>()
            .add(BidListRequested(widget.announcementId)),
      );
    }

    if (state is BidListLoaded) {
      return TabBarView(
        controller: _tabController,
        children: [
          // Tab 0 — Pending
          _BidTabContent(
            bids: pendingBids,
            announcementId: widget.announcementId,
            processingBidIds: _processingBidIds,
            onAccept: (bidId) {
              _addProcessing(bidId);
              context.read<BidBloc>().add(BidAcceptRequested(bidId));
            },
            onReject: (bidId) => _showRejectDialog(context, bidId),
            emptyTitle: 'Aucune demande en attente',
            emptyDescription:
                'Partagez votre annonce pour recevoir des demandes.',
            emptyIcon: Icons.inbox_outlined,
          ),
          // Tab 1 — Accepted / In transit / Completed
          _BidTabContent(
            bids: acceptedBids,
            announcementId: widget.announcementId,
            processingBidIds: const {},
            onAccept: null,
            onReject: null,
            emptyTitle: 'Aucune demande acceptée',
            emptyDescription: "Vous n'avez accepté aucune demande pour l'instant.",
            emptyIcon: Icons.check_circle_outline_rounded,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Reject confirmation dialog ─────────────────────────────────────────────

  Future<void> _showRejectDialog(BuildContext context, String bidId) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Refuser cette demande ?',
      message: "L'expéditeur sera informé. Cette action est irréversible.",
      confirmLabel: 'Refuser',
      variant: DonyDialogVariant.destructive,
      icon: Icons.cancel_rounded,
    );
    if (confirmed == true && context.mounted) {
      context.read<BidBloc>().add(BidRejectRequested(bidId));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidTabContent — list view for one tab
// ─────────────────────────────────────────────────────────────────────────────

class _BidTabContent extends StatelessWidget {
  final List<BidModel> bids;
  final String announcementId;
  final Set<String> processingBidIds;
  final void Function(String bidId)? onAccept;
  final void Function(String bidId)? onReject;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;

  const _BidTabContent({
    required this.bids,
    required this.announcementId,
    required this.processingBidIds,
    required this.onAccept,
    required this.onReject,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: emptyTitle,
        description: emptyDescription,
      ).animate().fadeIn(duration: 300.ms);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        DonyLayout.hPadding(context),
        DonySpacing.xl,
        DonyLayout.hPadding(context),
        DonySpacing.huge,
      ),
      itemCount: bids.length,
      separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
      itemBuilder: (context, i) {
        final bid = bids[i];
        final isProcessing = processingBidIds.contains(bid.id);

        final card = _BidCard(
          bid: bid,
          isProcessing: isProcessing,
          onAccept: onAccept != null ? () => onAccept!(bid.id) : null,
          onReject: onReject != null ? () => onReject!(bid.id) : null,
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);

        // Swipe-to-delete only for REJECTED bids (defensive — they normally
        // don't appear in these filtered tabs, but handled gracefully)
        if (bid.status == _kRejected) {
          return Dismissible(
            key: ValueKey('dismiss_${bid.id}'),
            direction: DismissDirection.endToStart,
            background: _DismissBackground(),
            confirmDismiss: (_) => _confirmDelete(context),
            onDismissed: (_) => context
                .read<BidBloc>()
                .add(BidTravelerDismissRequested(bid.id)),
            child: card,
          );
        }

        return card;
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Supprimer cette demande ?',
      message: 'Cette demande refusée sera retirée définitivement de votre liste.',
      confirmLabel: 'Supprimer',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_outline_rounded,
    );
    return confirmed == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidCard — status-aware card
// ─────────────────────────────────────────────────────────────────────────────

class _BidCard extends StatelessWidget {
  final BidModel bid;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _BidCard({
    required this.bid,
    required this.isProcessing,
    this.onAccept,
    this.onReject,
  });

  bool get _isPending  => bid.status == _kPending;
  bool get _isRejected => bid.status == _kRejected;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        // Always navigates to detail — no exceptions
        onTap: () => context.push('/bids/${bid.id}', extra: bid),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: avatar + sender info + amount ──────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyAvatar(
                    name: bid.resolvedSenderName,
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bid.resolvedSenderName,
                          style: tt.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DonySpacing.xxs),
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 13, color: cs.warning),
                            const SizedBox(width: DonySpacing.xxs),
                            Text(
                              '—',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              '· ${bid.weightKg.toStringAsFixed(0)} kg',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Text(
                    bid.pricePerKg != null
                        ? '${(bid.weightKg * bid.pricePerKg!).toStringAsFixed(0)} €'
                        : '—',
                    style: tt.titleLarge
                        ?.copyWith(color: cs.primary),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              // ── Content label ────────────────────────────────────
              Text(
                'CONTENU DÉCLARÉ',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                bid.contentCategory ?? bid.description ?? '—',
                style: tt.bodySmall?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: DonySpacing.md),

              // ── Divider ──────────────────────────────────────────
              Divider(color: cs.outline, height: 1),
              const SizedBox(height: DonySpacing.md),

              // ── Bottom area: actions OR status badge ─────────────
              if (_isPending && onAccept != null && onReject != null)
                _PendingActions(
                  isProcessing: isProcessing,
                  onAccept: onAccept!,
                  onReject: onReject!,
                )
              else if (bid.status == _kAccepted)
                _StatusBadge(
                  label: '✓ Accepté',
                  icon: Icons.check_circle_rounded,
                  color: cs.success,
                  bgColor: cs.successLight,
                )
              else if (bid.status == _kInTransit)
                _StatusBadge(
                  label: '↗ En transit',
                  icon: Icons.local_shipping_outlined,
                  color: cs.info,
                  bgColor: cs.infoLight,
                )
              else if (bid.status == _kCompleted)
                _StatusBadge(
                  label: '✓ Livré',
                  icon: Icons.verified_rounded,
                  color: DonyColors.success700,
                  bgColor: cs.successLight,
                )
              else if (_isRejected)
                _StatusBadge(
                  label: 'Refusé',
                  icon: Icons.cancel_rounded,
                  color: cs.error,
                  bgColor: cs.errorLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingActions — Refuser + Accepter buttons with debounce
// ─────────────────────────────────────────────────────────────────────────────

class _PendingActions extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingActions({
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DonyButton(
            label: 'Refuser',
            variant: DonyButtonVariant.ghost,
            onPressed: isProcessing ? null : onReject,
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: DonyButton(
            label: 'Accepter',
            isLoading: isProcessing,
            onPressed: isProcessing ? null : onAccept,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusBadge — small chip shown on non-pending cards
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DismissBackground — red delete background for swipe
// ─────────────────────────────────────────────────────────────────────────────

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete_outline_rounded,
              color: DonyColors.white, size: 28),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Supprimer',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: DonyColors.white),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScannerChipButton — QR scanner action chip in AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerChipButton extends StatelessWidget {
  const _ScannerChipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded,
                size: 16, color: cs.onSurface),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Scanner',
              style: tt.labelMedium?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorView — error state with retry
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: cs.outlineVariant),
            const SizedBox(height: DonySpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Réessayer',
              onPressed: onRetry,
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}