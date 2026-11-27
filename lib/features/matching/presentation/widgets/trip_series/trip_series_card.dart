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
    this.compact = false,
  });

  final AnnouncementModel announcement;
  final List<DateTime> autoDates;

  /// Ligne de liste sans fond ni bordure (« Et maintenant ? » de l'écran de
  /// succès) au lieu de la carte : libellé court, une précision, un chevron.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TripSeriesCubit>(param1: announcement);
        if (autoDates.isNotEmpty) unawaited(cubit.submitDates(autoDates));
        return cubit;
      },
      child: compact
          ? _CompactRow(auto: autoDates.isNotEmpty)
          : _CardBody(auto: autoDates.isNotEmpty),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.auto});

  /// Série partie d'elle-même (récurrence de l'étape 1) : son échec ou son
  /// résultat partiel s'affiche sur la carte. Ouverte au calendrier, c'est
  /// la feuille qui les montre.
  final bool auto;

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
                        if (auto &&
                            state.status == TripSeriesStatus.failed) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            tripSeriesErrorText(context, state.errorCode),
                            key: const Key('trip-series-card-error'),
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ],
                        if (auto && done && failedCount > 0) ...[
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

/// Version ligne de liste de la carte : même cubit, mêmes états (en cours,
/// terminé, échec), présentés sur une ligne qui ouvre le calendrier.
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.auto});

  final bool auto;

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
        final title = done
            ? l10n.tripSeriesCardDone(state.result?.created.length ?? 0)
            : busy
            ? l10n.tripRecurrenceSeriesPublishing(state.selected.length)
            : l10n.tripSeriesCardCta;
        String? detail;
        Color? detailColor;
        if (auto && state.status == TripSeriesStatus.failed) {
          detail = tripSeriesErrorText(context, state.errorCode);
          detailColor = cs.error;
        } else if (auto && done && failedCount > 0) {
          detail =
              '${l10n.tripSeriesSomeFailed(failedCount)} '
              '${tripSeriesErrorText(context, state.result!.failed.first.code)}';
        } else if (!done && !busy) {
          detail = l10n.tripSeriesCardHint;
        }
        final tappable = !done && !busy;
        return Semantics(
          button: tappable,
          child: InkWell(
            key: const Key('trip-series-open'),
            onTap: tappable
                ? () => TripSeriesFlow.start(
                    context,
                    context.read<TripSeriesCubit>(),
                  )
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                  vertical: DonySpacing.sm,
                ),
                child: Row(
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
                            title,
                            key: const Key('trip-series-card-title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.only(top: DonySpacing.xs),
                              child: LinearProgressIndicator(
                                key: Key('trip-series-card-progress'),
                              ),
                            )
                          else if (detail != null)
                            Text(
                              detail,
                              key: auto && done
                                  ? const Key('trip-series-card-partial')
                                  : auto &&
                                        state.status == TripSeriesStatus.failed
                                  ? const Key('trip-series-card-error')
                                  : null,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: detailColor ?? cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (tappable) ...[
                      const SizedBox(width: DonySpacing.sm),
                      DonyIcon(
                        'chevron-right',
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
