import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _kRejectedStatus = 'REJECTED';

class BidListScreen extends StatelessWidget {
  final String announcementId;
  // Route metadata: pass these for the AppBar subtitle
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;

  const BidListScreen({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
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
      ),
    );
  }
}

class _BidListView extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;

  const _BidListView({
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // Build subtitle: "CDG → DSS · jeu 17 avril" when data available
    final String subtitle = _buildSubtitle();

    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidDeleted) {
          DonySnackbar.show(context,
              message: 'Demande supprimée.',
              type: DonySnackbarType.success);
          context.read<BidBloc>().add(BidListRequested(announcementId));
        } else if (state is BidAccepted) {
          DonySnackbar.show(context,
              message: 'Demande acceptée !',
              type: DonySnackbarType.success);
          context.read<BidBloc>().add(BidListRequested(announcementId));
        } else if (state is BidRejected) {
          DonySnackbar.show(context,
              message: 'Demande refusée.',
              type: DonySnackbarType.info);
          context.read<BidBloc>().add(BidListRequested(announcementId));
        } else if (state is BidError) {
          DonySnackbar.show(context,
              message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        // Determine count for AppBar title
        final int count = state is BidListLoaded
            ? state.bids.length
            : 0;

        return Scaffold(
          backgroundColor: DonyColors.bg,
          appBar: AppBar(
            backgroundColor: DonyColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: DonyColors.green400),
              onPressed: () => context.pop(),
              tooltip: 'Retour',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count > 0
                      ? '$count demande${count > 1 ? 's' : ''}'
                      : 'Demandes',
                  style: tt.headlineLarge,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: tt.bodySmall
                        ?.copyWith(color: DonyColors.grey400),
                  ),
              ],
            ),
            actions: [
              // Scanner chip button
              Padding(
                padding: const EdgeInsets.only(right: DonySpacing.md),
                child: _ScannerChipButton(
                  onTap: () => context.push('/tracking/scan'),
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: DonyColors.grey200),
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (departureCityCode != null && arrivalCityCode != null) {
      parts.add('$departureCityCode → $arrivalCityCode');
    }
    if (departureDate != null) {
      parts.add(DateFormat('EEE d MMMM', 'fr').format(departureDate!));
    }
    return parts.join(' · ');
  }

  Widget _buildBody(BuildContext context, BidState state) {
    final tt = Theme.of(context).textTheme;

    if (state is BidLoading) {
      return const Center(
        child: CircularProgressIndicator(color: DonyColors.green400),
      );
    }

    if (state is BidListLoaded) {
      if (state.bids.isEmpty) {
        return const _EmptyView();
      }
      return _BidList(
        bids: state.bids,
        announcementId: announcementId,
      );
    }

    if (state is BidError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: DonyColors.grey200),
              const SizedBox(height: DonySpacing.md),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style:
                    tt.bodyMedium?.copyWith(color: DonyColors.grey400),
              ),
              const SizedBox(height: DonySpacing.base),
              DonyButton(
                label: 'Réessayer',
                onPressed: () => context
                    .read<BidBloc>()
                    .add(BidListRequested(announcementId)),
                variant: DonyButtonVariant.secondary,
                fullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Scanner chip button ───────────────────────────────────────────────────────

class _ScannerChipButton extends StatelessWidget {
  const _ScannerChipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: DonyColors.grey200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded,
                size: 16, color: DonyColors.ink900),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Scanner',
              style: tt.labelMedium?.copyWith(color: DonyColors.ink900),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bid list ──────────────────────────────────────────────────────────────────

class _BidList extends StatelessWidget {
  final List<BidModel> bids;
  final String announcementId;

  const _BidList({required this.bids, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      itemCount: bids.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: DonySpacing.md),
      itemBuilder: (context, i) {
        final bid = bids[i];
        final card = _BidCard(
          bid: bid,
          announcementId: announcementId,
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);

        if (bid.status != _kRejectedStatus) return card;

        return Dismissible(
          key: ValueKey(bid.id),
          direction: DismissDirection.endToStart,
          background: Container(
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
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DonyRadius.sheet),
                ),
                title: Text(
                  'Supprimer cette demande',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                content: Text(
                  'Cette demande refusée sera retirée définitivement de votre liste.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: DonyColors.grey400),
                ),
                actions: [
                  TextButton(
                    onPressed: () => ctx.pop(false),
                    child: Text(
                      'Annuler',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: DonyColors.grey400),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => ctx.pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: DonyColors.error,
                    ),
                    child: Text(
                      'Supprimer',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: DonyColors.white),
                    ),
                  ),
                ],
              ),
            ) ??
                false;
          },
          onDismissed: (_) => context
              .read<BidBloc>()
              .add(BidTravelerDismissRequested(bid.id)),
          child: card,
        );
      },
    );
  }
}

// ── Bid card ──────────────────────────────────────────────────────────────────

class _BidCard extends StatelessWidget {
  final BidModel bid;
  final String announcementId;

  const _BidCard({required this.bid, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: DonyColors.white,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => context.push('/bids/${bid.id}', extra: bid),
        child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: avatar + sender info + amount ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyAvatar(
                name: bid.resolvedSenderName,
                size: DonyAvatarSize.md,
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
                    // "★ rating · X kg"
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: DonyColors.warning),
                        const SizedBox(width: DonySpacing.xxs),
                        Text(
                          '—',
                          style: tt.bodySmall
                              ?.copyWith(color: DonyColors.grey400),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          '· ${bid.weightKg.toStringAsFixed(0)} kg',
                          style: tt.bodySmall
                              ?.copyWith(color: DonyColors.grey400),
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
                    ?.copyWith(color: DonyColors.green400),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),

          // ── Content label ─────────────────────────────────────────
          Text(
            'CONTENU DÉCLARÉ',
            style: tt.labelSmall?.copyWith(color: DonyColors.grey400),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            bid.contentCategory ?? bid.description,
            style: tt.bodySmall?.copyWith(color: DonyColors.ink900),
          ),
          const SizedBox(height: DonySpacing.md),

          // ── Divider ───────────────────────────────────────────────
          const Divider(color: DonyColors.grey200, height: 1),
          const SizedBox(height: DonySpacing.md),

          // ── Row of 2 action buttons ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: DonyButton(
                  label: 'Refuser',
                  variant: DonyButtonVariant.ghost,
                  onPressed: () => context
                      .read<BidBloc>()
                      .add(BidRejectRequested(bid.id)),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: DonyButton(
                  label: 'Accepter',
                  variant: DonyButtonVariant.primary,
                  onPressed: () => context
                      .read<BidBloc>()
                      .add(BidAcceptRequested(bid.id)),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ── Empty view ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DonyColors.green50,
                borderRadius: BorderRadius.circular(DonyRadius.xl),
              ),
              child: const Icon(Icons.inbox_outlined,
                  color: DonyColors.green400, size: 36),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucune demande',
              style: tt.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Partagez votre annonce pour recevoir des demandes d\'expéditeurs.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
            ),
          ],
        ),
      ),
    );
  }
}
