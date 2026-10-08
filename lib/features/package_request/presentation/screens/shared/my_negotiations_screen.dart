import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/widgets/nego_archive_actions.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

class MyNegotiationsScreen extends StatefulWidget {
  const MyNegotiationsScreen({super.key});

  @override
  State<MyNegotiationsScreen> createState() => _MyNegotiationsScreenState();
}

class _MyNegotiationsScreenState extends State<MyNegotiationsScreen> {
  @override
  void initState() {
    super.initState();
    getIt<NegotiationListBloc>().add(const NegotiationListFetchRequested());
    getIt<BidNegotiationListBloc>().add(
      const BidNegotiationListFetchRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Aligné sur la tuile « Discussions de prix » du hub Activités : le
      // libellé tapé doit être celui de l'écran qui s'ouvre. La tuile du hub
      // (activites_hub_screen.dart) n'est pas encore migrée : même texte à
      // reprendre quand elle le sera.
      appBar: DonyAppBar(title: context.l10n.negotiationListTitle),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.sm,
              DonySpacing.base,
              0,
            ),
            child: ContextualTutorialCard(context: TutorialContext.negotiation),
          ),
          Expanded(
            child: MultiBlocProvider(
              providers: [
                BlocProvider<NegotiationListBloc>.value(
                  value: getIt<NegotiationListBloc>(),
                ),
                BlocProvider<BidNegotiationListBloc>.value(
                  value: getIt<BidNegotiationListBloc>(),
                ),
              ],
              child: const MyNegotiationsBody(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Écran des archives ────────────────────────────────────────────────────────

/// Discussions de prix archivées, ouvertes par la ligne « Archivées (n) » en
/// tête de « Discussions de prix » (FLUTTER-FR), comme l'écran d'archives de
/// Messages. Même corps que la liste courante, limité aux archives.
class ArchivedNegotiationsScreen extends StatelessWidget {
  const ArchivedNegotiationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(title: context.l10n.archivedNegotiationsTitle),
      body: MultiBlocProvider(
        providers: [
          BlocProvider<NegotiationListBloc>.value(
            value: getIt<NegotiationListBloc>(),
          ),
          BlocProvider<BidNegotiationListBloc>.value(
            value: getIt<BidNegotiationListBloc>(),
          ),
        ],
        child: const MyNegotiationsBody(archivedOnly: true),
      ),
    );
  }
}

// ── Body avec filtre ──────────────────────────────────────────────────────────

class MyNegotiationsBody extends StatefulWidget {
  const MyNegotiationsBody({super.key, this.archivedOnly = false});

  /// Écran des archives : seules les discussions archivées, sans puces.
  /// Sinon, la liste courante, surmontée de la ligne « Archivées (n) ».
  final bool archivedOnly;
  @override
  State<MyNegotiationsBody> createState() => _MyNegotiationsBodyState();
}

class _MyNegotiationsBodyState extends State<MyNegotiationsBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late final NegotiationFilterCubit _filterCubit;

  @override
  void initState() {
    super.initState();
    _filterCubit = getIt<NegotiationFilterCubit>();
    if (widget.archivedOnly) {
      _filterCubit.setPreset(NegoQuickFilter.archived);
    }
    // Les archives sont lues dès l'ouverture : l'écran courant en affiche le
    // nombre, l'écran d'archives leur contenu. Rechargées à chaque visite, un
    // fil archivé depuis le détail doit y apparaître. Une fois lues, les BLoCs
    // les rechargent eux-mêmes après chaque archivage ou désarchivage, ce qui
    // tient le compteur à jour.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchArchived(context);
    });
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _filterCubit.setQuery(q),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _filterCubit.close();
    super.dispose();
  }

  void _refreshAll(BuildContext context) {
    context.read<NegotiationListBloc>().add(
      const NegotiationListRefreshRequested(),
    );
    context.read<BidNegotiationListBloc>().add(
      const BidNegotiationListRefreshRequested(),
    );
  }

  void _fetchArchived(BuildContext context) {
    context.read<NegotiationListBloc>().add(
      const NegotiationListArchivedFetchRequested(),
    );
    context.read<BidNegotiationListBloc>().add(
      const BidNegotiationListArchivedFetchRequested(),
    );
  }

  void _selectPreset(NegoQuickFilter preset) => _filterCubit.setPreset(preset);

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _filterCubit,
      child: MultiBlocListener(
        listeners: [
          // Échecs d'archivage / suppression lancés depuis la liste. Ceux du
          // détail sont commentés par le détail lui-même.
          BlocListener<NegotiationListBloc, NegotiationListState>(
            listenWhen: (a, b) =>
                b.lastAction != null &&
                a.lastAction != b.lastAction &&
                !b.lastAction!.fromDetail,
            listener: (ctx, state) =>
                showNegoArchiveFailure(ctx, state.lastAction!),
          ),
          BlocListener<BidNegotiationListBloc, BidNegotiationListState>(
            listenWhen: (a, b) =>
                b.lastAction != null &&
                a.lastAction != b.lastAction &&
                !b.lastAction!.fromDetail,
            listener: (ctx, state) =>
                showNegoArchiveFailure(ctx, state.lastAction!),
          ),
        ],
        child: BlocBuilder<NegotiationFilterCubit, NegotiationFilterState>(
          builder: (context, filter) =>
              BlocBuilder<NegotiationListBloc, NegotiationListState>(
                builder: (context, state) =>
                    BlocBuilder<
                      BidNegotiationListBloc,
                      BidNegotiationListState
                    >(
                      builder: (context, tripState) =>
                          _buildContent(context, filter, state, tripState),
                    ),
              ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    NegotiationFilterState filter,
    NegotiationListState state,
    BidNegotiationListState tripState,
  ) {
    final archivedMode = filter.preset == NegoQuickFilter.archived;

    // Les deux sources sont indépendantes : tant que l'une a quelque chose à
    // montrer, l'écran la montre. Chargement, erreur et vide ne concernent
    // donc que le cas où les deux sont muettes.
    final bothEmpty = state.threads.isEmpty && tripState.summaries.isEmpty;
    final anyLoading =
        state.status == NegotiationListStatus.loading ||
        tripState.status == BidNegotiationListStatus.loading;
    final anyError =
        state.status == NegotiationListStatus.error ||
        tripState.status == BidNegotiationListStatus.error;

    if (!archivedMode && bothEmpty && anyLoading) {
      return const _SkeletonList();
    }
    if (!archivedMode && bothEmpty && anyError) {
      return _ErrorState(
        message: _errorText(context, state.errorMessage, tripState),
        onRetry: () => _refreshAll(context),
      );
    }

    final all = <NegoEntry>[
      ...state.threads.map(NegoEntry.fromRequest),
      ...tripState.summaries.map(NegoEntry.fromTrip),
    ];
    final activeCount = all.where((e) => e.isActive).length;
    final terminalCount = all.length - activeCount;

    final Widget list;
    if (archivedMode) {
      list = _buildArchivedList(context, filter, state, tripState);
    } else if (bothEmpty) {
      // Sans action, un compte neuf restait devant un écran inerte : 6 rage
      // clicks PostHog en 13 min le 27/09, juste après une inscription. La
      // ligne « Archivées » reste au-dessus : un fil rangé doit rester
      // atteignable même quand plus rien n'est en cours.
      list = DonyEmptyState(
        title: context.l10n.negotiationEmptyTitle,
        description: context.l10n.negotiationEmptyDescription,
        mascotte: DonyMascotteType.assis,
        actionLabel: context.l10n.negotiationEmptySearchTripAction,
        onAction: () => context.go('/home'),
      );
    } else {
      list = _buildEntries(
        context,
        applyNegotiationFilters(all, filter),
        filter,
        archived: false,
      );
    }

    return Column(
      children: [
        if (!bothEmpty || archivedMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.sm,
              DonySpacing.base,
              0,
            ),
            child: DonySearchField(
              hint: context.l10n.negotiationSearchHint,
              controller: _searchController,
              onChanged: _onQuery,
              onClear: () => _filterCubit.setQuery(''),
            ),
          ),
        if (!widget.archivedOnly) ...[
          _FilterChips(
            preset: filter.preset,
            allCount: all.length,
            activeCount: activeCount,
            terminalCount: terminalCount,
            onSelected: _selectPreset,
          ),
          _archivedRow(context, state, tripState),
        ],
        Expanded(child: list),
      ],
    );
  }

  /// Ligne « Archivées (n) » (FLUTTER-FR), à la place de l'ancienne puce de
  /// filtre. Absente tant qu'il n'y a rien d'archivé.
  Widget _archivedRow(
    BuildContext context,
    NegotiationListState state,
    BidNegotiationListState tripState,
  ) {
    final count =
        state.archivedThreads.length + tripState.archivedSummaries.length;
    if (count == 0) return const SizedBox.shrink();
    final l = context.l10n;
    return DonyArchivedRow(
      key: const Key('nego-archived-row'),
      label: l.archivedRowLabel,
      semanticLabel: l.archivedRowSemantics(count),
      count: count,
      leadingWidth: 24,
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        0,
      ),
      onTap: () => context.push('/negotiations/archives'),
    );
  }

  String _errorText(
    BuildContext context,
    Object? requestError,
    BidNegotiationListState tripState,
  ) {
    final errorObj = requestError ?? tripState.errorMessage;
    return errorObj != null
        ? ErrorPresenter.resolve(errorObj, l10n: context.l10n).message
        : context.l10n.requestListErrorFallback;
  }

  Widget _buildArchivedList(
    BuildContext context,
    NegotiationFilterState filter,
    NegotiationListState state,
    BidNegotiationListState tripState,
  ) {
    final entries = <NegoEntry>[
      ...state.archivedThreads.map(NegoEntry.fromRequest),
      ...tripState.archivedSummaries.map(NegoEntry.fromTrip),
    ];
    final loading =
        state.archivedStatus == NegotiationListStatus.loading ||
        tripState.archivedStatus == BidNegotiationListStatus.loading;
    final error =
        state.archivedStatus == NegotiationListStatus.error ||
        tripState.archivedStatus == BidNegotiationListStatus.error;
    if (entries.isEmpty && loading) {
      return const _SkeletonList();
    }
    if (entries.isEmpty && error) {
      return _ErrorState(
        message: _errorText(context, state.errorMessage, tripState),
        onRetry: () => _fetchArchived(context),
      );
    }
    return _buildEntries(
      context,
      applyNegotiationFilters(entries, filter),
      filter,
      archived: true,
    );
  }

  Widget _buildEntries(
    BuildContext context,
    List<NegoEntry> filtered,
    NegotiationFilterState filter, {
    required bool archived,
  }) {
    if (filtered.isEmpty) {
      return _FilterEmptyState(
        preset: filter.preset,
        hasQuery: filter.query.isNotEmpty,
      );
    }
    return RefreshIndicator(
      color: DonyColors.primary,
      onRefresh: () async =>
          archived ? _fetchArchived(context) : _refreshAll(context),
      child: SlidableAutoCloseBehavior(
        child: ListView.separated(
          // Faire défiler la liste ferme le clavier de la recherche
          // (FLUTTER-CQ).
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.sm,
            DonySpacing.base,
            MediaQuery.of(context).padding.bottom + 100,
          ),
          itemCount: filtered.length,
          separatorBuilder: (_, i) => const SizedBox(height: DonySpacing.sm),
          itemBuilder: (_, i) => switch (filtered[i]) {
            final RequestNegoEntry e => _ArchivableTile(
              key: ValueKey('req-${e.thread.id}'),
              id: e.thread.id,
              kind: NegoEntryKind.request,
              finished: !e.isActive,
              archived: archived,
              child: _NegoCard(thread: e.thread, index: i),
            ),
            final TripNegoEntry e => _ArchivableTile(
              key: ValueKey('trip-${e.summary.bidId}'),
              id: e.summary.bidId,
              kind: NegoEntryKind.trip,
              finished: !e.isActive,
              archived: archived,
              child: _TripNegoCard(
                summary: e.summary,
                index: i,
                archived: archived,
              ),
            ),
          },
        ),
      ),
    );
  }
}

// ── Liste squelette ───────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
      itemBuilder: (_, _) => const DonyUserCardSkeleton(),
    );
  }
}

// ── Puces de filtre ───────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.preset,
    required this.allCount,
    required this.activeCount,
    required this.terminalCount,
    required this.onSelected,
  });

  final NegoQuickFilter preset;
  final int allCount;
  final int activeCount;
  final int terminalCount;
  final ValueChanged<NegoQuickFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chips = <(NegoQuickFilter, String)>[
      (NegoQuickFilter.all, l.negotiationFilterAllCountLabel(allCount)),
      (
        NegoQuickFilter.active,
        l.negotiationFilterActiveCountLabel(activeCount),
      ),
      (
        NegoQuickFilter.terminal,
        l.negotiationFilterTerminalCountLabel(terminalCount),
      ),
    ];
    // Les archives ont quitté les puces pour la ligne « Archivées (n) »
    // (FLUTTER-FR). La rangée défile toujours plutôt que de tronquer un
    // libellé sur un petit écran.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.xs,
      ),
      child: Row(
        children: [
          for (final (i, (value, label)) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: DonySpacing.xs + 2),
            _FilterChip(
              key: Key('nego-filter-${value.name}'),
              label: label,
              active: preset == value,
              onTap: () => onSelected(value),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tuile archivable ──────────────────────────────────────────────────────────

/// Balayage Archiver / Supprimer d'une discussion terminée, repris des
/// conversations de Messages (`conversation_list_screen.dart`). Sous le filtre
/// « Archivées », la seule action est « Désarchiver ». Une discussion en cours
/// n'a aucune action : le serveur la refuserait (409).
class _ArchivableTile extends StatelessWidget {
  const _ArchivableTile({
    super.key,
    required this.id,
    required this.kind,
    required this.finished,
    required this.archived,
    required this.child,
  });

  final String id;
  final NegoEntryKind kind;
  final bool finished;
  final bool archived;
  final Widget child;

  void _dispatch(BuildContext context, NegoArchiveAction action) {
    if (kind == NegoEntryKind.request) {
      context.read<NegotiationListBloc>().add(
        NegotiationArchiveActionRequested(id, action),
      );
    } else {
      context.read<BidNegotiationListBloc>().add(
        BidNegotiationArchiveActionRequested(id, action),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!finished) {
      return child;
    }
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    final actions = archived
        ? [
            DonySwipeAction(
              key: const Key('nego-slide-unarchive'),
              onPressed: (ctx) {
                _dispatch(ctx, NegoArchiveAction.unarchive);
                DonySnackbar.show(
                  ctx,
                  message: l.negotiationUnarchivedSnackbar,
                );
              },
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              icon: Icons.unarchive_outlined,
              label: l.negotiationUnarchiveAction,
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
          ]
        : [
            DonySwipeAction(
              key: const Key('nego-slide-archive'),
              onPressed: (ctx) {
                // Capturer les BLoCs avant tout : le volet se referme au tap
                // et démonte ctx.
                final requests = ctx.read<NegotiationListBloc>();
                final trips = ctx.read<BidNegotiationListBloc>();
                _dispatch(ctx, NegoArchiveAction.archive);
                DonySnackbar.show(
                  ctx,
                  message: l.negotiationArchivedSnackbar,
                  actionLabel: l.commonCancel,
                  onAction: () => kind == NegoEntryKind.request
                      ? requests.add(
                          NegotiationArchiveActionRequested(
                            id,
                            NegoArchiveAction.unarchive,
                          ),
                        )
                      : trips.add(
                          BidNegotiationArchiveActionRequested(
                            id,
                            NegoArchiveAction.unarchive,
                          ),
                        ),
                );
              },
              backgroundColor: cs.warning,
              foregroundColor: cs.onPrimary,
              icon: Icons.archive_outlined,
              label: l.negotiationArchiveAction,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(DonyRadius.card),
              ),
            ),
            DonySwipeAction(
              key: const Key('nego-slide-delete'),
              onPressed: (ctx) {
                // Capturer les BLoCs avant la feuille : le volet Slidable se
                // referme au tap (autoClose) et démonte ctx pendant qu'elle
                // est ouverte.
                final requests = ctx.read<NegotiationListBloc>();
                final trips = ctx.read<BidNegotiationListBloc>();
                confirmDeleteNegotiation(ctx).then((confirmed) {
                  if (!confirmed) return;
                  if (kind == NegoEntryKind.request) {
                    requests.add(
                      NegotiationArchiveActionRequested(
                        id,
                        NegoArchiveAction.delete,
                      ),
                    );
                  } else {
                    trips.add(
                      BidNegotiationArchiveActionRequested(
                        id,
                        NegoArchiveAction.delete,
                      ),
                    );
                  }
                });
              },
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              icon: Icons.delete_outline_rounded,
              label: l.commonDelete,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(DonyRadius.card),
              ),
            ),
          ];

    return Slidable(
      key: ValueKey('slidable-$id'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        // 0.55 tronquait « Archiver » et « Supprimer » (FLUTTER-FR) : la
        // largeur couvre les deux libellés en entier, en français et en anglais.
        extentRatio: archived ? 0.35 : 0.62,
        children: actions,
      ),
      child: child,
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md + 2,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: active ? DonyColors.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: active ? DonyColors.primary : cs.outline,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : cs.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ── Filter empty ──────────────────────────────────────────────────────────────

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.preset, required this.hasQuery});
  final NegoQuickFilter preset;
  final bool hasQuery;

  String _msg(AppLocalizations l) {
    if (hasQuery) {
      return l.requestListEmptySearchResult;
    }
    return switch (preset) {
      NegoQuickFilter.active => l.negotiationEmptyActiveFilter,
      NegoQuickFilter.terminal => l.negotiationEmptyTerminalFilter,
      NegoQuickFilter.archived => l.negotiationEmptyArchivedFilter,
      NegoQuickFilter.all => l.negotiationEmptyTitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyEmoji.parcel(size: 48),
            const SizedBox(height: DonySpacing.sm + 4),
            Text(
              _msg(context.l10n),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nego Card — Proposition A (Route First) ───────────────────────────────────

class _NegoCard extends StatelessWidget {
  const _NegoCard({required this.thread, required this.index});
  final NegotiationThread thread;
  final int index;

  bool get _isNew =>
      thread.status == NegotiationThreadStatus.open &&
      thread.messages.isNotEmpty;

  /// Un fil est terminal quand il n'est plus actif sans avoir abouti. Dérivé de
  /// `isActive`, qui fait autorité sur les statuts en cours : réénumérer les
  /// statuts morts ici les ferait diverger au prochain ajout côté serveur.
  bool get _isTerminal =>
      !thread.status.isActive &&
      thread.status != NegotiationThreadStatus.accepted;

  Color get _stripColor => switch (thread.status) {
    NegotiationThreadStatus.open => DonyColors.primary,
    NegotiationThreadStatus.awaitingTrip => DonyColors.threadStatusAmber,
    NegotiationThreadStatus.awaitingPayment ||
    NegotiationThreadStatus.awaitingDeposit => DonyColors.threadStatusViolet,
    NegotiationThreadStatus.awaitingCommission => DonyColors.threadStatusOrange,
    NegotiationThreadStatus.accepted => DonyColors.threadStatusGreen,
    _ => DonyColors.neutral300,
  };

  String _priceLabel(AppLocalizations l) => switch (thread.status) {
    NegotiationThreadStatus.open => l.negotiationStageProposal,
    NegotiationThreadStatus.awaitingTrip => l.negotiationStageDealPending,
    NegotiationThreadStatus.awaitingPayment => l.negotiationStageToPay,
    NegotiationThreadStatus.awaitingDeposit =>
      l.negotiationStageDepositInProgress,
    NegotiationThreadStatus.awaitingCommission =>
      l.negotiationStageCommissionDue,
    NegotiationThreadStatus.accepted => l.negotiationStagePaid,
    _ => l.negotiationStageClosed,
  };

  String _buildRoute(AppLocalizations l) {
    final dep = thread.departureCity;
    final arr = thread.arrivalCity;
    if (dep != null && arr != null) {
      return '$dep → $arr';
    }
    return thread.isTravelerKgFree
        ? l.tripKgFree
        : l.negotiationLinkTripKgAvailable(
            thread.travelerAvailableKg.toStringAsFixed(0),
          );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final name =
        thread.travelerName ??
        l.negotiationTravelerFallbackWithId(thread.travelerId.substring(0, 4));
    final rounds = thread.roundsCount.clamp(0, 5);

    // L'expéditeur voit TOUJOURS le prix qu'il paie (net + commission = gross),
    // cash comme stripe ; le voyageur voit son net.
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : authState is AuthProfileUpdated
        ? authState.user.id
        : '';
    final isTraveler = currentUserId == thread.travelerId;
    final displayPrice = isTraveler
        ? thread.currentPriceEur
        : (thread.grossPriceEur ??
              PriceDisplay.grossFromNet(thread.currentPriceEur));

    return _NegoCardShell(
      stripColor: _stripColor,
      dimmed: _isTerminal,
      highlighted: _isNew,
      index: index,
      onTap: () => context.push('/negotiations/${thread.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : route + prix
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _buildRoute(l),
                  style: tt.titleLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _isTerminal ? cs.onSurfaceVariant : cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PriceDisplay.money(displayPrice, thread.currency),
                    style: tt.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _isTerminal ? cs.onSurfaceVariant : cs.onSurface,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    _priceLabel(l),
                    style: tt.bodySmall?.copyWith(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Ligne 2 : avatar + nom + badge statut
          Row(
            children: [
              DonyAvatar(
                name: name,
                imageUrl: thread.travelerPhotoUrl,
                size: DonyAvatarSize.sm,
                verified: (thread.travelerTripsCount ?? 0) > 0,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const _SourcePill(kind: NegoEntryKind.request),
              const SizedBox(width: 4),
              _StatusPill(
                variant: ThreadStatusVariant.fromThread(thread.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Ligne 3 : round dots + méta + badge NOUVEAU
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Container(
                  width: 16,
                  height: 3,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < rounds
                        ? (_isTerminal ? DonyColors.neutral300 : cs.onSurface)
                        : cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  l.negotiationCardRoundShortLabel(
                    thread.roundsCount,
                    _timeAgo(l, thread.lastActivityAt),
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_isNew)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DonyColors.primary,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    l.negotiationMessageNewBadge,
                    style: tt.bodySmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Carte d'une négociation de prix de trajet ────────────────────────────────

/// Pendant de [_NegoCard] pour les fils de trajet.
///
/// Même lecture que la carte d'une demande (FLUTTER-BM) : bande et pastille de
/// statut, montant mis en avant, interlocuteur, tour en cours et qui doit
/// jouer. Le résumé ne porte ni le plafond de tours ni le détail du paiement :
/// la carte s'en tient à ce qu'il dit.
class _TripNegoCard extends StatelessWidget {
  const _TripNegoCard({
    required this.summary,
    required this.index,
    this.archived = false,
  });

  final BidNegotiationSummary summary;
  final int index;

  /// Ouvert depuis « Archivées » : le détail de trajet ne dit pas s'il est
  /// archivé, la route le lui transmet pour proposer « Désarchiver ».
  final bool archived;

  /// Le résumé ne porte que le brut. L'afficher au voyageur lui montrerait un
  /// montant qui n'est pas le sien : côté voyageur, le chiffre attend le fil.
  bool get _showsAmount => summary.role != 'TRAVELER';

  bool get _negotiating => summary.status == 'NEGOTIATING';

  /// La main est à moi : répondre en pleine discussion, ou payer un accord.
  bool get _actionRequired =>
      (_negotiating && summary.myTurn) || summary.needsMyPayment;

  ThreadStatusVariant get _variant => switch (summary.status) {
    'NEGOTIATING' => ThreadStatusVariant.open,
    'AWAITING_PAYMENT' => ThreadStatusVariant.awaitingPayment,
    'PENDING' => ThreadStatusVariant.awaitingCommission,
    'ACCEPTED' => ThreadStatusVariant.accepted,
    _ => ThreadStatusVariant.terminal,
  };

  /// Mêmes couleurs que la bande de [_NegoCard], variante par variante.
  Color get _stripColor => switch (_variant) {
    ThreadStatusVariant.open => DonyColors.primary,
    ThreadStatusVariant.awaitingTrip => DonyColors.threadStatusAmber,
    ThreadStatusVariant.awaitingPayment ||
    ThreadStatusVariant.awaitingDeposit => DonyColors.threadStatusViolet,
    ThreadStatusVariant.awaitingCommission => DonyColors.threadStatusOrange,
    ThreadStatusVariant.accepted => DonyColors.threadStatusGreen,
    ThreadStatusVariant.terminal => DonyColors.neutral300,
  };

  String _route(AppLocalizations l) {
    final dep = summary.departureCity;
    final arr = summary.arrivalCity;
    if (dep != null && arr != null) return '$dep → $arr';
    return l.requestCreateRecapTrip;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final isTerminal = summary.isClosed;
    final name =
        summary.counterpartyName ?? l.negotiationTripCardCounterpartyFallback;

    return _NegoCardShell(
      key: Key('trip-nego-card-${summary.bidId}'),
      stripColor: _stripColor,
      dimmed: isTerminal,
      highlighted: summary.hasUnread || _actionRequired,
      index: index,
      onTap: () => context.push(
        archived
            ? '/bids/${summary.bidId}/negotiation?archived=true'
            : '/bids/${summary.bidId}/negotiation',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : route + montant
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _route(l),
                  style: tt.titleLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isTerminal ? cs.onSurfaceVariant : cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_showsAmount)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PriceDisplay.money(
                        summary.proposedGrossEur,
                        summary.currency,
                      ),
                      key: Key('trip-nego-amount-${summary.bidId}'),
                      style: tt.headlineMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isTerminal
                            ? cs.onSurfaceVariant
                            : _actionRequired
                            ? cs.primary
                            : cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      summary.stageLabel(context.l10n),
                      style: tt.bodySmall?.copyWith(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Ligne 2 : interlocuteur + source + statut
          Row(
            children: [
              DonyAvatar(name: name, size: DonyAvatarSize.sm),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const _SourcePill(kind: NegoEntryKind.trip),
              const SizedBox(width: 4),
              _StatusPill(variant: _variant),
            ],
          ),
          const SizedBox(height: 6),
          // Ligne 3 : qui doit jouer + tour + badge NOUVEAU
          Row(
            children: [
              if (_negotiating) ...[
                _TurnChip(
                  myTurn: summary.myTurn,
                  label: summary.myTurn
                      ? l.negotiationThreadYourTurn
                      : l.negotiationThreadTheirTurn(name),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  l.negotiationTripCardRoundLabel(
                    summary.round,
                    _timeAgo(l, summary.updatedAt ?? DateTime.now()),
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (summary.hasUnread)
                Container(
                  key: Key('trip-nego-new-${summary.bidId}'),
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DonyColors.primary,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    l.negotiationMessageNewBadge,
                    style: tt.bodySmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « À vous de jouer » / « Au tour de … » sur une carte de trajet. Plein et
/// accentué quand la main est à l'utilisateur, discret sinon.
class _TurnChip extends StatelessWidget {
  const _TurnChip({required this.myTurn, required this.label});

  final bool myTurn;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = myTurn ? cs.primary : cs.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: myTurn
              ? cs.primary.withValues(alpha: 0.10)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chassis commun aux deux cartes ───────────────────────────────────────────

/// Enveloppe partagee par [_NegoCard] et [_TripNegoCard].
///
/// Les deux cartes n affichent pas la meme chose, mais elles sont le meme
/// objet a l ecran : meme bordure, meme bande de statut a gauche, meme
/// estompage une fois le fil termine, meme entree en cascade. Ecrite deux
/// fois, cette identite se serait defaite au premier reglage applique d un
/// seul cote.
class _NegoCardShell extends StatelessWidget {
  const _NegoCardShell({
    super.key,
    required this.stripColor,
    required this.dimmed,
    required this.highlighted,
    required this.onTap,
    required this.index,
    required this.child,
  });

  /// Bande verticale de gauche : la couleur porte le statut du fil.
  final Color stripColor;

  /// Fil termine : la carte reste lisible mais recule.
  final bool dimmed;

  /// Fil qui reclame l attention (non lu, offre fraiche) : bordure accentuee.
  final bool highlighted;

  final VoidCallback onTap;

  /// Rang dans la liste, pour l entree en cascade.
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Opacity(
          opacity: dimmed ? 0.65 : 1.0,
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              onTap: onTap,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(
                    color: highlighted
                        ? DonyColors.primary.withValues(alpha: 0.30)
                        : cs.outline,
                    width: highlighted ? 1.5 : 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Bande colorée gauche via Positioned (hauteur automatique)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 4, color: stripColor),
                    ),
                    // Contenu — padding gauche 16 = 4 (strip) + 12 (espacement)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 220.ms, delay: (50 * index).ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── Marqueur de source ───────────────────────────────────────────────────────

/// Distingue les deux natures de discussion mélangées dans la même liste :
/// sans lui, une carte « Paris → Dakar » ne dit pas si l'on négocie sa demande
/// d'envoi ou le prix d'un trajet.
class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.kind});

  final NegoEntryKind kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final isTrip = kind == NegoEntryKind.trip;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        isTrip ? l.requestCreateRecapTrip : l.negotiationSourcePillRequest,
        style: tt.bodySmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

/// Pastille de statut, partagée par les cartes « demande » et « trajet » :
/// elle se lit sur la variante visuelle du fil, pas sur un statut serveur,
/// pour que les deux natures de discussion portent les mêmes couleurs.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.variant});
  final ThreadStatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (variant) {
      ThreadStatusVariant.open => (DonyColors.primary, const Color(0xFFEEF3FF)),
      ThreadStatusVariant.awaitingTrip => (
        DonyColors.threadPillAmberFg,
        const Color(0xFFFEF3C7),
      ),
      // Dépôt mobile money en cours : même violet que le paiement, dont il
      // est une étape.
      ThreadStatusVariant.awaitingPayment ||
      ThreadStatusVariant.awaitingDeposit => (
        DonyColors.threadStatusViolet,
        const Color(0xFFF5F3FF),
      ),
      ThreadStatusVariant.awaitingCommission => (
        DonyColors.threadPillOrangeFg,
        const Color(0xFFFFEDD5),
      ),
      ThreadStatusVariant.accepted => (
        DonyColors.threadStatusGreen,
        const Color(0xFFDCFCE7),
      ),
      ThreadStatusVariant.terminal => (
        DonyColors.threadPillNeutralFg,
        const Color(0xFFF3F4F6),
      ),
    };
    // Même texte, même clé que la pastille du hero card (ThreadHeroCard).
    final label = variant.badge(context.l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl + 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DonyIcon(
              'circle-alert',
              size: 48,
              color: DonyColors.danger500,
            ),
            const SizedBox(height: DonySpacing.sm + 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Même mise en forme que `my_package_requests_screen.dart` (clés
/// `requestListTime…`), reprise ici en privé faute d'un point d'entrée
/// partagé : les deux écrans affichent le même « il y a N » relatif.
String _timeAgo(AppLocalizations l, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) {
    return l.requestListTimeJustNow;
  }
  if (diff.inMinutes < 60) {
    return l.requestListTimeMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l.requestListTimeHoursAgo(diff.inHours);
  }
  return l.requestListTimeDaysAgo(diff.inDays);
}
