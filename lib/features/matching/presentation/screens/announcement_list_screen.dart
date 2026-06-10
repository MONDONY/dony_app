import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ── Status sort priority ──────────────────────────────────────────────────────

int _statusPriority(String status) => switch (status) {
      'IN_PROGRESS' => 0,
      'ACTIVE' => 1,
      'FULL' => 2,
      'COMPLETED' => 3,
      'CANCELLED' => 4,
      _ => 5,
    };

// ── Chip counts ───────────────────────────────────────────────────────────────

({int all, int active, int completed, int cancelled}) _counts(
    List<AnnouncementModel> list) {
  int a = 0, c = 0, x = 0;
  for (final item in list) {
    if (item.status == 'ACTIVE' ||
        item.status == 'FULL' ||
        item.status == 'IN_PROGRESS') {
      a++;
    } else if (item.status == 'COMPLETED') {
      c++;
    } else if (item.status == 'CANCELLED') {
      x++;
    }
  }
  return (all: list.length, active: a, completed: c, cancelled: x);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({
    super.key,
    this.onSendParcel,
    this.showBackButton = false,
  });

  /// Si non nul, un bouton secondaire « Envoyer » apparaît dans l'en-tête,
  /// permettant au voyageur PRO d'accéder au flux expéditeur depuis Mes Trajets
  /// (modèle additif Phase 1).
  final VoidCallback? onSendParcel;

  /// Affiche un bouton retour dans l'en-tête quand l'écran est ouvert via
  /// `context.push` (depuis le hub Envoyer), et non comme racine d'onglet.
  final bool showBackButton;

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<AnnouncementModel> _lastList = [];
  bool _tickerWasActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.valuesOf(context).enabled;
    if (isActive && !_tickerWasActive) {
      context.read<AnnouncementBloc>().add(AnnouncementListRequested());
      context.read<TripsSummaryCubit>().load();
    }
    _tickerWasActive = isActive;
  }

  Future<bool?> _confirmDeleteDialog(BuildContext ctx) {
    return DonyDialog.show(
      ctx,
      title: 'Supprimer ce trajet ?',
      message:
          'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.',
      confirmLabel: 'Supprimer',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_outline_rounded,
    );
  }

  /// Returns the filtered + sorted list from _lastList.
  List<AnnouncementModel> _filtered(TripFilterState filter) {
    return _lastList
        .where((a) =>
            filter.matchesStatus(a.status) &&
            filter.matchesQuery(a.departureCity, a.arrivalCity))
        .toList()
      ..sort((a, b) {
        final pCmp =
            _statusPriority(a.status).compareTo(_statusPriority(b.status));
        if (pCmp != 0) {
          return pCmp;
        }
        return a.departureDate.compareTo(b.departureDate);
      });
  }

  Future<void> _createTrip() async {
    await CreateAnnouncementBottomSheet.show(context);
    if (!mounted) {
      return;
    }
    context.read<AnnouncementBloc>().add(AnnouncementListRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hPad = DonyLayout.hPadding(context);

    return Scaffold(
      // ── Permanent header: title + action pills ──────────────────────────
      appBar: _HeaderBar(
        onSendParcel: widget.onSendParcel,
        onCreateTrip: _createTrip,
        showBackButton: widget.showBackButton,
        hPad: hPad,
        tt: tt,
        cs: cs,
      ),
      // ── Content ─────────────────────────────────────────────────────────
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementDeleted) {
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          } else if (state is AnnouncementError && _lastList.isNotEmpty) {
            ErrorPresenter.show(context, state.error);
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          }
        },
        builder: (context, state) {
          if (state is AnnouncementListLoaded) {
            _lastList = state.announcements;
          }

          // ── Full-screen loading / error ───────────────────────────────────
          if ((state is AnnouncementLoading || state is AnnouncementInitial) &&
              _lastList.isEmpty) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (state is AnnouncementError && _lastList.isEmpty) {
            return _ErrorView(
                message: ErrorPresenter.resolve(state.error).message);
          }

          final counts = _counts(_lastList);

          return BlocBuilder<TripFilterCubit, TripFilterState>(
            builder: (context, filterState) {
              final filtered = _filtered(filterState);
              final chips = _buildChips(counts, cs, filterState.filter);

              return RefreshIndicator(
                color: cs.primary,
                onRefresh: () async {
                  final bloc = context.read<AnnouncementBloc>();
                  bloc.add(AnnouncementListRequested());
                  unawaited(context.read<TripsSummaryCubit>().load());
                  // Garde le spinner actif jusqu'au rechargement réel de la
                  // liste (sinon il disparaît avant l'arrivée des données).
                  await bloc.stream.firstWhere(
                    (s) =>
                        s is AnnouncementListLoaded || s is AnnouncementError,
                  );
                },
                child: CustomScrollView(
                  slivers: [
                    // ── Stats strip ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
                        builder: (context, summaryState) {
                          if (summaryState.status ==
                              TripsSummaryStatus.loaded) {
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                  hPad, DonySpacing.lg, hPad, 0),
                              child: TripsStatsStrip(
                                  summary: summaryState.summary!),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),

                    // ── Search + Chips (masked when list is empty) ──────────
                    if (_lastList.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, DonySpacing.lg, hPad, 0),
                          child: ActivitySearchField(
                            hint: 'Rechercher une destination…',
                            onChanged: (v) =>
                                context.read<TripFilterCubit>().setQuery(v),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, DonySpacing.md, hPad, 0),
                          child: StatusChipsRow<TripStatusFilter>(
                            chips: chips,
                            selected: filterState.filter,
                            onSelected: (value) {
                              if (value != filterState.filter) {
                                context
                                    .read<TripFilterCubit>()
                                    .setFilter(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],

                    // ── List or empty state ─────────────────────────────────
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyView(
                          rawListEmpty: _lastList.isEmpty,
                          activeFilter: filterState.filter,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          DonySpacing.lg,
                          hPad,
                          100 + MediaQuery.paddingOf(context).bottom,
                        ),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, idx) =>
                              const SizedBox(height: DonySpacing.md),
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            final isCancelled = item.status == 'CANCELLED';

                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: isCancelled
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              confirmDismiss: isCancelled
                                  ? (_) => _confirmDeleteDialog(context)
                                  : null,
                              onDismissed: (_) {
                                context
                                    .read<AnnouncementBloc>()
                                    .add(AnnouncementDeleteRequested(item.id));
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(
                                    right: DonySpacing.xl),
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.card),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_rounded,
                                        color: cs.onError, size: 26),
                                    const SizedBox(height: DonySpacing.xs),
                                    Text(
                                      'Supprimer',
                                      style: tt.labelMedium?.copyWith(
                                        color: cs.onError,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              child: TripCard(
                                key: ValueKey(item.id),
                                announcement: item,
                                index: i,
                                onTap: () async {
                                  await AnnouncementDetailBottomSheet.show(
                                      context,
                                      announcementId: item.id);
                                  if (context.mounted) {
                                    context
                                        .read<AnnouncementBloc>()
                                        .add(AnnouncementListRequested());
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<StatusChipData<TripStatusFilter>> _buildChips(
    ({int all, int active, int completed, int cancelled}) counts,
    ColorScheme cs,
    TripStatusFilter currentFilter,
  ) {
    return [
      StatusChipData(
        label: 'Tous',
        value: TripStatusFilter.all,
        count: counts.all,
      ),
      StatusChipData(
        label: 'Actifs',
        value: TripStatusFilter.active,
        count: counts.active,
        dotColor: cs.success,
      ),
      StatusChipData(
        label: 'Terminés',
        value: TripStatusFilter.completed,
        count: counts.completed,
        dotColor: DonyColors.neutral400,
      ),
      if (counts.cancelled > 0)
        StatusChipData(
          label: 'Annulés',
          value: TripStatusFilter.cancelled,
          count: counts.cancelled,
          dotColor: cs.error,
        ),
    ];
  }
}

// ── Header AppBar (title + action pills) ──────────────────────────────────────

class _HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const _HeaderBar({
    required this.onSendParcel,
    required this.onCreateTrip,
    required this.showBackButton,
    required this.hPad,
    required this.tt,
    required this.cs,
  });

  final VoidCallback? onSendParcel;
  final VoidCallback onCreateTrip;
  final bool showBackButton;
  final double hPad;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showBackButton)
                          IconButton(
                            key: const Key('activites-back'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: cs.primary,
                            ),
                            tooltip: 'Retour',
                            onPressed: () => context.pop(),
                          ),
                        Text(
                          'Mes trajets',
                          style: tt.displaySmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onSendParcel != null) ...[
                          HeaderPill(
                            key: const Key('send-parcel-btn'),
                            label: 'Envoyer',
                            icon: Icons.inventory_2_rounded,
                            style: HeaderPillStyle.warm,
                            onTap: onSendParcel!,
                          ),
                          const SizedBox(width: DonySpacing.xs),
                        ],
                        HeaderPill(
                          label: '+ Nouveau',
                          onTap: onCreateTrip,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

// ── Empty / Error views ───────────────────────────────────────────────────────

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
            Icon(Icons.wifi_off_rounded, size: 56, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Impossible de charger vos trajets',
              style: tt.titleLarge?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              onPressed: () => context
                  .read<AnnouncementBloc>()
                  .add(AnnouncementListRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool rawListEmpty;
  final TripStatusFilter activeFilter;

  const _EmptyView({required this.rawListEmpty, required this.activeFilter});

  String get _title => rawListEmpty
      ? 'Aucun trajet à venir'
      : switch (activeFilter) {
          TripStatusFilter.active => 'Aucun trajet actif',
          TripStatusFilter.completed => 'Aucun historique',
          TripStatusFilter.cancelled => 'Aucune annulation',
          TripStatusFilter.all => 'Aucun trajet trouvé',
        };

  String get _description => rawListEmpty
      ? 'Publiez votre premier trajet et commencez à transporter des colis.'
      : switch (activeFilter) {
          TripStatusFilter.active =>
            'Vos trajets en cours et à venir apparaîtront ici.',
          TripStatusFilter.completed =>
            'Vos trajets passés et terminés apparaîtront ici.',
          TripStatusFilter.cancelled => 'Vos trajets annulés apparaîtront ici.',
          TripStatusFilter.all =>
            'Aucun trajet ne correspond à votre recherche.',
        };

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      title: _title,
      description: _description,
      icon: Icons.flight_takeoff_rounded,
    );
  }
}
