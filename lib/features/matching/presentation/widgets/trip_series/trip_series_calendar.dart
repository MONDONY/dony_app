import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Grille d'un mois où l'on coche des jours précis : le jour du trajet
/// d'origine est entouré (non cochable), les jours passés sont grisés.
class TripSeriesCalendar extends StatelessWidget {
  const TripSeriesCalendar({super.key});

  static const _cell = 44.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripSeriesCubit>();
    final state = context.watch<TripSeriesCubit>().state;
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final material = MaterialLocalizations.of(context);
    final month = state.visibleMonth;
    final label = DateFormat.yMMMM(l10n.localeName).format(month);
    final firstWeekday = material.firstDayOfWeekIndex;
    final weekdays = [
      for (var i = 0; i < 7; i++)
        material.narrowWeekdays[(firstWeekday + i) % 7],
    ];
    final leading = (month.weekday % 7 - firstWeekday + 7) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('trip-series-prev-month'),
              tooltip: l10n.tripSeriesPrevMonth,
              onPressed: cubit.canGoBack ? () => cubit.showMonth(-1) : null,
              icon: RotatedBox(
                quarterTurns: 2,
                child: DonyIcon('chevron-right', size: 20, color: cs.primary),
              ),
            ),
            Expanded(
              child: Text(
                toBeginningOfSentenceCase(label),
                textAlign: TextAlign.center,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              key: const Key('trip-series-next-month'),
              tooltip: l10n.tripSeriesNextMonth,
              onPressed: cubit.canGoForward ? () => cubit.showMonth(1) : null,
              icon: DonyIcon('chevron-right', size: 20, color: cs.primary),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            children: [
              for (final day in cells.sublist(row * 7, row * 7 + 7))
                Expanded(
                  child: SizedBox(
                    height: _cell,
                    child: day == null
                        ? null
                        : _DayCell(
                            day: day,
                            selected: state.selected.contains(day),
                            isSource: day == cubit.sourceDay,
                            selectable: cubit.isSelectable(day),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isSource,
    required this.selectable,
  });

  final DateTime day;
  final bool selected;
  final bool isSource;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = Text(
      '${day.day}',
      style: tt.bodyMedium?.copyWith(
        fontWeight: selected || isSource ? FontWeight.w800 : FontWeight.w500,
        color: selected
            ? cs.onPrimary
            : isSource
            ? cs.primary
            : cs.onSurface,
      ),
    );
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? cs.primary : null,
      border: isSource ? Border.all(color: cs.primary, width: 2) : null,
    );
    final cell = Center(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: decoration,
        child: text,
      ),
    );
    if (!selectable) {
      return Semantics(
        label: DateFormat.yMMMMd(context.l10n.localeName).format(day),
        child: Opacity(opacity: isSource ? 1 : 0.4, child: cell),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat.yMMMMd(context.l10n.localeName).format(day),
      child: InkWell(
        key: Key('trip-series-day-${TripSeriesResult.wireDate(day)}'),
        customBorder: const CircleBorder(),
        onTap: () => context.read<TripSeriesCubit>().toggle(day),
        child: cell,
      ),
    );
  }
}
