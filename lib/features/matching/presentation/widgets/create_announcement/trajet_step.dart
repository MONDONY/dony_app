// Étape 0 du formulaire "Publier un trajet" : Trajet + Mode de transport.
// Extrait de create_announcement_bottom_sheet.dart — refactor pur, aucun changement
// de comportement.
import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Corps de l'étape 0 (Trajet + Mode de transport) du formulaire de création
/// d'annonce.
///
/// Tous les notifiers restent dans [_CreateAnnouncementContentState] (parent) ;
/// ce widget reçoit ses dépendances via des paramètres (option a).
///
/// [departureCityBloc] et [arrivalCityBloc] sont optionnels — ils permettent
/// l'injection en test. En production, le widget crée ses propres instances
/// via GetIt.
class TrajetStep extends StatelessWidget {
  final ValueNotifier<String?> departureCityNotifier;
  final ValueNotifier<String?> arrivalCityNotifier;

  /// Codes pays ISO-2 capturés lors de la sélection ville (optionnels — null
  /// dans les contextes/tests qui ne les passent pas, sans effet de bord).
  final ValueNotifier<String?>? departureCountryCodeNotifier;
  final ValueNotifier<String?>? arrivalCountryCodeNotifier;
  final ValueNotifier<DateTime?> departureDateNotifier;
  final ValueNotifier<TimeOfDay?> departureTimeNotifier;
  final ValueNotifier<TimeOfDay?> arrivalTimeNotifier;
  final ValueNotifier<TransportMode?> transportModeNotifier;

  /// Callbacks vers les méthodes du state parent.
  final Future<void> Function() onSelectDepartureTime;
  final Future<void> Function() onSelectArrivalTime;
  final Future<void> Function() onSelectDate;

  /// Blocs injectables pour les tests — null = créer via GetIt.
  final CitySearchBloc? departureCityBloc;
  final CitySearchBloc? arrivalCityBloc;

  /// Verrouille les villes (corridor) : champs en lecture seule. Utilisé quand
  /// le trajet est contraint par une demande (modification OU trajet dédié).
  final bool lockCorridor;

  /// Verrouille la date de départ : champ en lecture seule. Utilisé en
  /// modification (la date doit rester compatible avec la demande). Le trajet
  /// dédié la garde éditable (choix dans la fenêtre de tolérance).
  final bool lockDate;

  const TrajetStep({
    super.key,
    required this.departureCityNotifier,
    required this.arrivalCityNotifier,
    this.departureCountryCodeNotifier,
    this.arrivalCountryCodeNotifier,
    required this.departureDateNotifier,
    required this.departureTimeNotifier,
    required this.arrivalTimeNotifier,
    required this.transportModeNotifier,
    required this.onSelectDepartureTime,
    required this.onSelectArrivalTime,
    required this.onSelectDate,
    this.departureCityBloc,
    this.arrivalCityBloc,
    this.lockCorridor = false,
    this.lockDate = false,
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

  /// Formate la date et les heures du corridor pour l'aperçu.
  /// Reproduit exactement la logique de [_CreateAnnouncementContentState._formatCorridorDateTime].
  String _formatCorridorDateTime() {
    final departureDate = departureDateNotifier.value;
    final departureTime = departureTimeNotifier.value;
    final arrivalTime = arrivalTimeNotifier.value;
    if (departureDate == null) {
      return '';
    }
    final date = DateFormat('EEE d MMM', 'fr').format(departureDate);
    if (departureTime != null && arrivalTime != null) {
      return '$date · ${departureTime.hour}h–${arrivalTime.hour}h';
    } else if (departureTime != null) {
      return '$date · ${departureTime.hour}h';
    }
    return date;
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
          final dateStr = _formatCorridorDateTime();
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
      const CaSectionLabel(label: 'Trajet', iconAsset: 'plane-takeoff'),
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
              // ── Ville de départ * ───────────────────────────────────────
              // CityAutocompleteField utilise le même InputDecoration (via
              // le thème) que DonyTextField — uniformité visuelle garantie.
              // L'autocomplétion (suggestions inline) est préservée.
              // requiredLabel: true → astérisque rouge via InputDecoration.label.
              lockCorridor
                  ? DonyTextField.tappable(
                      key: const Key('departureCityField'),
                      label: 'Ville de départ',
                      value: departureCityNotifier.value,
                      prefixWidget: const DonyEmoji.planeTakeoff(size: 20),
                      trailing: DonyIcon('lock',
                          size: 16, color: cs.onSurfaceVariant),
                      onTap: () {},
                    )
                  : BlocProvider(
                      create: (_) =>
                          departureCityBloc ?? getIt<CitySearchBloc>(),
                      child: CityAutocompleteField(
                        label: 'Ville de départ',
                        fieldKey: const Key('departureCityField'),
                        initialValue: departureCityNotifier.value,
                        prefixIcon: const DonyEmoji.planeTakeoff(size: 20),
                        requiredLabel: true,
                        onSelected: (CityModel city) {
                          // Code pays d'abord : le listener du city notifier
                          // (sync vers le form bloc) lit la valeur courante.
                          departureCountryCodeNotifier?.value = city.countryCode;
                          departureCityNotifier.value = city.name;
                        },
                      ),
                    ),
              const SizedBox(height: DonySpacing.sm),
              // ── Heure de départ (obligatoire, D1) — DonyTextField.tappable ───
              DonyTextField.tappable(
                key: const Key('departureTimeField'),
                label: 'Heure de départ',
                requiredLabel: true,
                value: departureTimeNotifier.value != null
                    ? '${departureTimeNotifier.value!.hour.toString().padLeft(2, '0')}:${departureTimeNotifier.value!.minute.toString().padLeft(2, '0')}'
                    : null,
                prefixIcon: DonyIcons.time,
                prefixIconColor: Theme.of(context).colorScheme.primary,
                // Obligatoire (D1) : pas de bouton clear, on garde le chevron.
                trailing: Icon(
                  DonyIcons.chevron,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => onSelectDepartureTime(),
              ),
              const SizedBox(height: DonySpacing.sm),
              // ── Ville d'arrivée * ───────────────────────────────────────
              lockCorridor
                  ? DonyTextField.tappable(
                      key: const Key('arrivalCityField'),
                      label: 'Ville d\'arrivée',
                      value: arrivalCityNotifier.value,
                      prefixWidget: const DonyEmoji.planeLanding(size: 20),
                      trailing: DonyIcon('lock',
                          size: 16, color: cs.onSurfaceVariant),
                      onTap: () {},
                    )
                  : BlocProvider(
                      create: (_) =>
                          arrivalCityBloc ?? getIt<CitySearchBloc>(),
                      child: CityAutocompleteField(
                        label: 'Ville d\'arrivée',
                        fieldKey: const Key('arrivalCityField'),
                        initialValue: arrivalCityNotifier.value,
                        prefixIcon: const DonyEmoji.planeLanding(size: 20),
                        requiredLabel: true,
                        onSelected: (CityModel city) {
                          arrivalCountryCodeNotifier?.value = city.countryCode;
                          arrivalCityNotifier.value = city.name;
                        },
                      ),
                    ),
              const SizedBox(height: DonySpacing.sm),
              // ── Heure d'arrivée (optionnel) — DonyTextField.tappable ───
              DonyTextField.tappable(
                key: const Key('arrivalTimeField'),
                label: 'Heure d\'arrivée (optionnel)',
                value: arrivalTimeNotifier.value != null
                    ? '${arrivalTimeNotifier.value!.hour.toString().padLeft(2, '0')}:${arrivalTimeNotifier.value!.minute.toString().padLeft(2, '0')}'
                    : null,
                prefixIcon: DonyIcons.time,
                prefixIconColor: Theme.of(context).colorScheme.secondary,
                trailing: arrivalTimeNotifier.value != null
                    ? IconButton(
                        icon: Icon(
                          DonyIcons.close,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => arrivalTimeNotifier.value = null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      )
                    : Icon(
                        DonyIcons.chevron,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                onTap: () => onSelectArrivalTime(),
              ),
              const SizedBox(height: DonySpacing.sm),
              // ── Date de départ * — DonyTextField.tappable ─────────────
              DonyTextField.tappable(
                key: const Key('departureDateField'),
                label: 'Date de départ',
                value: departureDateNotifier.value != null
                    ? DateFormat('EEE d MMM yyyy', 'fr')
                        .format(departureDateNotifier.value!)
                    : null,
                prefixIcon: DonyIcons.date,
                prefixIconColor: Theme.of(context).colorScheme.primary,
                trailing: DonyIcon(
                  lockDate ? 'lock' : 'chevron-right',
                  size: lockDate ? 16 : 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                requiredLabel: true,
                onTap: lockDate ? () {} : () => onSelectDate(),
              ),
            ],
          ).animate().fadeIn(delay: 60.ms);
        },
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── MODE DE TRANSPORT ─────────────────────────────────────────────────
      const CaSectionLabel(
        label: 'Mode de transport',
        iconAsset: 'route',
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
