import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ── Status constants (onglet « En attente ») ──────────────────────────────────
const _kPending         = 'PENDING';
const _kPaymentEscrowed = 'PAYMENT_ESCROWED';
const _kRejected        = 'REJECTED';

// ─────────────────────────────────────────────────────────────────────────────
// BidListScreen — root widget, fournit les BloCs
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<BidBloc>()..add(BidListRequested(announcementId)),
        ),
        BlocProvider(create: (_) => getIt<BidAcceptanceBloc>()),
        BlocProvider(create: (_) => getIt<BidListFilterCubit>()),
      ],
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

/// Variante de test : `BidBloc` et `BidAcceptanceBloc` doivent être fournis par
/// le contexte parent. `BidListFilterCubit` est créé ici (Cubit déterministe,
/// aucun mock nécessaire). Utilisé uniquement en tests.
@visibleForTesting
class BidListScreenTesting extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final int initialTabIndex;

  const BidListScreenTesting({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => BidListFilterCubit(),
        child: _BidListView(
          announcementId: announcementId,
          departureCityCode: departureCityCode,
          arrivalCityCode: arrivalCityCode,
          departureDate: departureDate,
          initialTabIndex: initialTabIndex,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidListView — StatefulWidget avec TabController
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

  /// Bids en cours d'acceptation (requête en vol) — anti double-tap.
  final _processingBidIds = <String>{};

  /// L'auto-sélection d'onglet ne se fait qu'une fois, au premier chargement.
  bool _didAutoSelectTab = false;

  /// Passe à `true` dès que l'utilisateur change d'onglet.
  bool _userSwitchedTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _userSwitchedTab = true;
      } else {
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

  void _showCardDeclinedSheet(BuildContext context, String message) {
    DonyBottomSheet.show<void>(
      context,
      title: 'Paiement refusé',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DonyColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Changez votre carte de commission pour accepter cette demande.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DonyColors.textMuted),
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
      BuildContext context, acs.BidWalletInsufficient state) {
    DonyBottomSheet.show<void>(
      context,
      title: 'Solde insuffisant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission requise : ${state.requiredCommission.toStringAsFixed(2)} €',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DonyColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Solde wallet : ${state.availableBalance.toStringAsFixed(2)} €',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DonyColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Rechargez votre wallet ou payez la commission directement par carte.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: DonyColors.textMuted),
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
              // /topup/method est le point d'entrée correct (passe extra: méthode à /topup/amount).
              final recharged = await context.push<bool>('/payments/wallet/topup/method');
              if ((recharged ?? false) && context.mounted) {
                context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(state.bidId));
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
                context.read<BidAcceptanceBloc>().add(ace.BidAcceptWithCardRequested(state.bidId));
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

  // ── BLoC listeners ─────────────────────────────────────────────────────────

  void _onCashAcceptanceStateChange(
      BuildContext context, acs.BidAcceptanceState state) {
    if (state is acs.BidAccepted) {
      setState(() => _processingBidIds.clear());
      DonySnackbar.show(context,
          message: 'Demande acceptée !', type: DonySnackbarType.success);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is acs.BidWalletInsufficient) {
      // Ne pas clear _processingBidIds ici — garder le bid « en cours » tant que
      // la sheet est ouverte pour éviter un double-submit si l'user la ferme par
      // l'extérieur et retape Accept. Le clear se fait à la résolution terminale.
      _showWalletInsufficientSheet(context, state);
    } else if (state is acs.BidFailed) {
      setState(() => _processingBidIds.clear());
      if (state.cardDeclined) {
        _showCardDeclinedSheet(context, state.message);
      } else {
        DonySnackbar.show(context,
            message: state.message, type: DonySnackbarType.error);
      }
    }
  }

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
      if (_processingBidIds.isNotEmpty) {
        setState(() => _processingBidIds.clear());
      }
      ErrorPresenter.show(context, state.error);
    }
  }

  /// Bascule sur l'onglet « Acceptées » au premier chargement si « En attente »
  /// est vide et que l'utilisateur n'a pas demandé/choisi un onglet précis.
  void _maybeAutoSelectTab(List<BidModel> pendingBids) {
    if (_didAutoSelectTab) return;
    _didAutoSelectTab = true;
    if (pendingBids.isEmpty &&
        widget.initialTabIndex == 0 &&
        !_userSwitchedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index == 0) {
          _tabController.animateTo(1);
        }
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = _buildSubtitle();

    return BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
      listener: _onCashAcceptanceStateChange,
      child: BlocConsumer<BidBloc, BidState>(
        listener: _onStateChange,
        builder: (context, state) {
          final allBids = state is BidListLoaded ? state.bids : <BidModel>[];
          final pendingBids = allBids
              .where((b) =>
                  b.status == _kPending || b.status == _kPaymentEscrowed)
              .toList();
          final acceptedBids = allBids.where(isAcceptedTabBid).toList();

          if (state is BidListLoaded) {
            _maybeAutoSelectTab(pendingBids);
          }

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
                  child: Icon(Icons.chevron_left_rounded,
                      size: 20, color: cs.primary),
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
                preferredSize: const Size.fromHeight(1 + kTextTabBarHeight),
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
      ),
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
        child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary),
      );
    }

    if (state is BidError) {
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
          // Tab 0 — En attente (avec filtre minBidPriceEur)
          _buildPendingTab(pendingBids),
          // Tab 1 — Acceptées
          _AcceptedTab(acceptedBids: acceptedBids),
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

  // Onglet « En attente » avec filtre minBidPriceEur. Le filtre n'est appliqué
  // que si BusinessPrefsBloc est enregistré (toujours le cas en prod ; absent
  // dans certains widget tests isolés → liste non filtrée).
  Widget _buildPendingTab(List<BidModel> pendingBids) {
    Widget content(BuildContext context, int minPrice) {
      final visibleBids = minPrice == 0
          ? pendingBids
          : pendingBids
              .where((b) => b.pricePerKg == null || b.pricePerKg! >= minPrice)
              .toList();
      final hiddenCount = pendingBids.length - visibleBids.length;
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
              child: _HiddenBidsBanner(
                count: hiddenCount,
                onShowAll: () => getIt<BusinessPrefsBloc>()
                    .add(const MinBidPriceChanged(0)),
              ),
            ),
          Expanded(
            child: _PendingTab(
              bids: visibleBids,
              processingBidIds: _processingBidIds,
              onAccept: (bidId) {
                _addProcessing(bidId);
                final bid = pendingBids.firstWhere((b) => b.id == bidId);
                if (bid.paymentMethod == BidPaymentMethod.cash) {
                  context
                      .read<BidAcceptanceBloc>()
                      .add(ace.BidAcceptRequested(bidId));
                } else {
                  context.read<BidBloc>().add(BidAcceptRequested(bidId));
                }
              },
              onReject: (bidId) => _showRejectDialog(context, bidId),
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
// _PendingTab — onglet « En attente »
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final List<BidModel> bids;
  final Set<String> processingBidIds;
  final void Function(String bidId) onAccept;
  final void Function(String bidId) onReject;

  const _PendingTab({
    required this.bids,
    required this.processingBidIds,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: 'Aucune demande en attente',
        description: 'Partagez votre annonce pour recevoir des demandes.',
      ).animate().fadeIn(duration: 300.ms);
    }

    final hp = DonyLayout.hPadding(context);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hp, DonySpacing.xl, hp, DonySpacing.huge),
      itemCount: bids.length,
      separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.md),
      itemBuilder: (context, i) {
        final bid = bids[i];
        final card = _BidCard(
          bid: bid,
          isProcessing: processingBidIds.contains(bid.id),
          onAccept: () => onAccept(bid.id),
          onReject: () => onReject(bid.id),
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);

        // Swipe-to-delete défensif pour les bids REJECTED (n'apparaissent
        // normalement pas dans cet onglet).
        if (bid.status == _kRejected) {
          return Dismissible(
            key: ValueKey('dismiss_${bid.id}'),
            direction: DismissDirection.endToStart,
            background: const _DismissBackground(),
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
      message:
          'Cette demande refusée sera retirée définitivement de votre liste.',
      confirmLabel: 'Supprimer',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_outline_rounded,
    );
    return confirmed == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AcceptedTab — onglet « Acceptées » : recherche + filtre + liste
// ─────────────────────────────────────────────────────────────────────────────

class _AcceptedTab extends StatefulWidget {
  final List<BidModel> acceptedBids;
  const _AcceptedTab({required this.acceptedBids});

  @override
  State<_AcceptedTab> createState() => _AcceptedTabState();
}

class _AcceptedTabState extends State<_AcceptedTab> {
  /// L'animation en cascade ne se joue qu'au premier affichage de la liste,
  /// jamais à chaque frappe de recherche (sinon scintillement).
  bool _hasAnimatedOnce = false;

  @override
  Widget build(BuildContext context) {
    if (widget.acceptedBids.isEmpty) {
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: 'Aucune demande acceptée',
        description: "Vous n'avez accepté aucune demande pour l'instant.",
      ).animate().fadeIn(duration: 300.ms);
    }

    return BlocBuilder<BidListFilterCubit, BidListFilterState>(
      builder: (context, filter) {
        final queryFiltered = widget.acceptedBids
            .where((b) => bidMatchesQuery(b, filter.query))
            .toList();
        final allCount = queryFiltered.length;
        final activeCount = queryFiltered.where(isActiveBid).length;
        final closedCount = queryFiltered.where(isClosedBid).length;

        List<BidModel> displayed;
        switch (filter.filter) {
          case AcceptedStatusFilter.all:
            displayed = queryFiltered;
          case AcceptedStatusFilter.active:
            displayed = queryFiltered.where(isActiveBid).toList();
          case AcceptedStatusFilter.closed:
            displayed = queryFiltered.where(isClosedBid).toList();
        }
        displayed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final animate = !_hasAnimatedOnce;
        if (animate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _hasAnimatedOnce = true;
          });
        }

        final hp = DonyLayout.hPadding(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(
              hp, DonySpacing.base, hp, DonySpacing.huge),
          children: [
            const _BidSearchField(),
            const SizedBox(height: DonySpacing.md),
            _StatusFilterChips(
              active: filter.filter,
              allCount: allCount,
              activeCount: activeCount,
              closedCount: closedCount,
            ),
            const SizedBox(height: DonySpacing.base),
            if (displayed.isEmpty)
              _SearchEmptyState(query: filter.query)
            else
              for (var i = 0; i < displayed.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        i == displayed.length - 1 ? 0 : DonySpacing.md,
                  ),
                  child: _maybeAnimate(
                    animate,
                    i,
                    _BidCard(
                      bid: displayed[i],
                      isProcessing: false,
                      query: filter.query,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _maybeAnimate(bool animate, int index, Widget card) {
    if (!animate) return card;
    return card
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidSearchField — barre de recherche (nom / n° de suivi)
// ─────────────────────────────────────────────────────────────────────────────

class _BidSearchField extends StatelessWidget {
  const _BidSearchField();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BidListFilterCubit>();
    return DonySearchField(
      hint: 'Nom ou n° de suivi…',
      onChanged: cubit.setQuery,
      onClear: () => cubit.setQuery(''),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusFilterChips — chips Tous / Actifs / Clôturés
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  final AcceptedStatusFilter active;
  final int allCount;
  final int activeCount;
  final int closedCount;

  const _StatusFilterChips({
    required this.active,
    required this.allCount,
    required this.activeCount,
    required this.closedCount,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BidListFilterCubit>();
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: [
        DonyChip(
          label: 'Tous ($allCount)',
          selected: active == AcceptedStatusFilter.all,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.all),
        ),
        DonyChip(
          label: 'Actifs ($activeCount)',
          selected: active == AcceptedStatusFilter.active,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.active),
        ),
        DonyChip(
          label: 'Clôturés ($closedCount)',
          selected: active == AcceptedStatusFilter.closed,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.closed),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchEmptyState — état vide quand recherche/filtre sans résultat
// ─────────────────────────────────────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasQuery = query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxl),
      child: Column(
        children: [
          hasQuery
              ? Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: cs.outlineVariant,
                )
              : const DonyEmoji.parcel(size: 44),
          const SizedBox(height: DonySpacing.md),
          Text(
            hasQuery ? 'Aucun résultat' : 'Aucun envoi',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            hasQuery
                ? 'Aucun envoi ne correspond à « ${query.trim()} ».'
                : 'Aucun envoi dans cette catégorie.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// _BidCard — carte de bid (Option B)
// ─────────────────────────────────────────────────────────────────────────────

class _BidCard extends StatelessWidget {
  final BidModel bid;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  /// Requête de recherche courante — pour le surlignage. Vide hors recherche.
  final String query;

  const _BidCard({
    required this.bid,
    required this.isProcessing,
    this.onAccept,
    this.onReject,
    this.query = '',
  });

  bool get _isPending =>
      bid.status == _kPending || bid.status == _kPaymentEscrowed;
  bool get _isPaymentEscrowed => bid.status == _kPaymentEscrowed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final amount = bid.totalAmountEur != null
        ? '${bid.totalAmountEur!.toStringAsFixed(0)} €'
        : bid.pricePerKg != null
            ? '${((bid.weightKg ?? 0) * bid.pricePerKg!).toStringAsFixed(0)} €'
            : '—';
    final content = bid.contentCategory ?? bid.description;
    final hasTracking =
        bid.trackingNumber != null && bid.trackingNumber!.isNotEmpty;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
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
              // ── Ligne 1 : avatar + identité + montant ──────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyAvatar(name: bid.resolvedSenderName, imageUrl: bid.senderAvatarUrl),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: bid.resolvedSenderName,
                          query: query,
                          style: tt.titleLarge,
                        ),
                        if (hasTracking) ...[
                          const SizedBox(height: DonySpacing.xxs),
                          _HighlightedText(
                            text: 'N° ${bid.trackingNumber}',
                            query: query,
                            style: tt.labelSmall
                                ?.copyWith(color: cs.outlineVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MONTANT',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.outlineVariant),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        amount,
                        style: tt.titleLarge?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              // ── Ligne 2 : pastilles méta ───────────────────────────
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  _MetaPill(
                    icon: Icons.scale_outlined,
                    label: bid.weightKg != null
                        ? '${bid.weightKg!.toStringAsFixed(0)} kg'
                        : bid.pricingMode == BidPricingMode.grid
                            ? 'Forfait'
                            : '—',
                  ),
                  if (content != null && content.isNotEmpty)
                    _MetaPill(
                      iconAsset: 'package',
                      label: content,
                    ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              Divider(color: cs.outline, height: 1),
              const SizedBox(height: DonySpacing.md),

              // ── Bas : actions OU badge de statut ───────────────────
              if (_isPending && onAccept != null && onReject != null) ...[
                if (_isPaymentEscrowed) ...[
                  const _EscrowedHint(),
                  const SizedBox(height: DonySpacing.sm),
                ],
                _PendingActions(
                  isProcessing: isProcessing,
                  onAccept: onAccept!,
                  onReject: onReject!,
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusDot(status: bid.status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HighlightedText — texte avec terme de recherche surligné
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;

  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(query.trim());
    if (q.isEmpty) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    // normalizeSearch préserve la longueur → les index sont valides sur `text`.
    final idx = normalizeSearch(text).indexOf(q);
    if (idx < 0 || idx + q.length > text.length) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    final cs = Theme.of(context).colorScheme;
    final highlight = (style ?? const TextStyle()).copyWith(
      backgroundColor: cs.warningLight,
      color: cs.onSurface,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
              text: text.substring(idx, idx + q.length), style: highlight),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetaPill — pastille discrète (poids, contenu)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;

  const _MetaPill({required this.label, this.icon, this.iconAsset});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconAsset != null
              ? DonyIcon(iconAsset!, size: 13, color: cs.onSurfaceVariant)
              : Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingActions — Refuser + Accepter
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
// _EscrowedHint — bandeau « Paiement reçu » (bids PAYMENT_ESCROWED)
// ─────────────────────────────────────────────────────────────────────────────

class _EscrowedHint extends StatelessWidget {
  const _EscrowedHint();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 14, color: cs.warning),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              '💳 Paiement reçu — en attente de votre réponse',
              style: tt.labelMedium?.copyWith(color: cs.warning),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusDot — badge « point coloré » (statuts post-acceptation)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (Color color, Color bg, String label) = switch (status) {
      'ACCEPTED' => (cs.success, cs.successLight, 'Accepté'),
      'HANDED_OVER' => (cs.primary, cs.primaryContainer, 'En route'),
      'IN_TRANSIT' => (cs.info, cs.infoLight, 'En transit'),
      'COMPLETED' => (cs.success, cs.successLight, 'Livré'),
      'NO_SHOW' => (cs.warning, cs.warningLight, 'Absent'),
      'PARCEL_REFUSED' => (cs.error, cs.errorLight, 'Colis refusé'),
      'CANCELLED' => (
          cs.onSurfaceVariant,
          cs.surfaceContainerHighest,
          'Annulé'
        ),
      _ => (cs.onSurfaceVariant, cs.surfaceContainerHighest, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Text(label, style: tt.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DismissBackground — fond rouge du swipe-to-delete
// ─────────────────────────────────────────────────────────────────────────────

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

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
              color: DonyColors.neutral0, size: 28),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Supprimer',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: DonyColors.neutral0),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScannerChipButton — chip QR scanner dans l'AppBar
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
            Icon(Icons.qr_code_scanner_rounded, size: 16, color: cs.onSurface),
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
// _HiddenBidsBanner — bandeau « n offre(s) masquée(s) » + bouton Voir tout
// ─────────────────────────────────────────────────────────────────────────────

class _HiddenBidsBanner extends StatelessWidget {
  const _HiddenBidsBanner({required this.count, required this.onShowAll});
  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Text(
              '$count offre${count > 1 ? 's' : ''} masquée${count > 1 ? 's' : ''} (prix minimum actif)',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: onShowAll,
            child: const Text('Voir tout'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorView — état d'erreur avec « Réessayer »
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
