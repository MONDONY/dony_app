import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PackageRequestSearchScreen extends StatelessWidget {
  const PackageRequestSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<PackageRequestSearchBloc>()..add(const SearchFiltersChanged()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _depCtrl = TextEditingController();
  final _arrCtrl = TextEditingController();

  void _applyFilters() {
    context.read<PackageRequestSearchBloc>().add(
      SearchFiltersChanged(
        departure: _depCtrl.text.trim().isEmpty ? null : _depCtrl.text.trim(),
        arrival: _arrCtrl.text.trim().isEmpty ? null : _arrCtrl.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _depCtrl.dispose();
    _arrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Demandes ouvertes',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.lg,
              DonySpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _depCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Départ',
                      prefixIcon: DonyEmoji.planeTakeoff(size: 18),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: TextField(
                    controller: _arrCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Arrivée',
                      prefixIcon: DonyEmoji.planeLanding(size: 18),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                IconButton.filled(
                  icon: const DonyIcon('search'),
                  onPressed: _applyFilters,
                  style: IconButton.styleFrom(backgroundColor: cs.primary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          Expanded(
            child:
                BlocBuilder<
                  PackageRequestSearchBloc,
                  PackageRequestSearchState
                >(
                  builder: (context, state) {
                    if (state.status == SearchStatus.loading) {
                      return Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      );
                    }
                    if (state.status == SearchStatus.error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(
                            state.errorMessage ?? 'Erreur',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(fontSize: 14, color: kError),
                          ),
                        ),
                      );
                    }
                    if (state.results.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const DonyMascotteAnimated(
                                type: DonyMascotteType.aucunResultat,
                                size: DonyMascotteSize.lg,
                              ),
                              const SizedBox(height: DonySpacing.base),
                              Text(
                                'Aucune demande ne correspond à votre filtre',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      fontSize: 14,
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                                n.metrics.maxScrollExtent - 200 &&
                            state.status == SearchStatus.loaded &&
                            state.hasMore) {
                          context.read<PackageRequestSearchBloc>().add(
                            const SearchLoadMore(),
                          );
                        }
                        return false;
                      },
                      child: RefreshIndicator(
                        color: cs.primary,
                        onRefresh: () async {
                          context.read<PackageRequestSearchBloc>().add(
                            const SearchRefresh(),
                          );
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.lg,
                            DonySpacing.md,
                            DonySpacing.lg,
                            40,
                          ),
                          itemCount:
                              state.results.length +
                              (state.status == SearchStatus.loadingMore
                                  ? 1
                                  : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: DonySpacing.md),
                          itemBuilder: (context, i) {
                            if (i >= state.results.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: DonySpacing.base,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: cs.primary,
                                  ),
                                ),
                              );
                            }
                            final r = state.results[i];
                            return _PublicRequestCard(request: r)
                                .animate()
                                .fadeIn(duration: 200.ms, delay: (40 * i).ms)
                                .slideY(begin: 0.04);
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _PublicRequestCard extends StatelessWidget {
  const _PublicRequestCard({required this.request});
  final PackageRequestSearchItem request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => context.push('/package-requests/${request.id}/public'),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.departureCity} → ${request.arrivalCity}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      request.parcelSize.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.md,
                runSpacing: DonySpacing.xs,
                children: [
                  _Pill(
                    iconAsset: 'calendar',
                    label:
                        '${request.desiredDate.day}/${request.desiredDate.month} ±${request.dateToleranceDays}j',
                  ),
                  _Pill(iconAsset: 'scale', label: '${request.weightKg} kg'),
                  if (request.categories.isNotEmpty)
                    _Pill(iconAsset: 'tag', label: request.categories.first),
                ],
              ),
              if (request.targetPriceEur != null) ...[
                const SizedBox(height: DonySpacing.md),
                Text(
                  'Budget: ${formatPriceIn(request.targetPriceEur!, request.currency)}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.iconAsset, required this.label});
  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon(iconAsset, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
