import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/bloc/trip_published_item_prices_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/grid_preview_card.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Carte « Prix par article » de l'écran de succès d'un trajet publié.
///
/// Trajet publié avec des prix par article : ils sont rappelés en pastilles
/// « Libellé · prix ». Grille du profil vide : les prix pratiqués sur la
/// route sont proposés (« Modifier » ouvre l'éditeur prérempli, « Ajouter »
/// les ajoute tels quels). Sans prix de route, seul « Ajouter mes prix »
/// reste : une carte courte, qui garde l'invitation sans charger l'écran.
///
/// La grille est figée sur le trajet à la publication : des prix ajoutés ici
/// valent pour les trajets suivants, ce que la carte dit.
class TripPublishedItemPricesCard extends StatelessWidget {
  const TripPublishedItemPricesCard({
    super.key,
    required this.announcement,
    this.routeSuggestion,
  });

  final AnnouncementModel announcement;

  /// Prix de la route déjà chargés par l'étape prix, s'il y en a.
  final TripPriceSuggestionState? routeSuggestion;

  @override
  Widget build(BuildContext context) {
    // Graphe d'injection incomplet (écrans de démonstration, tests qui ne
    // visent pas cette carte) : l'écran de succès reste entier, sans carte.
    if (!getIt.isRegistered<TripPublishedItemPricesCubit>() ||
        !getIt.isRegistered<PriceGridBloc>()) {
      return const SizedBox.shrink();
    }
    final currency = SupportedCurrency.fromCodeOrDefault(announcement.currency);
    final published = [
      for (final item in announcement.priceGridItems)
        GridPreviewItem(
          id: item.id,
          label: item.label,
          unitPriceDisplay: item.unitPriceDisplay,
          unitPriceNet: item.unitPriceNet,
        ),
    ];
    return MultiBlocProvider(
      providers: [
        BlocProvider<PriceGridBloc>(create: (_) => getIt<PriceGridBloc>()),
        BlocProvider<TripPublishedItemPricesCubit>(
          create: (context) {
            // La grille du profil n'est lue que si le trajet n'en porte pas.
            if (published.isEmpty) {
              context.read<PriceGridBloc>().add(const PriceGridLoadRequested());
            }
            final cubit = getIt<TripPublishedItemPricesCubit>();
            unawaited(
              cubit.start(
                publishedItems: published,
                departureCity: announcement.departureCity,
                arrivalCity: announcement.arrivalCity,
                currency: currency,
                routeSuggestion: routeSuggestion,
              ),
            );
            return cubit;
          },
        ),
      ],
      child: BlocListener<PriceGridBloc, PriceGridState>(
        listener: (context, state) {
          final cubit = context.read<TripPublishedItemPricesCubit>();
          if (state is PriceGridLoaded) {
            cubit.gridLoaded(state.items.length);
          } else if (state is PriceGridError) {
            cubit.gridFailed(state.error);
          }
        },
        child: _CardBody(currency: currency),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.currency});

  final SupportedCurrency currency;

  Future<void> _openEditor(BuildContext context) async {
    final grid = context.read<PriceGridBloc>();
    final suggestions = context
        .read<TripPublishedItemPricesCubit>()
        .editOpened();
    await context.push(
      '/profile/price-grid',
      extra: suggestions.isEmpty ? null : suggestions,
    );
    if (!context.mounted) return;
    grid.add(const PriceGridLoadRequested());
  }

  void _add(BuildContext context) {
    final suggestions = context
        .read<TripPublishedItemPricesCubit>()
        .addRequested();
    if (suggestions == null) return;
    context.read<PriceGridBloc>().add(
      PriceGridSuggestionsAddRequested(suggestions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      TripPublishedItemPricesCubit,
      TripPublishedItemPricesState
    >(
      builder: (context, state) {
        final Widget child = switch (state.status) {
          PublishedItemPricesStatus.checking ||
          PublishedItemPricesStatus.hidden => const SizedBox.shrink(
            key: ValueKey('none'),
          ),
          PublishedItemPricesStatus.filled => _FilledCard(
            key: const ValueKey('filled'),
            items: state.items,
            currency: currency,
          ),
          PublishedItemPricesStatus.proposal ||
          PublishedItemPricesStatus.adding => _ProposalCard(
            key: const ValueKey('proposal'),
            suggestions: state.suggestions,
            currency: currency,
            adding: state.status == PublishedItemPricesStatus.adding,
            failed: state.addFailed,
            onEdit: () => _openEditor(context),
            onAdd: () => _add(context),
          ),
          PublishedItemPricesStatus.empty => _EmptyCard(
            key: const ValueKey('empty'),
            onAdd: () => _openEditor(context),
          ),
          PublishedItemPricesStatus.added => _AddedCard(
            key: const ValueKey('added'),
            count: state.addedCount,
            onSee: () => _openEditor(context),
          ),
        };
        final visible =
            state.status != PublishedItemPricesStatus.checking &&
            state.status != PublishedItemPricesStatus.hidden;
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: visible
                ? Padding(
                    key: ValueKey(
                      state.status == PublishedItemPricesStatus.adding
                          ? PublishedItemPricesStatus.proposal
                          : state.status,
                    ),
                    padding: const EdgeInsets.only(bottom: DonySpacing.base),
                    child: child,
                  )
                : child,
          ),
        );
      },
    );
  }
}

/// Fond chaud des cartes d'invitation (même teinte que la maquette).
BoxDecoration _warmDecoration(ColorScheme cs) => BoxDecoration(
  color: cs.surfaceWarm,
  borderRadius: BorderRadius.circular(DonyRadius.card),
);

class _CardText extends StatelessWidget {
  const _CardText({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          body,
          style: tt.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.45,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    super.key,
    required this.suggestions,
    required this.currency,
    required this.adding,
    required this.failed,
    required this.onEdit,
    required this.onAdd,
  });

  final List<PriceGridSuggestion> suggestions;
  final SupportedCurrency currency;
  final bool adding;
  final bool failed;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      key: const Key('published-item-prices-proposal'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: _warmDecoration(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardText(
            title: l.tripPublishedItemPricesProposalTitle,
            body: l.tripPublishedItemPricesProposalBody,
          ),
          const SizedBox(height: DonySpacing.md),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Column(
              children: [
                for (var i = 0; i < suggestions.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md + 2,
                      vertical: DonySpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: i == suggestions.length - 1
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: cs.outline.withValues(alpha: 0.6),
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestions[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        Text(
                          CurrencyFormatter.formatOrPlain(
                            suggestions[i].unitPriceNet,
                            currency,
                            compact: true,
                          ),
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.tripPublishedItemPricesNextTrips,
            key: const Key('published-item-prices-next-trips'),
            style: tt.bodySmall?.copyWith(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (failed) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.tripPublishedItemPricesAddFailed,
              key: const Key('published-item-prices-add-failed'),
              style: tt.bodySmall?.copyWith(fontSize: 13, color: cs.error),
            ),
          ],
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              Expanded(
                child: DonyButton(
                  key: const Key('published-item-prices-edit'),
                  label: l.commonEdit,
                  variant: DonyButtonVariant.secondary,
                  onPressed: adding ? null : onEdit,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  key: const Key('published-item-prices-add'),
                  label: l.tripPublishedItemPricesAddCta,
                  isLoading: adding,
                  onPressed: adding ? null : onAdd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      key: const Key('published-item-prices-empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: _warmDecoration(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardText(
            title: l.tripPublishedItemPricesProposalTitle,
            body: l.tripPublishedItemPricesEmptyBody,
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('published-item-prices-add-mine'),
            label: l.tripPublishItemPricesAddCta,
            variant: DonyButtonVariant.secondary,
            iconAsset: 'plus',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _AddedCard extends StatelessWidget {
  const _AddedCard({super.key, required this.count, required this.onSee});

  final int count;
  final VoidCallback onSee;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      key: const Key('published-item-prices-added'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.successLight,
                  shape: BoxShape.circle,
                ),
                child: DonyIcon('check', size: 18, color: cs.success),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: _CardText(
                  title: l.tripPublishedItemPricesAddedTitle,
                  body: l.tripPublishedItemPricesAddedBody(count),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('published-item-prices-see'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: onSee,
              child: Text(
                l.tripPublishedItemPricesSeeCta,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Récapitulatif : prix par article du trajet publié, en pastilles nettes.
class _FilledCard extends StatelessWidget {
  const _FilledCard({super.key, required this.items, required this.currency});

  final List<GridPreviewItem> items;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    // Prix figés dans la devise du trajet : aucune conversion, et le net du
    // voyageur sous grille de commission, comme à l'étape prix.
    final display = GridPriceDisplay.resolve(
      gridCurrency: currency,
      tripCurrency: currency,
    );
    return Container(
      key: const Key('published-item-prices-filled'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tripPublishItemPricesTitle,
            style: tt.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DonySpacing.sm + 2),
          Wrap(
            spacing: DonySpacing.xs + 2,
            runSpacing: DonySpacing.xs + 2,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm + 2,
                    vertical: DonySpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    l.tripPublishItemPriceExample(
                      item.label,
                      display.formatItem(item, compact: true),
                    ),
                    style: tt.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
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
