import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ColisMatchScreen extends StatelessWidget {
  const ColisMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<AnnouncementBloc>()..add(AnnouncementListRequested()),
        ),
        BlocProvider(
          create: (_) => getIt<PackageRequestSearchBloc>(),
        ),
      ],
      child: const _ColisMatchView(),
    );
  }
}

class _ColisMatchView extends StatefulWidget {
  const _ColisMatchView();

  @override
  State<_ColisMatchView> createState() => _ColisMatchViewState();
}

class _ColisMatchViewState extends State<_ColisMatchView> {
  final _selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _search(BuildContext ctx, AnnouncementModel ann) {
    ctx.read<PackageRequestSearchBloc>().add(SearchFiltersChanged(
          departure: ann.departureCity,
          arrival: ann.arrivalCity,
          dateFrom: ann.departureDate.subtract(const Duration(days: 7)),
          dateTo: ann.departureDate.add(const Duration(days: 7)),
        ));
  }

  void _selectChip(
      BuildContext ctx, List<AnnouncementModel> active, int index) {
    _selectedIndexNotifier.value = index;
    _search(ctx, active[index]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: BlocBuilder<PackageRequestSearchBloc, PackageRequestSearchState>(
          builder: (_, state) {
            final count = state.results.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Colis sur mes trajets',
                  style: tt.headlineMedium,
                ),
                if (count > 0)
                  Text(
                    '$count compatible${count > 1 ? 's' : ''}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outline),
        ),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (ctx, state) {
          if (state is AnnouncementListLoaded) {
            final active = state.announcements
                .where((a) => a.status == 'ACTIVE' || a.status == 'FULL')
                .toList();
            if (active.isEmpty) {
              return;
            }
            final idx =
                _selectedIndexNotifier.value.clamp(0, active.length - 1);
            _selectedIndexNotifier.value = idx;
            _search(ctx, active[idx]);
          }
        },
        builder: (ctx, state) {
          if (state is AnnouncementInitial || state is AnnouncementLoading) {
            return Center(
                child: CircularProgressIndicator(color: cs.primary));
          }
          if (state is AnnouncementError) {
            return _ErrorView(
              onRetry: () => ctx
                  .read<AnnouncementBloc>()
                  .add(AnnouncementListRequested()),
            );
          }
          if (state is AnnouncementListLoaded) {
            final active = state.announcements
                .where((a) => a.status == 'ACTIVE' || a.status == 'FULL')
                .toList();

            if (active.isEmpty) {
              return const _NoTripsEmptyView();
            }

            return ValueListenableBuilder<int>(
              valueListenable: _selectedIndexNotifier,
              builder: (context2, selectedIdx, child) {
                final ann = active[selectedIdx];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChipsBar(
                      announcements: active,
                      selectedIndex: selectedIdx,
                      onTap: (i) => _selectChip(ctx, active, i),
                    ),
                    _CapacityBanner(announcement: ann),
                    Expanded(child: _ResultsView(announcement: ann)),
                  ],
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Chips bar ───────────────────────────────────────────────────────────────

class _ChipsBar extends StatelessWidget {
  const _ChipsBar({
    required this.announcements,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<AnnouncementModel> announcements;
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.sm + 2,
        ),
        child: Row(
          children: List.generate(announcements.length, (i) {
            final ann = announcements[i];
            final isActive = i == selectedIndex;
            final label =
                '✈ ${ann.departureCity}→${ann.arrivalCity} · ${DateFormat('d MMM', 'fr').format(ann.departureDate)}';
            return Padding(
              padding: const EdgeInsets.only(right: DonySpacing.sm),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                    vertical: DonySpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(DonyRadius.xl),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Capacity banner ──────────────────────────────────────────────────────────

class _CapacityBanner extends StatelessWidget {
  const _CapacityBanner({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.xs + 2,
      ),
      child: Row(
        children: [
          Icon(Icons.scale_rounded, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs + 2),
          Text.rich(TextSpan(children: [
            TextSpan(
              text:
                  '${announcement.availableKg.toStringAsFixed(1)} kg restants',
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            TextSpan(
              text: ' · ${announcement.totalKg.toStringAsFixed(1)} kg total',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ])),
        ],
      ),
    );
  }
}

// ─── Results list ─────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.announcement});
  final AnnouncementModel announcement;

  void _triggerSearch(BuildContext ctx, AnnouncementModel ann) {
    ctx.read<PackageRequestSearchBloc>().add(SearchFiltersChanged(
          departure: ann.departureCity,
          arrival: ann.arrivalCity,
          dateFrom: ann.departureDate.subtract(const Duration(days: 7)),
          dateTo: ann.departureDate.add(const Duration(days: 7)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestSearchBloc, PackageRequestSearchState>(
      builder: (ctx, state) {
        if (state.status == SearchStatus.loading ||
            state.status == SearchStatus.initial) {
          return Center(
            child: CircularProgressIndicator(
                color: Theme.of(ctx).colorScheme.primary),
          );
        }

        if (state.status == SearchStatus.error) {
          return _ErrorView(
            onRetry: () => _triggerSearch(ctx, announcement),
          );
        }

        if (state.results.isEmpty && state.status == SearchStatus.loaded) {
          return const _NoResultsEmptyView();
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                n.metrics.extentAfter < 200 &&
                state.hasMore &&
                state.status == SearchStatus.loaded) {
              ctx.read<PackageRequestSearchBloc>().add(const SearchLoadMore());
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async => _triggerSearch(ctx, announcement),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              itemCount: state.results.length +
                  (state.status == SearchStatus.loadingMore ? 1 : 0),
              separatorBuilder: (context3, index) =>
                  const SizedBox(height: DonySpacing.md),
              itemBuilder: (lCtx, i) {
                if (i == state.results.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DonySpacing.base),
                      child: CircularProgressIndicator(
                          color: Theme.of(lCtx).colorScheme.primary),
                    ),
                  );
                }
                final item = state.results[i];
                return PackageRequestListCard(
                  item: item,
                  index: i,
                  onTap: () => lCtx.push(
                    '/package-requests/${item.id}/public',
                    extra: {'announcement': announcement},
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 60 * i),
                      duration: 280.ms,
                    )
                    .slideY(begin: 0.04, curve: Curves.easeOutCubic);
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _NoTripsEmptyView extends StatelessWidget {
  const _NoTripsEmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge - 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucun trajet actif',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Publie un trajet pour voir les colis compatibles.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Publier un trajet',
              onPressed: () => context.push('/announcements/create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsEmptyView extends StatelessWidget {
  const _NoResultsEmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge - 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucun colis ne correspond à ce trajet pour l\'instant.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge - 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Une erreur est survenue',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
