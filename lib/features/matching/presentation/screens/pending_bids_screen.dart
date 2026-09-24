import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_accept_dispatch.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_list_chrome.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ── Status constants ──────────────────────────────────────────────────────────
const _kPending = 'PENDING';
const _kPaymentEscrowed = 'PAYMENT_ESCROWED';
const _kRejected = 'REJECTED';

// ─────────────────────────────────────────────────────────────────────────────
// PendingBidsScreen — écran dédié « À traiter » : demandes en attente
// (PENDING + PAYMENT_ESCROWED) avec Refuser/Accepter. Atteint depuis le bouton
// « À traiter » de la liste des demandes.
// ─────────────────────────────────────────────────────────────────────────────

class PendingBidsScreen extends StatelessWidget {
  final String announcementId;

  const PendingBidsScreen({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<BidBloc>()..add(BidListRequested(announcementId)),
        ),
        BlocProvider(create: (_) => getIt<BidAcceptanceBloc>()),
      ],
      child: _PendingBidsView(announcementId: announcementId),
    );
  }
}

/// Variante de test : `BidBloc` et `BidAcceptanceBloc` doivent être fournis par
/// le contexte parent. Utilisé uniquement en tests.
@visibleForTesting
class PendingBidsScreenTesting extends StatelessWidget {
  final String announcementId;

  const PendingBidsScreenTesting({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context) =>
      _PendingBidsView(announcementId: announcementId);
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingBidsView — état + logique d'acceptation (cash / carte / wallet)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingBidsView extends StatefulWidget {
  final String announcementId;

  const _PendingBidsView({required this.announcementId});

  @override
  State<_PendingBidsView> createState() => _PendingBidsViewState();
}

class _PendingBidsViewState extends State<_PendingBidsView> {
  /// Bids en cours d'acceptation (requête en vol) — anti double-tap.
  final _processingBidIds = <String>{};

  /// L'event d'intention « ouverture À traiter » n'est tiré qu'une fois.
  bool _analyticsFired = false;

  void _addProcessing(String bidId) =>
      setState(() => _processingBidIds.add(bidId));

  void _removeProcessing(String bidId) =>
      setState(() => _processingBidIds.remove(bidId));

  void _maybeFireAnalytics(int count) {
    if (_analyticsFired) return;
    _analyticsFired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.pendingRequestsOpened,
          properties: {'count': count},
        ),
      );
    });
  }

  // ── BLoC listeners ─────────────────────────────────────────────────────────

  void _onCashAcceptanceStateChange(
    BuildContext context,
    acs.BidAcceptanceState state,
  ) {
    if (state is acs.BidAccepted) {
      setState(() => _processingBidIds.clear());
      DonySnackbar.show(
        context,
        message: context.l10n.bidListAcceptedSnackbar,
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is acs.BidWalletInsufficient) {
      _showWalletInsufficientSheet(context, state);
    } else if (state is acs.BidFailed) {
      setState(() => _processingBidIds.clear());
      final message = state.displayMessage(context.l10n);
      if (state.cardDeclined) {
        _showCardDeclinedSheet(context, message);
      } else {
        DonySnackbar.show(
          context,
          message: message,
          type: DonySnackbarType.error,
        );
      }
    }
  }

  void _onStateChange(BuildContext context, BidState state) {
    if (state is BidAccepted) {
      _removeProcessing(state.bid.id);
      DonySnackbar.show(
        context,
        message: context.l10n.bidListAcceptedSnackbar,
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidRejected) {
      DonySnackbar.show(context, message: context.l10n.bidListRejectedSnackbar);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidDeleted) {
      DonySnackbar.show(
        context,
        message: context.l10n.bidListDeletedSnackbar,
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidNotFound) {
      DonySnackbar.show(
        context,
        message: context.l10n.listingAnnouncementGoneMessage,
        type: DonySnackbarType.warning,
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else if (state is BidError) {
      if (_processingBidIds.isNotEmpty) {
        setState(() => _processingBidIds.clear());
      }
      ErrorPresenter.show(context, state.error);
    }
  }

  // ── Sheets ───────────────────────────────────────────────────────────────

  void _showCardDeclinedSheet(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    DonyBottomSheet.show<void>(
      context,
      title: l.bidListCardDeclinedSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            l.bidListCardDeclinedHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      stickyBottom: DonyButton(
        label: l.bidListChangeCommissionCardButton,
        onPressed: () {
          context.pop();
          context.push('/payments/commission-method');
        },
      ),
    );
  }

  void _showWalletInsufficientSheet(
    BuildContext context,
    acs.BidWalletInsufficient state,
  ) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    DonyBottomSheet.show<void>(
      context,
      title: l.bidListWalletInsufficientTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, line) in commissionShortfallLines(
            l,
            breakdown: state.breakdown,
            requiredCommission: state.requiredCommission,
            availableBalance: state.availableBalance,
            currency: state.currency,
          ).indexed) ...[
            if (i > 0) const SizedBox(height: 4),
            Text(
              line,
              style: i == 0
                  ? Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: cs.onSurface)
                  : Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l.bidListWalletInsufficientHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: l.bidListWalletTopupButton,
            onPressed: () async {
              context.pop();
              final recharged = await context.push<bool>(
                '/payments/wallet/topup/method',
              );
              if ((recharged ?? false) && context.mounted) {
                context.read<BidAcceptanceBloc>().add(
                  ace.BidAcceptRequested(state.bidId),
                );
              }
            },
          ),
          if (state.hasCard) ...[
            const SizedBox(height: 8),
            DonyButton(
              label: l.bidListPayByCardButton,
              variant: DonyButtonVariant.secondary,
              onPressed: () {
                context.pop();
                context.read<BidAcceptanceBloc>().add(
                  ace.BidAcceptWithCardRequested(state.bidId),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            DonyButton(
              label: l.bidListAddCardButton,
              variant: DonyButtonVariant.secondary,
              onPressed: () async {
                context.pop();
                await context.push('/payments/commission-method');
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(BuildContext context, String bidId) async {
    final l = context.l10n;
    final confirmed = await DonyDialog.show(
      context,
      title: l.bidListDeclineDialogTitle,
      message: l.bidListDeclineDialogMessage,
      confirmLabel: l.bidListDeclineButton,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed == true && context.mounted) {
      context.read<BidBloc>().add(BidRejectRequested(bidId));
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await DonyDialog.show(
      context,
      title: l.bidListDeleteDialogTitle,
      message: l.bidListDeleteDialogMessage,
      confirmLabel: l.commonDelete,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'trash-2',
    );
    return confirmed == true;
  }

  void _onAccept(
    BuildContext context,
    List<BidModel> pendingBids,
    String bidId,
  ) {
    _addProcessing(bidId);
    final bid = pendingBids.firstWhere((b) => b.id == bidId);
    dispatchBidAccept(context, bid);
  }

  // Ouvre le détail et recharge la liste au retour : le statut du bid peut
  // changer côté détail (accept/refus/scan) et l'écran « À traiter » doit se
  // mettre à jour seul (règle CLAUDE.md — rafraîchissement après navigation).
  Future<void> _openDetail(BuildContext context, BidModel bid) async {
    await context.push('/bids/${bid.id}', extra: bid);
    if (context.mounted) {
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
      listener: _onCashAcceptanceStateChange,
      child: BlocConsumer<BidBloc, BidState>(
        listener: _onStateChange,
        builder: (context, state) {
          final allBids = state is BidListLoaded ? state.bids : <BidModel>[];
          final pendingBids = allBids
              .where(
                (b) => b.status == _kPending || b.status == _kPaymentEscrowed,
              )
              .toList();

          if (state is BidListLoaded) {
            _maybeFireAnalytics(pendingBids.length);
          }

          final count = pendingBids.length;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              actions: const [DonyFeedbackButton()],
              backgroundColor: cs.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              leading: const DonyAppBarBackButton(),
              title: Text(
                count > 0
                    ? context.l10n.bidListPendingTitleWithCount(count)
                    : context.l10n.bidListFilterToReview,
                style: tt.headlineLarge,
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: cs.outline, height: 1),
              ),
            ),
            body: _buildBody(context, state, pendingBids),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BidState state,
    List<BidModel> pendingBids,
  ) {
    if (state is BidLoading) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          DonyLayout.hPadding(context),
          DonySpacing.lg,
          DonyLayout.hPadding(context),
          DonySpacing.huge,
        ),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
        itemBuilder: (_, _) => const DonyUserCardSkeleton(),
      );
    }

    if (state is BidError) {
      return BidListErrorView(
        message: ErrorPresenter.resolve(state.error).message,
        onRetry: () => context.read<BidBloc>().add(
          BidListRequested(widget.announcementId),
        ),
      );
    }

    if (state is BidListLoaded) {
      return _buildPendingList(pendingBids);
    }

    return const SizedBox.shrink();
  }

  // Liste « À traiter » avec filtre minBidPriceEur. Le filtre n'est appliqué que
  // si BusinessPrefsBloc est enregistré (toujours le cas en prod ; absent dans
  // certains widget tests isolés → liste non filtrée).
  Widget _buildPendingList(List<BidModel> pendingBids) {
    Widget content(BuildContext context, int minPrice) {
      final visibleBids = minPrice == 0
          ? pendingBids
          : pendingBids
                .where((b) => b.pricePerKg == null || b.pricePerKg! >= minPrice)
                .toList();
      final hiddenCount = pendingBids.length - visibleBids.length;

      if (visibleBids.isEmpty && hiddenCount == 0) {
        return DonyEmptyState(
          mascotte: DonyMascotteType.assis,
          title: context.l10n.bidListEmptyPendingTitle,
          description: context.l10n.bidListEmptyPendingDescription,
        ).animate().fadeIn(duration: 300.ms);
      }

      return Column(
        children: [
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                0,
              ),
              child: HiddenBidsBanner(
                count: hiddenCount,
                onShowAll: () =>
                    getIt<BusinessPrefsBloc>().add(const MinBidPriceChanged(0)),
              ),
            ),
          Expanded(
            child: _PendingList(
              bids: visibleBids,
              processingBidIds: _processingBidIds,
              onAccept: (bidId) => _onAccept(context, pendingBids, bidId),
              onReject: (bidId) => _showRejectDialog(context, bidId),
              onOpenDetail: (bid) => _openDetail(context, bid),
              confirmDelete: () => _confirmDelete(context),
              onDelete: (bidId) => context.read<BidBloc>().add(
                BidTravelerDismissRequested(bidId),
              ),
            ),
          ),
        ],
      );
    }

    if (!getIt.isRegistered<BusinessPrefsBloc>()) {
      return Builder(builder: (context) => content(context, 0));
    }
    return BlocBuilder<BusinessPrefsBloc, BusinessPrefsState>(
      bloc: getIt<BusinessPrefsBloc>(),
      builder: (context, prefs) => content(context, prefs.minBidPriceEur),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingList — liste des cartes en attente
// ─────────────────────────────────────────────────────────────────────────────

class _PendingList extends StatelessWidget {
  final List<BidModel> bids;
  final Set<String> processingBidIds;
  final void Function(String bidId) onAccept;
  final void Function(String bidId) onReject;
  final void Function(BidModel bid) onOpenDetail;
  final Future<bool> Function() confirmDelete;
  final void Function(String bidId) onDelete;

  const _PendingList({
    required this.bids,
    required this.processingBidIds,
    required this.onAccept,
    required this.onReject,
    required this.onOpenDetail,
    required this.confirmDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: context.l10n.bidListEmptyPendingTitle,
        description: context.l10n.bidListEmptyPendingDescription,
      ).animate().fadeIn(duration: 300.ms);
    }

    final hp = DonyLayout.hPadding(context);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hp, DonySpacing.xl, hp, DonySpacing.huge),
      itemCount: bids.length,
      separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
      itemBuilder: (context, i) {
        final bid = bids[i];
        final card =
            BidCard(
                  bid: bid,
                  isProcessing: processingBidIds.contains(bid.id),
                  onAccept: () => onAccept(bid.id),
                  onReject: () => onReject(bid.id),
                  onTap: () => onOpenDetail(bid),
                )
                .animate(delay: Duration(milliseconds: i * 60))
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);

        // Swipe-to-delete défensif pour les bids REJECTED (n'apparaissent
        // normalement pas dans cet écran).
        if (bid.status == _kRejected) {
          return Dismissible(
            key: ValueKey('dismiss_${bid.id}'),
            direction: DismissDirection.endToStart,
            background: const DismissBackground(),
            confirmDismiss: (_) => confirmDelete(),
            onDismissed: (_) => onDelete(bid.id),
            child: card,
          );
        }
        return card;
      },
    );
  }
}
