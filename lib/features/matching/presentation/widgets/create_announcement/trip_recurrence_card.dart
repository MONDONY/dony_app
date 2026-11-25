// Récurrence d'un trajet choisie à l'étape 1 de « Publier un trajet ».
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_recurrence_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_calendar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Carte « Vous faites ce trajet souvent ? » : interrupteur éteint par
/// défaut ; allumé, rythme, prochaines dates, compteur et « Choisir les
/// dates ». La série est créée après la publication du trajet.
///
/// [multiLeg] : des étapes de voyage ont été ajoutées, la récurrence n'est
/// pas proposée (explication à la place de l'interrupteur).
class TripRecurrenceCard extends StatelessWidget {
  const TripRecurrenceCard({super.key, this.multiLeg = false});

  final bool multiLeg;

  static String frequencyLabel(AppLocalizations l, TripRecurrenceFrequency f) =>
      switch (f) {
        TripRecurrenceFrequency.weekly => l.tripRecurrenceWeekly,
        TripRecurrenceFrequency.biweekly => l.tripRecurrenceBiweekly,
        TripRecurrenceFrequency.monthly => l.tripRecurrenceMonthly,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return BlocBuilder<TripRecurrenceCubit, TripRecurrenceState>(
      builder: (context, state) {
        final cubit = context.read<TripRecurrenceCubit>();
        final on = state.enabled && !multiLeg;
        return AnimatedContainer(
          key: const Key('trip-recurrence-card'),
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: on ? cs.primary : cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MergeSemantics(
                child: Row(
                  children: [
                    DonyIcon('calendar-sync', size: 20, color: cs.primary),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.tripSeriesCardTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            multiLeg
                                ? l.tripRecurrenceMultiLegHint
                                : l.tripRecurrenceSubtitle,
                            key: multiLeg
                                ? const Key('trip-recurrence-multileg-hint')
                                : null,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!multiLeg) ...[
                      const SizedBox(width: DonySpacing.sm),
                      Switch(
                        key: const Key('trip-recurrence-switch'),
                        value: state.enabled,
                        onChanged: cubit.setEnabled,
                      ),
                    ],
                  ],
                ),
              ),
              if (on) ..._details(context, state, cubit),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _details(
    BuildContext context,
    TripRecurrenceState state,
    TripRecurrenceCubit cubit,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return [
      const SizedBox(height: DonySpacing.md),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.xs,
        children: [
          for (final f in TripRecurrenceFrequency.values)
            ChoiceChip(
              key: Key('trip-recurrence-${f.wire}'),
              label: Text(frequencyLabel(l, f), maxLines: 1, softWrap: false),
              selected: !state.customized && state.frequency == f,
              onSelected: (_) => cubit.chooseFrequency(f),
            ),
        ],
      ),
      const SizedBox(height: DonySpacing.md),
      if (state.departureDate == null)
        Text(
          l.tripRecurrencePickDateFirst,
          key: const Key('trip-recurrence-pick-date-first'),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        )
      else ...[
        Text(
          l.tripRecurrenceCount(state.totalTrips),
          key: const Key('trip-recurrence-count'),
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Wrap(
          spacing: DonySpacing.xs,
          runSpacing: DonySpacing.xs,
          children: [
            for (final d in [state.departureDate!, ...state.dates])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  DateFormat.MMMd(l.localeName).format(d),
                  style: tt.labelLarge?.copyWith(color: cs.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('trip-recurrence-choose-dates'),
            onPressed: () => TripRecurrenceDatesSheet.show(context, cubit),
            icon: DonyIcon('calendar', size: 16, color: cs.primary),
            label: Text(
              l.tripRecurrenceChooseDates,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ],
    ];
  }
}

/// Calendrier « Choisir les dates » de la récurrence : un toucher ajoute ou
/// retire un jour, le premier trajet est entouré.
abstract final class TripRecurrenceDatesSheet {
  static Future<void> show(BuildContext context, TripRecurrenceCubit cubit) {
    cubit.customDatesOpened();
    final l = context.l10n;
    final first = cubit.state.departureDate;
    return DonyBottomSheet.show<void>(
      context,
      title: l.tripRecurrenceDatesSheetTitle,
      subtitle: first == null
          ? null
          : l.tripRecurrenceDatesSheetSubtitle(
              DateFormat.MMMMd(l.localeName).format(first),
            ),
      analyticsName: 'trip-create/recurrence-dates',
      wrapper: (child) => BlocProvider.value(value: cubit, child: child),
      stickyBottom: Builder(
        builder: (context) => DonyButton(
          key: const Key('trip-recurrence-dates-done'),
          label: context.l10n.tripRecurrenceDatesDone,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: const _DatesBody(),
    );
  }
}

class _DatesBody extends StatelessWidget {
  const _DatesBody();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<TripRecurrenceCubit, TripRecurrenceState>(
      builder: (context, state) {
        final cubit = context.read<TripRecurrenceCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripSeriesCalendar(
              visibleMonth: state.visibleMonth,
              selected: state.dates,
              sourceDay: cubit.sourceDay,
              isSelectable: cubit.isSelectable,
              onToggle: cubit.toggleDate,
              canGoBack: cubit.canGoBack,
              canGoForward: cubit.canGoForward,
              onShowMonth: cubit.showMonth,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              context.l10n.tripRecurrenceCount(state.totalTrips),
              key: const Key('trip-recurrence-sheet-count'),
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }
}
