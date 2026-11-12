import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dernier jour proposé par les puces rapides : « le jour même », « le
/// lendemain », « dans 2 jours ». Au-delà, « Autre date ».
const int kArrivalQuickDaysMax = 2;

/// Jours proposés par les puces pour [mode] : jusqu'à J+14 en route (puce
/// « Autre date »), J+2 ailleurs. Un mode inconnu vaut l'avion.
int arrivalChipsMaxDays(TransportMode? mode) =>
    mode != null && mode.isRoad ? mode.maxArrivalDays : kArrivalQuickDaysMax;

/// Décalage d'arrivée à envoyer (création, report, modèle). En route, le jour
/// d'arrivée compte même sans heure d'arrivée (C28) ; ailleurs, il n'existe
/// qu'avec une heure d'arrivée, sinon il vaut 0 (aucun champ caché envoyé).
int effectiveArrivalOffset({
  required TransportMode? mode,
  required bool hasArrivalTime,
  required int offset,
}) => ((mode?.isRoad ?? false) || hasArrivalTime) ? offset : 0;

/// « Arrivée : le jour même / le lendemain / dans 2 jours » (FLUTTER-4E), plus
/// « Autre date » quand le mode permet davantage (route : jusqu'à J+14).
///
/// Partagé par la création de trajet, le report, et l'édition d'un modèle de
/// trajet.
///
/// - [maxDays] <= 2 : trois puces, rendu historique.
/// - [maxDays] > 2 : une quatrième puce « Autre date ». Avec [departureDate],
///   elle ouvre un sélecteur de date borné à départ + 3 jusqu'à départ +
///   [maxDays] ; la date choisie reste affichée sous les puces (« Date
///   d'arrivée »). Sans [departureDate] (modèles et séries : le départ change
///   à chaque occurrence), elle ouvre un choix de décalage en jours, de 3 à
///   [maxDays], affiché « Dans N jours ».
class ArrivalDayChips extends StatelessWidget {
  const ArrivalDayChips({
    super.key,
    required this.notifier,
    this.maxDays = kArrivalQuickDaysMax,
    this.departureDate,
  });
  final ValueNotifier<int> notifier;
  final int maxDays;
  final DateTime? departureDate;

  bool get _hasOtherDate => maxDays > kArrivalQuickDaysMax;

  /// Jour de calendrier à [offset] jours du départ (sans passer par une
  /// `Duration` : un changement d'heure décalerait minuit).
  static DateTime _dayAt(DateTime departure, int offset) =>
      DateTime(departure.year, departure.month, departure.day + offset);

  Future<void> _pickOther(BuildContext context, int selected) async {
    final departure = departureDate;
    const first = kArrivalQuickDaysMax + 1;
    final int? picked;
    if (departure == null) {
      picked = await _pickOffset(context, selected);
    } else {
      final current = selected < first
          ? first
          : (selected > maxDays ? maxDays : selected);
      final date = await showDatePicker(
        context: context,
        initialDate: _dayAt(departure, current),
        firstDate: _dayAt(departure, first),
        lastDate: _dayAt(departure, maxDays),
      );
      picked = date == null
          ? null
          : DateTime.utc(date.year, date.month, date.day)
                .difference(
                  DateTime.utc(departure.year, departure.month, departure.day),
                )
                .inDays;
    }
    if (picked != null) notifier.value = picked;
  }

  /// Choix du décalage en jours, quand aucune date de départ n'est connue.
  Future<int?> _pickOffset(BuildContext context, int selected) {
    final l = context.l10n;
    return DonyBottomSheet.show<int>(
      context,
      title: l.tripPublishArrivalOtherDate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var n = kArrivalQuickDaysMax + 1; n <= maxDays; n++)
            ListTile(
              key: Key('arrival-offset-$n'),
              title: Text(l.tripPublishArrivalDayOption(n)),
              trailing: n == selected ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.of(context, rootNavigator: true).pop(n),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, selected, _) {
        final otherSelected = _hasOtherDate && selected > kArrivalQuickDaysMax;
        final departure = departureDate;
        return Column(
          key: const Key('arrival-day-chips'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.tripPublishArrivalDayLabel,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.xs,
              children: [
                for (var offset = 0; offset <= kArrivalQuickDaysMax; offset++)
                  ChoiceChip(
                    key: Key('arrival-day-$offset'),
                    label: Text(l.tripPublishArrivalDayOption(offset)),
                    selected: selected == offset,
                    onSelected: (_) => notifier.value = offset,
                  ),
                if (_hasOtherDate)
                  ChoiceChip(
                    key: const Key('arrival-day-other'),
                    label: Text(l.tripPublishArrivalOtherDate),
                    selected: otherSelected,
                    onSelected: (_) => _pickOther(context, selected),
                  ),
              ],
            ),
            if (otherSelected) ...[
              const SizedBox(height: DonySpacing.xs),
              Wrap(
                key: const Key('arrival-date-row'),
                spacing: DonySpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l.tripPublishArrivalDateLabel,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    departure == null
                        ? l.tripPublishArrivalDayOption(selected)
                        : DateFormat.yMMMEd(
                            l.localeName,
                          ).format(_dayAt(departure, selected)),
                    key: const Key('arrival-date-value'),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
