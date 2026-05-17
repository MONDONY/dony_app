// Étape 0 du formulaire "Publier un trajet" : Trajet + Mode de transport.
// Extrait de create_announcement_bottom_sheet.dart — refactor pur, aucun changement
// de comportement.
import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Corps de l'étape 0 (Trajet + Mode de transport) du formulaire de création
/// d'annonce.
///
/// Tous les notifiers restent dans [_CreateAnnouncementContentState] (parent) ;
/// ce widget reçoit ses dépendances via des paramètres (option a).
class TrajetStep extends StatelessWidget {
  final ValueNotifier<String?> departureCityNotifier;
  final ValueNotifier<String?> arrivalCityNotifier;
  final ValueNotifier<DateTime?> departureDateNotifier;
  final ValueNotifier<TimeOfDay?> departureTimeNotifier;
  final ValueNotifier<TimeOfDay?> arrivalTimeNotifier;
  final ValueNotifier<TransportMode?> transportModeNotifier;

  /// Callbacks vers les méthodes du state parent.
  final Future<void> Function() onSelectDepartureTime;
  final Future<void> Function() onSelectArrivalTime;
  final Future<void> Function() onSelectDate;
  final String Function() formatCorridorDateTime;

  const TrajetStep({
    super.key,
    required this.departureCityNotifier,
    required this.arrivalCityNotifier,
    required this.departureDateNotifier,
    required this.departureTimeNotifier,
    required this.arrivalTimeNotifier,
    required this.transportModeNotifier,
    required this.onSelectDepartureTime,
    required this.onSelectArrivalTime,
    required this.onSelectDate,
    required this.formatCorridorDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildWidgets(context, tt, cs),
    );
  }

  List<Widget> _buildWidgets(
      BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      // ── Corridor preview ──────────────────────────────────────────────────
      ListenableBuilder(
        listenable: Listenable.merge([
          departureCityNotifier,
          arrivalCityNotifier,
          departureDateNotifier,
          departureTimeNotifier,
          arrivalTimeNotifier,
        ]),
        builder: (context, _) {
          final dep = departureCityNotifier.value;
          final arr = arrivalCityNotifier.value;
          if (dep == null || arr == null) {
            return const SizedBox.shrink();
          }
          final depCode = cityAirportCode(dep, departure: true);
          final arrCode = cityAirportCode(arr, departure: false);
          final dateStr = formatCorridorDateTime();
          return Column(
            children: [
              CaSectionCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$depCode → $arrCode',
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.sm,
                          vertical: DonySpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(DonyRadius.full),
                        ),
                        child: Text(
                          'Confirmé',
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: DonySpacing.xl),
            ],
          );
        },
      ),

      // ── TRAJET ────────────────────────────────────────────────────────────
      const CaSectionLabel(label: 'TRAJET', icon: Icons.flight_takeoff_rounded),
      const SizedBox(height: DonySpacing.sm),
      ListenableBuilder(
        listenable: Listenable.merge([
          departureCityNotifier,
          arrivalCityNotifier,
          departureDateNotifier,
          departureTimeNotifier,
          arrivalTimeNotifier,
        ]),
        builder: (context, _) {
          return Column(
            children: [
              BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: CaFieldCard(
                  child: CityAutocompleteField(
                    label: 'Ville de départ',
                    initialValue: departureCityNotifier.value,
                    prefixIcon: const CaFieldIcon(
                        icon: Icons.flight_takeoff_rounded),
                    onSelected: (CityModel city) {
                      departureCityNotifier.value = city.name;
                    },
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              CaTimeRow(
                isDeparture: true,
                time: departureTimeNotifier.value,
                onTap: onSelectDepartureTime,
                onClear: departureTimeNotifier.value != null
                    ? () => departureTimeNotifier.value = null
                    : null,
              ),
              const SizedBox(height: DonySpacing.sm),
              BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: CaFieldCard(
                  child: CityAutocompleteField(
                    label: 'Ville d\'arrivée',
                    initialValue: arrivalCityNotifier.value,
                    prefixIcon:
                        const CaFieldIcon(icon: Icons.flight_land_rounded),
                    onSelected: (CityModel city) {
                      arrivalCityNotifier.value = city.name;
                    },
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              CaTimeRow(
                isDeparture: false,
                time: arrivalTimeNotifier.value,
                onTap: onSelectArrivalTime,
                onClear: arrivalTimeNotifier.value != null
                    ? () => arrivalTimeNotifier.value = null
                    : null,
              ),
              const SizedBox(height: DonySpacing.sm),
              CaDateRow(
                date: departureDateNotifier.value,
                onTap: onSelectDate,
              ),
            ],
          ).animate().fadeIn(delay: 60.ms);
        },
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── MODE DE TRANSPORT ─────────────────────────────────────────────────
      const CaSectionLabel(
        label: 'MODE DE TRANSPORT',
        icon: Icons.commute_rounded,
      ),
      const SizedBox(height: DonySpacing.sm),
      ValueListenableBuilder<TransportMode?>(
        valueListenable: transportModeNotifier,
        builder: (context, current, _) {
          return Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: [
              for (final mode in TransportMode.values)
                Opacity(
                  opacity: mode != TransportMode.plane ? 0.4 : 1.0,
                  child: DonyChip(
                    key: Key('transport-chip-${mode.name}'),
                    label: mode.label,
                    icon: mode.icon,
                    selected: current == mode,
                    onTap: mode == TransportMode.plane
                        ? () => transportModeNotifier.value = mode
                        : () {
                            DonySnackbar.show(
                              context,
                              message: 'Bientôt disponible',
                              type: DonySnackbarType.info,
                            );
                          },
                  ),
                ),
            ],
          );
        },
      ).animate().fadeIn(delay: 110.ms),
      const SizedBox(height: DonySpacing.xxl),
    ];
  }
}
