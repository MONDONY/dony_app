import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_list_chrome.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
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
        message: 'Demande acceptée !',
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is acs.BidWalletInsufficient) {
      _showWalletInsufficientSheet(context, state);
    } else if (state is acs.BidFailed) {
      setState(() => _processingBidIds.clear());
      if (state.cardDeclined) {
        _showCardDeclinedSheet(context, state.message);
      } else {
        DonySnackbar.show(
          context,
          message: state.message,
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
        message: 'Demande acceptée !',
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidRejected) {
      DonySnackbar.show(context, message: 'Demande refusée.');
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidDeleted) {
      DonySnackbar.show(
        context,
        message: 'Demande supprimée.',
        type: DonySnackbarType.success,
      );
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
      if (_processingBidIds.isNotEmpty) {
        setState(() => _processingBidIds.clear());
      }
      ErrorPresenter.show(context, state.error);
    }
  }

  // ── Sheets ───────────────────────────────────────────────────────────────

  void _showCardDeclinedSheet(BuildContext context, String message) {
    DonyBottomSheet.show<void>(
      context,
      title: 'Paiement refusé',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: DonyColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Changez votre carte de commission pour accepter cette demande.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: DonyColors.textMuted),
          ),
        ],
      ),
      stickyBottom: DonyButton(
        label: 'Changer ma carte de commission',
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
    DonyBottomSheet.show<void>(
      context,
      title: 'Solde insuffisant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission requise : ${state.requiredCommission.toStringAsFixed(2)} €',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: DonyColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Solde wallet : ${state.availableBalance.toStringAsFixed(2)} €',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: DonyColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Rechargez votre wallet ou payez la commission directement par carte.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: DonyColors.textMuted),
          ),
        ],
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Recharger mon wallet',
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
              label: 'Payer par carte',
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
              label: 'Ajouter une carte',
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
    final confirmed = await DonyDialog.show(
      context,
      title: 'Refuser cette demande ?',
      message: "L'expéditeur sera informé. Cette action est irréversible.",
      confirmLabel: 'Refuser',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed == true && context.mounted) {
      context.read<BidBloc>().add(BidRejectRequested(bidId));
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Supprimer cette demande ?',
      message:
          'Cette demande refusée sera retirée définitivement de votre liste.',
      confirmLabel: 'Supprimer',
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
    if (bid.paymentMethod == BidPaymentMethod.cash) {
      context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(bidId));
    } else {
      context.read<BidBloc>().add(BidAcceptRequested(bidId));
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
              backgroundColor: cs.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                  ),
                  child: DonyIcon('chevron-left', size: 20, color: cs.primary),
                ),
              ),
              title: Text(
                count > 0 ? 'À traiter ($count)' : 'À traiter',
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
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
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
        return const DonyEmptyState(
          mascotte: DonyMascotteType.assis,
          title: 'Aucune demande à traiter',
          description: 'Partagez votre annonce pour recevoir des demandes.',
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
  final Future<bool> Function() confirmDelete;
  final void Function(String bidId) onDelete;

  const _PendingList({
    required this.bids,
    required this.processingBidIds,
    required this.onAccept,
    required this.onReject,
    required this.confirmDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return const DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: 'Aucune demande à traiter',
        description: 'Partagez votre annonce pour recevoir des demandes.',
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
