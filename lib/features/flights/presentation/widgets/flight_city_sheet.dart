import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Ville de départ / d'arrivée » : autocomplétion des villes
/// (`GET /flights/places`), villes de la diaspora proposées à vide. Rend la
/// ville choisie, `null` si la feuille est fermée.
abstract final class FlightCitySheet {
  static Future<FlightPlace?> show(
    BuildContext context, {
    required bool departure,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<FlightPlace>(
      context,
      title: departure
          ? l.flightsCityDepartureTitle
          : l.flightsCityArrivalTitle,
      heightFraction: 0.85,
      child: BlocProvider(
        create: (_) => getIt<FlightPlacesCubit>(),
        child: const _CityPicker(),
      ),
    );
  }
}

class _CityPicker extends StatelessWidget {
  const _CityPicker();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonySearchField(
          key: const Key('flight-city-field'),
          hint: l.flightsCitySearchHint,
          autofocus: true,
          onChanged: context.read<FlightPlacesCubit>().termChanged,
        ),
        const SizedBox(height: DonySpacing.base),
        BlocBuilder<FlightPlacesCubit, FlightPlacesState>(
          builder: (context, state) {
            if (state.status == FlightPlacesStatus.error) {
              return Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Text(
                  ErrorPresenter.resolve(state.error, l10n: l).message,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              );
            }
            if (state.status == FlightPlacesStatus.loaded &&
                state.places.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Text(
                  l.flightsCityNoResult,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.status == FlightPlacesStatus.suggestions
                      ? l.flightsCitySuggestions
                      : l.flightsCityResults,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (state.status == FlightPlacesStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DonySpacing.sm),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                for (final place in state.places)
                  _CityRow(
                    place: place,
                    onTap: () => Navigator.of(context).pop(place),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.place, required this.onTap});

  final FlightPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final subtitle = [?place.countryName, place.code].join(' · ');

    return InkWell(
      key: Key('flight-city-${place.code}'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              place.name,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
