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
  const DemandesScreen({super.key});

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
        // Singleton partagé : le volet « Envoyées » déclenche son propre
        // chargement quand il est réellement affiché.
        BlocProvider.value(value: getIt<PackageRequestBloc>()),
      ],
      child: const _DemandesView(),
    );
  }
}

/// Variante de test : les blocs sont fournis par le contexte parent.
@visibleForTesting
class DemandesScreenTesting extends StatelessWidget {
  const DemandesScreenTesting({super.key});

  @override
  Widget build(BuildContext context) => const _DemandesView();
}

class _DemandesView extends StatefulWidget {
  const _DemandesView();

  @override
  State<_DemandesView> createState() => _DemandesViewState();
}

class _DemandesViewState extends State<_DemandesView> {
  DemandesTab _tab = DemandesTab.recues;

  /// Le volet « Envoyées » est chargé à sa première ouverture : un utilisateur
  /// qui reste sur « Reçues » ne paie pas la requête.
  bool _envoyeesLoaded = false;

  void _selectTab(DemandesTab tab) {
    if (tab == DemandesTab.envoyees && !_envoyeesLoaded) {
      _envoyeesLoaded = true;
      context.read<PackageRequestBloc>().add(const FetchMyRequests());
    }
    setState(() => _tab = tab);
  }

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
            padding: EdgeInsets.fromLTRB(hp, DonySpacing.md, hp, DonySpacing.sm),
            // Le badge « à traiter » du volet Reçues vit sur le toggle : c'est
            // l'information qui décide où l'utilisateur doit aller en premier.
            child: BlocBuilder<TravelerBidsBloc, TravelerBidsState>(
              builder: (context, state) {
                final pending = state is TravelerBidsLoaded
                    ? state.pendingCount
                    : 0;
                return _RoleSegmented(
                  selected: _tab,
                  recuesBadge: pending,
                  onSelect: _selectTab,
                );
              },
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

// ── Segmented control de rôle ─────────────────────────────────────────────────

/// Bascule Reçues / Envoyées : une seule surface connectée avec une capsule
/// qui glisse, plutôt que deux pastilles séparées. Le rôle est le choix le plus
/// structurant de l'écran, il doit se lire comme un vrai contrôle unique.
class _RoleSegmented extends StatelessWidget {
  const _RoleSegmented({
    required this.selected,
    required this.recuesBadge,
    required this.onSelect,
  });

  final DemandesTab selected;
  final int recuesBadge;
  final ValueChanged<DemandesTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: DonyDuration.base,
                curve: DonyCurve.easeOut,
                alignment: selected == DemandesTab.recues
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: segWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    boxShadow: DonyShadows.card,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _RoleSegLabel(
                      key: const Key('demandes-tab-recues'),
                      label: 'Reçues',
                      badge: recuesBadge,
                      selected: selected == DemandesTab.recues,
                      onTap: () => onSelect(DemandesTab.recues),
                    ),
                  ),
                  Expanded(
                    child: _RoleSegLabel(
                      key: const Key('demandes-tab-envoyees'),
                      label: 'Envoyées',
                      badge: 0,
                      selected: selected == DemandesTab.envoyees,
                      onTap: () => onSelect(DemandesTab.envoyees),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleSegLabel extends StatelessWidget {
  const _RoleSegLabel({
    super.key,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (badge > 0) ...[
            const SizedBox(width: DonySpacing.xs),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: tt.labelSmall?.copyWith(
                  color: cs.onError,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
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

  void _onAccept(BidModel bid) {
    setState(() => _processingBidIds.add(bid.id));
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.activitesHubBidAccepted,
      ),
    );
    // Le cash passe par le flux commission ; la carte est déjà en séquestre.
    if (bid.paymentMethod == BidPaymentMethod.cash) {
      context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(bid.id));
    } else {
      context.read<BidBloc>().add(BidAcceptRequested(bid.id));
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

    return MultiBlocListener(
      listeners: [
        BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
          listener: _onAcceptanceStateChange,
        ),
        BlocListener<BidBloc, BidState>(listener: _onBidStateChange),
      ],
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
                            ? () => _onAccept(bid)
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

    // Sur « À traiter », l'écran vide invite à agir plutôt que de rester une
    // impasse ; les autres filtres sont des archives, sans action.
    final showAction = filter == TravelerBidFilter.aTraiter;

    // ListView pour que le pull-to-refresh reste possible sur un écran vide.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: DonySpacing.huge),
        DonyEmptyState(
          mascotte: DonyMascotteType.assis,
          title: title,
          description: description,
          actionLabel: showAction ? 'Publier un trajet' : null,
          onAction: showAction
              ? () {
                  unawaited(
                    getIt<AnalyticsService>().logEvent(
                      AnalyticsEvents.activitesHubTripCreateOpened,
                    ),
                  );
                  context.push('/trips/create');
                }
              : null,
        ),
      ],
    );
  }
}
