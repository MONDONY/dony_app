import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_sheets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// « Vous faites ce trajet souvent ? » sur l'écran de succès d'un trajet
/// direct : ouvre le calendrier du trajet récurrent.
///
/// [autoDates] non vide : la récurrence a été choisie à l'étape 1 du
/// formulaire, la série part dès l'affichage (publiée, pas en brouillons)
/// et la carte en montre l'avancement puis le résultat.
class TripSeriesCard extends StatelessWidget {
  const TripSeriesCard({
    super.key,
    required this.announcement,
    this.autoDates = const [],
  });

  final AnnouncementModel announcement;
  final List<DateTime> autoDates;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TripSeriesCubit>(param1: announcement);
        if (autoDates.isNotEmpty) unawaited(cubit.submitDates(autoDates));
        return cubit;
      },
      child: const _CardBody(),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<TripSeriesCubit, TripSeriesState>(
      buildWhen: (p, c) => p.status != c.status || p.result != c.result,
      builder: (context, state) {
        final done = state.status == TripSeriesStatus.done;
        final busy = state.status == TripSeriesStatus.submitting;
        final failedCount = state.result?.failed.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: DonyIcon(
                      done ? 'check' : 'calendar-sync',
                      size: 20,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          done
                              ? l10n.tripSeriesCardDone(
                                  state.result?.created.length ?? 0,
                                )
                              : busy
                              ? l10n.tripRecurrenceSeriesPublishing(
                                  state.selected.length,
                                )
                              : l10n.tripSeriesCardTitle,
                          key: const Key('trip-series-card-title'),
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!done && !busy) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            l10n.tripSeriesCardBody,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        // Échec de la série : le motif, puis le calendrier
                        // reste proposé, dates gardées.
                        if (state.status == TripSeriesStatus.failed) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            tripSeriesErrorText(context, state.errorCode),
                            key: const Key('trip-series-card-error'),
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ],
                        if (done && failedCount > 0) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            '${l10n.tripSeriesSomeFailed(failedCount)} '
                            '${tripSeriesErrorText(context, state.result!.failed.first.code)}',
                            key: const Key('trip-series-card-partial'),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: DonySpacing.md),
                  child: LinearProgressIndicator(
                    key: Key('trip-series-card-progress'),
                  ),
                )
              else if (!done) ...[
                const SizedBox(height: DonySpacing.md),
                DonyButton(
                  key: const Key('trip-series-open'),
                  label: l10n.tripSeriesCardCta,
                  iconAsset: 'calendar',
                  onPressed: () => TripSeriesFlow.start(
                    context,
                    context.read<TripSeriesCubit>(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
