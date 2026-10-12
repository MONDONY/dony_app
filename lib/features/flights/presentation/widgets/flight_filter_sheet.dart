import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille « Filtres » des résultats : tri, prix min–max, escales, compagnies
/// et sites de réservation. Travaille sur les offres déjà reçues ; rend les
/// filtres validés, `null` si la feuille est fermée sans valider.
abstract final class FlightFilterSheet {
  static Future<FlightFilters?> show(
    BuildContext context, {
    required List<FlightOffer> offers,
    required FlightFilters current,
    required String currency,
  }) {
    final draft = ValueNotifier(current);
    final facets = FlightFacets.of(offers);
    final l = context.l10n;
    return DonyBottomSheet.show<FlightFilters>(
      context,
      title: l.flightsFiltersTitle,
      heightFraction: 0.92,
      stickyBottom: ValueListenableBuilder<FlightFilters>(
        valueListenable: draft,
        builder: (context, filters, _) {
          final count = filters.apply(offers).length;
          return Row(
            children: [
              DonyButton(
                key: const Key('flight-filters-reset'),
                label: l.flightsFiltersReset,
                variant: DonyButtonVariant.ghost,
                fullWidth: false,
                onPressed: () =>
                    draft.value = FlightFilters(sort: filters.sort),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  key: const Key('flight-filters-apply'),
                  label: l.flightsFiltersShow(count),
                  onPressed: () => Navigator.of(context).pop(filters),
                ),
              ),
            ],
          );
        },
      ),
      child: _FilterBody(draft: draft, facets: facets, currency: currency),
    ).whenComplete(draft.dispose);
  }
}

class _FilterBody extends StatelessWidget {
  const _FilterBody({
    required this.draft,
    required this.facets,
    required this.currency,
  });

  final ValueNotifier<FlightFilters> draft;
  final FlightFacets facets;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget section(String title, {String? trailing}) => Padding(
      padding: const EdgeInsets.only(
        top: DonySpacing.xl,
        bottom: DonySpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );

    return ValueListenableBuilder<FlightFilters>(
      valueListenable: draft,
      builder: (context, f, _) {
        final min = facets.minPrice;
        final max = facets.maxPrice;
        final low = f.minPrice ?? min;
        final high = f.maxPrice ?? max;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.flightsFiltersSort,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.sm),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                for (final sort in FlightSort.values)
                  DonyChip(
                    key: Key('flight-sort-${sort.name}'),
                    label: switch (sort) {
                      FlightSort.cheapest => l.flightsSortCheapest,
                      FlightSort.fastest => l.flightsSortFastest,
                      FlightSort.fewestStops => l.flightsSortFewestStops,
                    },
                    selected: f.sort == sort,
                    onTap: () => draft.value = f.copyWith(sort: sort),
                  ),
              ],
            ),
            if (min != null && max != null && max > min) ...[
              section(
                l.flightsFiltersPrice,
                trailing:
                    '${FlightFormat.price(low!, currency)} – ${FlightFormat.price(high!, currency)}',
              ),
              RangeSlider(
                key: const Key('flight-filter-price'),
                min: min,
                max: max,
                values: RangeValues(low.clamp(min, max), high.clamp(min, max)),
                labels: RangeLabels(
                  FlightFormat.price(low, currency),
                  FlightFormat.price(high, currency),
                ),
                onChanged: (v) => draft.value = f.copyWith(
                  minPrice: v.start <= min ? null : v.start,
                  maxPrice: v.end >= max ? null : v.end,
                  clearMinPrice: v.start <= min,
                  clearMaxPrice: v.end >= max,
                ),
              ),
            ],
            section(l.flightsFiltersStops),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                for (final stops in FlightStops.values)
                  DonyChip(
                    key: Key('flight-stops-${stops.name}'),
                    label: switch (stops) {
                      FlightStops.any => l.flightsStopsAny,
                      FlightStops.direct => l.flightsStopsDirect,
                      FlightStops.oneMax => l.flightsStopsOneMax,
                    },
                    selected: f.stops == stops,
                    onTap: () => draft.value = f.copyWith(stops: stops),
                  ),
              ],
            ),
            if (facets.airlines.isNotEmpty) ...[
              section(l.flightsFiltersAirlines),
              for (final airline in facets.airlines)
                CheckboxListTile(
                  key: Key('flight-airline-${airline.code}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: f.airlines.contains(airline.code),
                  onChanged: (checked) {
                    final next = {...f.airlines};
                    checked == true
                        ? next.add(airline.code)
                        : next.remove(airline.code);
                    draft.value = f.copyWith(airlines: next);
                  },
                  title: Row(
                    children: [
                      AirlineLogo(
                        code: airline.code,
                        logoUrl: airline.logoUrl,
                        name: airline.name,
                        size: 28,
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          airline.name,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        l.flightsFromPrice(
                          FlightFormat.price(airline.minPrice, currency),
                        ),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (facets.gates.isNotEmpty) ...[
              section(l.flightsFiltersGates),
              Text(
                l.flightsFiltersGatesHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final gate in facets.gates)
                    DonyChip(
                      key: Key('flight-gate-${gate.name}'),
                      label:
                          '${gate.name} · ${FlightFormat.price(gate.minPrice, currency)}',
                      selected: f.gates.contains(gate.name),
                      onTap: () {
                        final next = {...f.gates};
                        next.contains(gate.name)
                            ? next.remove(gate.name)
                            : next.add(gate.name);
                        draft.value = f.copyWith(gates: next);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: DonySpacing.base),
          ],
        );
      },
    );
  }
}
