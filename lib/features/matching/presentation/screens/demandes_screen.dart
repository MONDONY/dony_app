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
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_list_chrome.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Volet affiché par [DemandesScreen].
enum DemandesTab {
  /// Demandes d'expéditeurs sur mes trajets — je suis transporteur.
  recues,

  /// Demandes d'envoi que j'ai publiées — je suis expéditeur.
  envoyees,
}

/// Écran « Demandes » du hub Activités.
///
/// Réunit les deux sens du marketplace, conformément au modèle double rôle :
/// les demandes reçues sur mes trajets (`GET /travelers/me/bids`, tous trajets
/// confondus, ce qui n'existait pas) et les demandes d'envoi que j'ai publiées
/// — ces dernières venaient de l'onglet « Demandes » de l'écran Envoyer,
/// désormais retiré.
class DemandesScreen extends StatelessWidget {
  const DemandesScreen({super.key, this.initialTab = DemandesTab.recues});

  final DemandesTab initialTab;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<TravelerBidsBloc>()
                ..add(const TravelerBidsRequested(force: true)),
        ),
        BlocProvider(create: (_) => getIt<BidBloc>()),
        BlocProvider(create: (_) => getIt<BidAcceptanceBloc>()),
        BlocProvider.value(
          value: getIt<PackageRequestBloc>()..add(const FetchMyRequests()),
        ),
      ],
      child: _DemandesView(initialTab: initialTab),
    );
  }
}

/// Variante de test : les blocs sont fournis par le contexte parent.
@visibleForTesting
class DemandesScreenTesting extends StatelessWidget {
  const DemandesScreenTesting({
    super.key,
    this.initialTab = DemandesTab.recues,
  });

  final DemandesTab initialTab;

  @override
  Widget build(BuildContext context) => _DemandesView(initialTab: initialTab);
}

class _DemandesView extends StatefulWidget {
  const _DemandesView({required this.initialTab});

  final DemandesTab initialTab;

  @override
  State<_DemandesView> createState() => _DemandesViewState();
}

class _DemandesViewState extends State<_DemandesView> {
  late DemandesTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hp = DonyLayout.hPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: const DonyAppBarBackButton(),
        title: Text('Demandes', style: tt.headlineLarge),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cs.outline, height: 1),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              hp,
              DonySpacing.md,
              hp,
              DonySpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    key: const Key('demandes-tab-recues'),
                    label: 'Reçues',
                    selected: _tab == DemandesTab.recues,
                    onTap: () => setState(() => _tab = DemandesTab.recues),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: _TabButton(
                    key: const Key('demandes-tab-envoyees'),
                    label: 'Envoyées',
                    selected: _tab == DemandesTab.envoyees,
                    onTap: () => setState(() => _tab = DemandesTab.envoyees),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              DemandesTab.recues => const _DemandesRecuesBody(),
              DemandesTab.envoyees => const MyPackageRequestsBody(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Segmented ────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DonyDuration.micro,
        curve: DonyCurve.easeOut,
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: selected ? cs.primary : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Volet « Reçues » ─────────────────────────────────────────────────────────

class _DemandesRecuesBody extends StatefulWidget {
  const _DemandesRecuesBody();

  @override
  State<_DemandesRecuesBody> createState() => _DemandesRecuesBodyState();
}

class _DemandesRecuesBodyState extends State<_DemandesRecuesBody> {
  /// Anti double-tap : bids dont l'acceptation est en vol.
  final _processingBidIds = <String>{};

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<TravelerBidsBloc>().add(
        const TravelerBidsNextPageRequested(),
      );
    }
  }

  void _reload() {
    context.read<TravelerBidsBloc>().add(
      const TravelerBidsRequested(force: true),
    );
  }

  Future<void> _onRefresh() async {
    _reload();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _onAccept(List<BidModel> bids, String bidId) {
    setState(() => _processingBidIds.add(bidId));
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.activitesHubBidAccepted,
      ),
    );
    final bid = bids.firstWhere((b) => b.id == bidId);
    // Le cash passe par le flux commission ; la carte est déjà en séquestre.
    if (bid.paymentMethod == BidPaymentMethod.cash) {
      context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(bidId));
    } else {
      context.read<BidBloc>().add(BidAcceptRequested(bidId));
    }
  }

  Future<void> _onReject(String bidId) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Refuser cette demande ?',
      message: "L'expéditeur sera informé. Cette action est irréversible.",
      confirmLabel: 'Refuser',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed == true && mounted) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.activitesHubBidRejected,
        ),
      );
      context.read<BidBloc>().add(BidRejectRequested(bidId));
    }
  }

  Future<void> _openDetail(BidModel bid) async {
    await context.push('/bids/${bid.id}', extra: bid);
    if (mounted) _reload();
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onBidStateChange(BuildContext context, BidState state) {
    if (state is BidAccepted) {
      setState(() => _processingBidIds.remove(state.bid.id));
      DonySnackbar.show(
        context,
        message: 'Demande acceptée !',
        type: DonySnackbarType.success,
      );
      _reload();
    } else if (state is BidRejected) {
      DonySnackbar.show(context, message: 'Demande refusée.');
      _reload();
    } else if (state is BidError) {
      if (_processingBidIds.isNotEmpty) {
        setState(_processingBidIds.clear);
      }
      ErrorPresenter.show(context, state.error);
    }
  }

  void _onAcceptanceStateChange(
    BuildContext context,
    acs.BidAcceptanceState state,
  ) {
    if (state is acs.BidAccepted) {
      setState(_processingBidIds.clear);
      DonySnackbar.show(
        context,
        message: 'Demande acceptée !',
        type: DonySnackbarType.success,
      );
      _reload();
    } else if (state is acs.BidFailed) {
      setState(_processingBidIds.clear);
      DonySnackbar.show(
        context,
        message: state.message,
        type: DonySnackbarType.error,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
      listener: _onAcceptanceStateChange,
      child: BlocListener<BidBloc, BidState>(
        listener: _onBidStateChange,
        child: BlocBuilder<TravelerBidsBloc, TravelerBidsState>(
          builder: (context, state) => switch (state) {
            TravelerBidsInitial() || TravelerBidsLoading() => Center(
              child: CircularProgressIndicator(color: cs.primary),
            ),
            final TravelerBidsError s => BidListErrorView(
              message: ErrorPresenter.resolve(s.error).message,
              onRetry: _reload,
            ),
            final TravelerBidsLoaded s => _buildLoaded(context, s),
          },
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, TravelerBidsLoaded state) {
    final visible = state.visibleBids;
    final hp = DonyLayout.hPadding(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hp, DonySpacing.sm, hp, DonySpacing.sm),
          child: Row(
            children: [
              for (final f in TravelerBidFilter.values) ...[
                DonyChip(
                  key: Key('demandes-filter-${f.name}'),
                  label: '${f.label} (${state.countFor(f)})',
                  selected: f == state.filter,
                  onTap: () => context.read<TravelerBidsBloc>().add(
                    TravelerBidsFilterChanged(f),
                  ),
                ),
                if (f != TravelerBidFilter.values.last)
                  const SizedBox(width: DonySpacing.sm),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: visible.isEmpty
                ? _EmptyForFilter(filter: state.filter)
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      hp,
                      DonySpacing.md,
                      hp,
                      DonySpacing.huge,
                    ),
                    itemCount: visible.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: DonySpacing.md),
                    itemBuilder: (context, i) {
                      if (i >= visible.length) {
                        return const Padding(
                          padding: EdgeInsets.all(DonySpacing.base),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final bid = visible[i];
                      final canAct = state.filter == TravelerBidFilter.aTraiter;
                      return BidCard(
                        bid: bid,
                        isProcessing: _processingBidIds.contains(bid.id),
                        onAccept: canAct
                            ? () => _onAccept(state.bids, bid.id)
                            : null,
                        onReject: canAct ? () => _onReject(bid.id) : null,
                        onTap: () => _openDetail(bid),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({required this.filter});

  final TravelerBidFilter filter;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (filter) {
      TravelerBidFilter.aTraiter => (
        'Aucune demande à traiter',
        "Publiez un trajet pour recevoir des demandes d'expéditeurs.",
      ),
      TravelerBidFilter.acceptees => (
        'Aucune demande acceptée',
        'Les demandes que vous acceptez apparaîtront ici.',
      ),
      TravelerBidFilter.terminees => (
        'Aucune demande terminée',
        'Vos demandes clôturées seront archivées ici.',
      ),
    };

    // ListView pour que le pull-to-refresh reste possible sur un écran vide.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: DonySpacing.huge),
        DonyEmptyState(
          mascotte: DonyMascotteType.assis,
          title: title,
          description: description,
        ),
      ],
    );
  }
}
