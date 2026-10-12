import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Dates retenues dans la feuille : [returnDate] `null` = aller simple.
class FlightDatesChoice {
  const FlightDatesChoice({this.departure, this.returnDate});

  final FlightWhen? departure;
  final FlightWhen? returnDate;
}

enum _Leg { departure, returnLeg }

/// Feuille « Quand partez-vous ? » : jour précis (calendrier) ou mois entier
/// (grille de mois). L'aller-retour se choisit dans le formulaire ([roundTrip])
/// ; [returnFirst] ouvre la feuille sur la date du retour. Rend le choix,
/// `null` si la feuille est fermée sans valider.
abstract final class FlightDatesSheet {
  static Future<FlightDatesChoice?> show(
    BuildContext context, {
    FlightWhen? departure,
    FlightWhen? returnDate,
    bool roundTrip = false,
    bool returnFirst = false,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final state = _DatesState(
      roundTrip: roundTrip || returnDate != null,
      wholeMonth: ValueNotifier(departure?.wholeMonth ?? false),
      departure: ValueNotifier(departure?.date),
      returnDate: ValueNotifier(returnDate?.date),
      leg: ValueNotifier(
        returnFirst && departure != null ? _Leg.returnLeg : _Leg.departure,
      ),
      today: DateTime(now.year, now.month, now.day),
    );
    return DonyBottomSheet.show<FlightDatesChoice>(
      context,
      title: context.l10n.flightsDatesTitle,
      heightFraction: 0.92,
      stickyBottom: _ValidateButton(state: state),
      child: _DatesBody(state: state),
    ).whenComplete(state.dispose);
  }
}

class _DatesState {
  _DatesState({
    required this.roundTrip,
    required this.wholeMonth,
    required this.departure,
    required this.returnDate,
    required this.leg,
    required this.today,
  });

  final bool roundTrip;
  final ValueNotifier<bool> wholeMonth;
  final ValueNotifier<DateTime?> departure;
  final ValueNotifier<DateTime?> returnDate;
  final ValueNotifier<_Leg> leg;
  final DateTime today;

  Listenable get all =>
      Listenable.merge([wholeMonth, departure, returnDate, leg]);

  FlightWhen? _when(DateTime? d) {
    if (d == null) return null;
    return wholeMonth.value ? FlightWhen.month(d) : FlightWhen.day(d);
  }

  FlightDatesChoice get choice => FlightDatesChoice(
    departure: _when(departure.value),
    returnDate: roundTrip ? _when(returnDate.value) : null,
  );

  /// Un retour qui précède l'aller (au jour, ou au mois) est refusé.
  bool get isValid {
    final out = departure.value;
    final back = returnDate.value;
    if (!roundTrip || out == null || back == null) return true;
    return wholeMonth.value
        ? DateTime(
                back.year,
                back.month,
              ).compareTo(DateTime(out.year, out.month)) >=
              0
        : !back.isBefore(out);
  }

  void pick(DateTime d) {
    if (leg.value == _Leg.departure) {
      departure.value = d;
      final back = returnDate.value;
      if (back != null && back.isBefore(d)) returnDate.value = null;
      if (roundTrip) leg.value = _Leg.returnLeg;
    } else {
      returnDate.value = d;
    }
  }

  void dispose() {
    wholeMonth.dispose();
    departure.dispose();
    returnDate.dispose();
    leg.dispose();
  }
}

class _DatesBody extends StatelessWidget {
  const _DatesBody({required this.state});

  final _DatesState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: state.all,
      builder: (context, _) {
        final wholeMonth = state.wholeMonth.value;
        final roundTrip = state.roundTrip;
        String label(DateTime? d) => d == null
            ? l.flightsDatesAny
            : wholeMonth
            ? FlightFormat.month(l, d)
            : FlightFormat.dateTime(l, d, withTime: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _LegTile(
                    key: const Key('flight-dates-departure'),
                    title: l.flightsOutboundLabel,
                    value: label(state.departure.value),
                    selected: state.leg.value == _Leg.departure,
                    onTap: () => state.leg.value = _Leg.departure,
                  ),
                ),
                if (roundTrip) ...[
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: _LegTile(
                      key: const Key('flight-dates-return'),
                      title: l.flightsReturnLabel,
                      value: label(state.returnDate.value),
                      selected: state.leg.value == _Leg.returnLeg,
                      onTap: () => state.leg.value = _Leg.returnLeg,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            Wrap(
              spacing: DonySpacing.sm,
              children: [
                DonyChip(
                  key: const Key('flight-dates-day'),
                  label: l.flightsDatesPreciseDay,
                  selected: !wholeMonth,
                  onTap: () => state.wholeMonth.value = false,
                ),
                DonyChip(
                  key: const Key('flight-dates-month'),
                  label: l.flightsDatesWholeMonth,
                  selected: wholeMonth,
                  onTap: () => state.wholeMonth.value = true,
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            if (wholeMonth)
              _MonthGrid(state: state)
            else
              CalendarDatePicker(
                // Nouvelle clé à chaque changement de jambe : le calendrier se
                // replace sur la date de cette jambe.
                key: ValueKey(state.leg.value),
                initialDate: _initialDay(),
                firstDate: _firstDay(),
                lastDate: state.today.add(const Duration(days: 365)),
                onDateChanged: state.pick,
              ),
            if (!state.isValid)
              Text(
                l.flightsDatesReturnBeforeDeparture,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.error),
              ),
          ],
        );
      },
    );
  }

  DateTime _firstDay() {
    final out = state.departure.value;
    return state.leg.value == _Leg.returnLeg &&
            out != null &&
            !out.isBefore(state.today)
        ? out
        : state.today;
  }

  DateTime _initialDay() {
    final first = _firstDay();
    final current = state.leg.value == _Leg.departure
        ? state.departure.value
        : state.returnDate.value;
    if (current == null || current.isBefore(first)) return first;
    return current;
  }
}

class _LegTile extends StatelessWidget {
  const _LegTile({
    super.key,
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les 12 prochains mois, le mois en cours compris.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.state});

  final _DatesState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final selected = state.leg.value == _Leg.departure
        ? state.departure.value
        : state.returnDate.value;
    final out = state.departure.value;
    final months = [
      for (var i = 0; i < 12; i++)
        DateTime(state.today.year, state.today.month + i),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: DonySpacing.sm,
      crossAxisSpacing: DonySpacing.sm,
      childAspectRatio: 2.4,
      children: [
        for (final m in months)
          Builder(
            builder: (context) {
              final isSelected =
                  selected != null &&
                  selected.year == m.year &&
                  selected.month == m.month;
              final disabled =
                  state.leg.value == _Leg.returnLeg &&
                  out != null &&
                  DateTime(out.year, out.month).isAfter(m);
              return Opacity(
                opacity: disabled ? 0.4 : 1,
                child: Material(
                  color: isSelected ? cs.primary : cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    side: BorderSide(
                      color: isSelected ? cs.primary : cs.outline,
                    ),
                  ),
                  child: InkWell(
                    key: Key('flight-month-${m.year}-${m.month}'),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    onTap: disabled ? null : () => state.pick(m),
                    child: Center(
                      child: Text(
                        FlightFormat.month(l, m),
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ValidateButton extends StatelessWidget {
  const _ValidateButton({required this.state});

  final _DatesState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state.all,
      builder: (context, _) => DonyButton(
        key: const Key('flight-dates-validate'),
        label: context.l10n.flightsDatesValidate,
        onPressed: state.isValid
            ? () => Navigator.of(context).pop(state.choice)
            : null,
      ),
    );
  }
}
