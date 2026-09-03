import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart'
    show bidMatchesQuery;
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_list_chrome.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Demandes » du hub Activités.
///
/// Les demandes d'expéditeurs reçues sur mes trajets (`GET /travelers/me/bids`,
/// tous trajets confondus), côté transporteur. Le volet « Envoyées », qui
/// doublait cet écran d'un second rôle, a rejoint l'écran « Mes colis »
/// (`/envois`) aux côtés de la liste d'envois : les deux y parlent du même
/// objet, un colis que j'expédie.
class DemandesScreen extends StatelessWidget {
  const DemandesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Singleton partagé avec le hub et l'onglet Activités : `.value` (ne pas
        // le fermer au pop). On force un chargement à l'ouverture de l'écran.
        BlocProvider.value(
          value: getIt<TravelerBidsBloc>()
            ..add(const TravelerBidsRequested(force: true)),
        ),
        BlocProvider(create: (_) => getIt<BidBloc>()),
        BlocProvider(create: (_) => getIt<BidAcceptanceBloc>()),
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

class _DemandesView extends StatelessWidget {
  const _DemandesView();

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
            child: const ContextualTutorialCard(
              context: TutorialContext.receivedRequests,
            ),
          ),
          // Le décompte « à traiter » vit sur les pastilles de filtre de ce
          // volet ; il n'a plus de toggle où s'afficher, et n'en a plus besoin.
          const Expanded(child: _DemandesRecuesBody()),
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

  /// Recherche par nom d'expéditeur ou numéro de suivi. Filtrage client sur la
  /// liste déjà chargée (toutes les demandes tiennent en mémoire).
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _query = value);
      }
    });
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
    // Pas d'event analytics ici : bid_accepted est tracé dans les blocs au
    // succès réel, pas au tap (un échec réseau ne doit pas compter).
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
      // bid_rejected est tracé dans BidBloc au succès.
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
    } else if (state is acs.BidWalletInsufficient) {
      setState(_processingBidIds.clear);
      _showWalletInsufficientSheet(context, state);
    } else if (state is acs.BidFailed) {
      setState(_processingBidIds.clear);
      DonySnackbar.show(
        context,
        message: state.message,
        type: DonySnackbarType.error,
      );
    }
  }

  /// Solde wallet insuffisant pour la commission d'un accept cash : même
  /// parcours de sortie que sur PendingBidsScreen — recharger, ou payer par
  /// carte si une carte existe, sinon en ajouter une.
  void _showWalletInsufficientSheet(
    BuildContext context,
    acs.BidWalletInsufficient state,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    DonyBottomSheet.show<void>(
      context,
      title: 'Solde insuffisant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission requise : ${formatPriceIn(state.requiredCommission, state.currency)}',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Solde du portefeuille : ${formatPriceIn(state.availableBalance, state.currency)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Rechargez votre portefeuille ou payez la commission directement par carte.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Recharger mon portefeuille',
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
          listener: _onAcceptanceStateChange,
        ),
        BlocListener<BidBloc, BidState>(listener: _onBidStateChange),
      ],
      child: BlocBuilder<TravelerBidsBloc, TravelerBidsState>(
        builder: (context, state) => switch (state) {
          TravelerBidsInitial() || TravelerBidsLoading() => ListView.separated(
            padding: EdgeInsets.fromLTRB(
              DonyLayout.hPadding(context),
              DonySpacing.lg,
              DonyLayout.hPadding(context),
              DonySpacing.huge,
            ),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
            itemBuilder: (_, _) => const DonyUserCardSkeleton(),
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
    final hp = DonyLayout.hPadding(context);
    final searching = _query.trim().isNotEmpty;
    final visible = searching
        ? state.visibleBids
              .where((b) => bidMatchesQuery(b, _query))
              .toList(growable: false)
        : state.visibleBids;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hp, DonySpacing.sm, hp, DonySpacing.sm),
          child: DonySearchField(
            hint: 'Expéditeur, n° de suivi…',
            onChanged: _onQueryChanged,
            onClear: () => setState(() => _query = ''),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hp, 0, hp, DonySpacing.sm),
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
                ? (searching
                      ? const _NoSearchResult()
                      : _EmptyForFilter(filter: state.filter))
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
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: DonySpacing.md),
                    itemBuilder: (context, i) {
                      if (i >= visible.length) {
                        return const DonyUserCardSkeleton();
                      }
                      final bid = visible[i];
                      final canAct = state.filter == TravelerBidFilter.aTraiter;
                      return BidCard(
                        bid: bid,
                        isProcessing: _processingBidIds.contains(bid.id),
                        onAccept: canAct ? () => _onAccept(bid) : null,
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

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult();

  @override
  Widget build(BuildContext context) {
    // ListView pour garder le pull-to-refresh sur un écran sans résultat.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: DonySpacing.huge),
        DonyEmptyState(
          mascotte: DonyMascotteType.assis,
          title: 'Aucun résultat',
          description: 'Aucune demande ne correspond à votre recherche.',
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
