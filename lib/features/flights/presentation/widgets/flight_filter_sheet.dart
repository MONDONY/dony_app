import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/features/flights/presentation/widgets/flight_results_parts.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille « Filtres » des résultats : escales, horaires de départ, prix
/// maximum, compagnies et sites de réservation. Le tri vit dans les onglets
/// des résultats. Travaille sur les offres déjà reçues ; rend les filtres
/// validés, `null` si la feuille est fermée sans valider.
abstract final class FlightFilterSheet {
  static Future<FlightFilters?> show(
    BuildContext context, {
    required List<FlightOffer> offers,
    required FlightFilters current,
    required String currency,
    FlightFilterSection? focus,
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
      child: _FilterBody(
        draft: draft,
        facets: facets,
        currency: currency,
        focus: focus,
      ),
    ).whenComplete(draft.dispose);
  }
}

class _FilterBody extends StatefulWidget {
  const _FilterBody({
    required this.draft,
    required this.facets,
    required this.currency,
    required this.focus,
  });

  final ValueNotifier<FlightFilters> draft;
  final FlightFacets facets;
  final String currency;
  final FlightFilterSection? focus;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

/// `State` pour les seules clés des rubriques : la feuille défile jusqu'à
/// celle de la puce touchée, une fois posée.
class _FilterBodyState extends State<_FilterBody> {
  final _sections = {
    for (final s in FlightFilterSection.values) s: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    final focus = widget.focus;
    if (focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _sections[focus]?.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(
            target,
            duration: DonyDuration.slow,
            curve: DonyCurve.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final facets = widget.facets;
    final currency = widget.currency;
    final draft = widget.draft;

    Widget section(String title, {Key? key, bool first = false}) => Padding(
      key: key,
      padding: EdgeInsets.only(
        top: first ? DonySpacing.base : DonySpacing.xl,
        bottom: DonySpacing.sm,
      ),
      child: Text(
        title,
        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return ValueListenableBuilder<FlightFilters>(
      valueListenable: draft,
      builder: (context, f, _) {
        final steps = facets.priceSteps;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            section(
              l.flightsFiltersStops,
              key: _sections[FlightFilterSection.stops],
              first: true,
            ),
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
            if (facets.slots.isNotEmpty) ...[
              section(
                l.flightsFiltersTimes,
                key: _sections[FlightFilterSection.times],
              ),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final slot in FlightDaySlot.values)
                    if (facets.slots.contains(slot))
                      DonyChip(
                        key: Key('flight-slot-${slot.name}'),
                        label: switch (slot) {
                          FlightDaySlot.night => l.flightsSlotNight,
                          FlightDaySlot.morning => l.flightsSlotMorning,
                          FlightDaySlot.afternoon => l.flightsSlotAfternoon,
                          FlightDaySlot.evening => l.flightsSlotEvening,
                        },
                        selected: f.slots.contains(slot),
                        onTap: () {
                          final next = {...f.slots};
                          next.contains(slot)
                              ? next.remove(slot)
                              : next.add(slot);
                          draft.value = f.copyWith(slots: next);
                        },
                      ),
                ],
              ),
            ],
            if (steps.isNotEmpty) ...[
              section(l.flightsFiltersMaxPrice),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  DonyChip(
                    key: const Key('flight-price-any'),
                    label: l.flightsPriceAny,
                    selected: f.maxPrice == null,
                    onTap: () => draft.value = f.copyWith(
                      clearMaxPrice: true,
                      clearMinPrice: true,
                    ),
                  ),
                  for (final step in steps)
                    DonyChip(
                      key: Key('flight-price-${step.round()}'),
                      label: l.flightsAlertAtMost(
                        FlightFormat.price(step, currency),
                      ),
                      selected: f.maxPrice == step,
                      onTap: () => draft.value = f.copyWith(
                        maxPrice: step,
                        clearMinPrice: true,
                      ),
                    ),
                ],
              ),
            ],
            if (facets.airlines.isNotEmpty) ...[
              section(
                l.flightsFiltersAirlines,
                key: _sections[FlightFilterSection.airlines],
              ),
              for (final airline in facets.airlines)
                FlightCheckRow(
                  key: Key('flight-airline-${airline.code}'),
                  value: f.airlines.contains(airline.code),
                  onChanged: (checked) {
                    final next = {...f.airlines};
                    checked
                        ? next.add(airline.code)
                        : next.remove(airline.code);
                    draft.value = f.copyWith(airlines: next);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DonySpacing.xs,
                    ),
                    child: Row(
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
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
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
