import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/search_form_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_period_filter_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ShipmentListScreen extends StatelessWidget {
  const ShipmentListScreen({
    super.key,
    this.embedded = false,
    this.onSwitchToDemandes,
  });

  /// Quand `true`, l'écran omet son header sombre — adapté pour servir de
  /// sous-onglet dans le hub `EnvoyerHubScreen`.
  final bool embedded;

  /// Callback optionnel pour basculer vers l'onglet Demandes depuis l'état
  /// vide (lien secondaire dans l'empty state).
  final VoidCallback? onSwitchToDemandes;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<ShipmentFilterCubit>(),
    child: _ShipmentListContent(
      embedded: embedded,
      onSwitchToDemandes: onSwitchToDemandes,
    ),
  );
}

/// Body extrait pour usage en sous-onglet du hub `EnvoyerHubScreen`.
///
/// Délègue à [ShipmentListScreen] en mode `embedded: true`.
class ShipmentListBody extends StatelessWidget {
  const ShipmentListBody({super.key, this.onSwitchToDemandes});

  /// Callback optionnel pour basculer vers l'onglet Demandes (lien secondaire
  /// dans l'empty state).
  final VoidCallback? onSwitchToDemandes;

  @override
  Widget build(BuildContext context) => ShipmentListScreen(
    embedded: true,
    onSwitchToDemandes: onSwitchToDemandes,
  );
}

class _ShipmentListContent extends StatefulWidget {
  const _ShipmentListContent({
    required this.embedded,
    this.onSwitchToDemandes,
  });
  final bool embedded;
  final VoidCallback? onSwitchToDemandes;
  @override
  State<_ShipmentListContent> createState() => _ShipmentListContentState();
}

class _ShipmentListContentState extends State<_ShipmentListContent> {
  late final EnvoisRefreshNotifier _refreshNotifier;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
    context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
  }

  void _onTabRefreshRequested() {
    if (mounted) {
      context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
    }
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => context.read<ShipmentFilterCubit>().setQuery(q),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _refreshNotifier.removeListener(_onTabRefreshRequested);
    super.dispose();
  }

  void _onBidState(BuildContext context, BidState state) {
    if (state is BidDeleted) {
      DonySnackbar.show(
        context,
        message: 'Envoi supprimé',
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(
        const BidMyListAutoRefreshRequested(force: true),
      );
    } else if (state is BidError) {
      ErrorPresenter.show(context, state.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(listener: _onBidState),
      ],
      child: BlocBuilder<ShipmentFilterCubit, ShipmentFilterState>(
        builder: (context, filter) => BlocBuilder<BidBloc, BidState>(
          builder: (context, bidState) {
            final hasData = bidState is BidListLoaded;
            final rawBids = hasData ? bidState.bids : <BidModel>[];
            final rawEmpty = hasData && rawBids.isEmpty;
            final filtered = hasData
                ? applyShipmentFilters(rawBids, filter, DateTime.now())
                : <BidModel>[];

            Widget body;
            if (!hasData &&
                (bidState is BidLoading || bidState is BidInitial)) {
              body = const _LoadingView();
            } else if (!hasData && bidState is BidError) {
              body = _ErrorView(
                message: ErrorPresenter.resolve(bidState.error).message,
              );
            } else if (rawEmpty) {
              // Raw (unfiltered) list empty → full empty state with CTA
              body = _RawEmptyView(
                onSearchTrip: () async {
                  final params = await SearchFormBottomSheet.show(context);
                  if (params != null && context.mounted) {
                    getIt<PendingSearchNotifier>().setPending(params);
                    context.go('/home');
                  }
                },
                onSwitchToDemandes: widget.onSwitchToDemandes,
              );
            } else if (filtered.isEmpty) {
              body = _FilteredEmptyView(
                onReset: () => context.read<ShipmentFilterCubit>().reset(),
              );
            } else {
              body = _ShipmentListView(
                bids: filtered,
                hPadding: DonyLayout.hPadding(context),
                onRefresh: () async => context.read<BidBloc>().add(
                  const BidMyListAutoRefreshRequested(force: true),
                ),
                onDelete: (bid) =>
                    context.read<BidBloc>().add(BidDeleteRequested(bid.id)),
              );
            }

            if (hasData && bidState.isRefreshing) {
              body = Stack(
                children: [
                  body,
                  LinearProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 2,
                  ),
                ],
              );
            }

            return Scaffold(
              backgroundColor: widget.embedded
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFF2F1EF),
              body: Column(
                children: [
                  if (!widget.embedded)
                    SafeArea(
                      bottom: false,
                      child: _DarkHeader(
                        total: hasData ? rawBids.length : 0,
                      ),
                    ),
                  // Hide filter bar when RAW bid list is empty
                  if (!rawEmpty)
                    _ShipmentFilterBar(
                      controller: _searchController,
                      onQueryChanged: _onQueryChanged,
                      resultCount: filtered.length,
                      hasData: hasData,
                    ),
                  Expanded(child: body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

/// Quick-preset chips for the shipment list.
List<StatusChipData<Set<String>>> _buildChips(ColorScheme cs) => [
  const StatusChipData(label: 'Tous', value: <String>{}),
  StatusChipData(label: 'En transit', value: kEnvoisEnCours, dotColor: cs.info),
  StatusChipData(
    label: 'En attente',
    value: kEnvoisAVenir,
    dotColor: cs.warning,
  ),
  StatusChipData(
    label: 'Livrés',
    value: const {'COMPLETED'},
    dotColor: cs.success,
  ),
];

class _ShipmentFilterBar extends StatelessWidget {
  const _ShipmentFilterBar({
    required this.controller,
    required this.onQueryChanged,
    required this.resultCount,
    required this.hasData,
  });
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final int resultCount;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShipmentFilterCubit>();
    final filter = context.watch<ShipmentFilterCubit>().state;
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        DonySpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonySearchField(
            hint: 'Ville, destinataire, voyageur…',
            controller: controller,
            onChanged: onQueryChanged,
            onClear: () {
              controller.clear();
              cubit.setQuery('');
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          // Status chips + period filter icon
          StatusChipsRow<Set<String>>(
            chips: _buildChips(cs),
            selected: filter.statuses,
            equals: setEquals,
            onSelected: (s) => cubit.applyQuickPreset(s),
            trailing: IconButton(
              icon: Icon(
                Icons.tune_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
              constraints: const BoxConstraints(),
              tooltip: 'Filtrer par période',
              onPressed: () async {
                final r = await ShipmentPeriodFilterSheet.show(
                  context,
                  basis: filter.periodBasis,
                  preset: filter.periodPreset,
                  range: filter.customRange,
                );
                if (r != null && context.mounted) {
                  cubit.setPeriod(
                    basis: r.basis,
                    preset: r.preset,
                    range: r.range,
                  );
                }
              },
            ),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Text(
                  hasData
                      ? '$resultCount résultat${resultCount > 1 ? 's' : ''}'
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    cubit.reset();
                  },
                  child: Text(
                    'Tout effacer',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Dark Header ───────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  const _DarkHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canGoBack = context.canPop();

    return Container(
      color: const Color(0xFF0A2540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xs,
              DonySpacing.sm,
              DonySpacing.base,
              DonySpacing.sm,
            ),
            child: Row(
              children: [
                if (canGoBack)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () => context.pop(),
                  )
                else
                  const SizedBox(width: DonySpacing.base),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Mes envois',
                    style: tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xxs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ShipmentListView extends StatelessWidget {
  final List<BidModel> bids;
  final double hPadding;
  final Future<void> Function()? onRefresh;
  final void Function(BidModel)? onDelete;

  const _ShipmentListView({
    required this.bids,
    required this.hPadding,
    this.onRefresh,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final child = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        hPadding,
        DonySpacing.base,
        hPadding,
        100,
      ),
      itemCount: bids.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: DonySpacing.md);
      },
      itemBuilder: (ctx, i) {
        final bid = bids[i];
        final card = ShipmentCard(
          bid: bid,
          index: i,
          onTap: () async {
            await ctx.push('/bids/${bid.id}', extra: bid);
            if (ctx.mounted) {
              ctx.read<BidBloc>().add(BidMyListRequested());
            }
          },
        );
        if (onDelete == null || !kEnvoisPasses.contains(bid.status)) {
          return card;
        }
        return Dismissible(
          key: ValueKey('dismiss_${bid.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(ctx),
          onDismissed: (_) => onDelete!(bid),
          background: _DeleteBackground(),
          child: card,
        );
      },
    );

    if (onRefresh == null) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final confirmed = await DonyDialog.show(
    context,
    title: 'Supprimer cet envoi ?',
    message:
        'Il sera retiré de votre historique. Cette action est irréversible.',
    confirmLabel: 'Supprimer',
    variant: DonyDialogVariant.destructive,
    icon: Icons.delete_outline_rounded,
  );
  return confirmed == true;
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
          const Icon(
            Icons.delete_outline_rounded,
            color: DonyColors.white,
            size: 26,
          ),
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

// ── Empty / Loading / Error ───────────────────────────────────────────────────

/// Empty state shown when the RAW (unfiltered) bid list is empty.
/// Shows mascotte, primary CTA to search a trip, and a secondary text link
/// to switch to the Demandes tab.
class _RawEmptyView extends StatelessWidget {
  const _RawEmptyView({
    required this.onSearchTrip,
    this.onSwitchToDemandes,
  });

  final VoidCallback onSearchTrip;
  final VoidCallback? onSwitchToDemandes;

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
                children: [
                  DonyEmptyState(
                    title: 'Aucun envoi pour l\'instant',
                    description:
                        'Trouvez un voyageur et envoyez votre colis vers l\'Afrique.',
                    mascotte: DonyMascotteType.assis,
                    actionLabel: 'Rechercher un trajet',
                    onAction: onSearchTrip,
                  ),
                  if (onSwitchToDemandes != null) ...[
                    const SizedBox(height: DonySpacing.base),
                    GestureDetector(
                      onTap: onSwitchToDemandes,
                      child: Text(
                        'ou publie une demande de transport →',
                        style: tt.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: cs.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 40, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucun envoi ne correspond à tes filtres',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              label: 'Réinitialiser',
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
              onPressed: onReset,
            ),
          ],
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
              child: Icon(Icons.wifi_off_rounded, size: 32, color: cs.error),
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
                  horizontal: DonySpacing.lg,
                  vertical: DonySpacing.md,
                ),
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
