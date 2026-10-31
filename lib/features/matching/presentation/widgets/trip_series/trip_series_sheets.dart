import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_calendar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Texte d'un refus de série, par code métier du back.
String tripSeriesErrorText(BuildContext context, String? code) {
  final l10n = context.l10n;
  return switch (code) {
    'draft-limit-reached' => l10n.tripSeriesErrorDraftLimit,
    'kyc-not-verified' => l10n.tripSeriesErrorKyc,
    'pro-limit-reached' => l10n.tripSeriesErrorProLimit,
    'stripe-onboarding-incomplete' => l10n.tripSeriesErrorStripe,
    _ => l10n.tripSeriesErrorGeneric,
  };
}

/// Calendrier du trajet récurrent puis, si des trajets ont été créés, offre
/// d'en faire un modèle. Le cubit appartient à l'appelant (carte de l'écran
/// de succès, menu ⋮ de l'écran du trajet), qui reflète le résultat et le
/// ferme.
abstract final class TripSeriesFlow {
  static Future<void> start(BuildContext context, TripSeriesCubit cubit) async {
    cubit.trackOpened();
    final a = cubit.announcement;
    final created = await DonyBottomSheet.show<bool>(
      context,
      title: context.l10n.tripSeriesSheetTitle,
      analyticsName: 'trip-series/calendar',
      subtitle: context.l10n.tripSeriesSheetSubtitle(
        a.departureCity,
        a.arrivalCity,
      ),
      wrapper: (child) => BlocProvider.value(value: cubit, child: child),
      stickyBottom: const _SeriesButtons(),
      child: const _SeriesBody(),
    );
    if (created != true || !context.mounted) return;
    await _offerTemplate(context, cubit, canSkip: true);
  }

  /// Feuille du modèle seule, sans calendrier : « Enregistrer en modèle » du
  /// menu ⋮ de l'écran du trajet. Le voyageur l'a demandée, donc pas de
  /// « Non merci » (le geste de fermeture suffit).
  static Future<void> saveTemplate(
    BuildContext context,
    TripSeriesCubit cubit,
  ) => _offerTemplate(context, cubit, canSkip: false);

  static Future<void> _offerTemplate(
    BuildContext context,
    TripSeriesCubit cubit, {
    required bool canSkip,
  }) async {
    final saved = await DonyBottomSheet.show<bool>(
      context,
      analyticsName: 'trip-series/template',
      wrapper: (child) => BlocProvider.value(value: cubit, child: child),
      stickyBottom: _TemplateButtons(canSkip: canSkip),
      child: const _TemplateOffer(),
    );
    if (saved == true && context.mounted) {
      DonySnackbar.show(
        context,
        message: context.l10n.tripTemplateSaved,
        type: DonySnackbarType.success,
      );
    }
  }
}

class _SeriesBody extends StatelessWidget {
  const _SeriesBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<TripSeriesCubit>();
    return BlocConsumer<TripSeriesCubit, TripSeriesState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == TripSeriesStatus.done) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final full = state.selected.length >= TripSeriesCubit.maxDates;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TripSeriesCalendar(),
            const SizedBox(height: DonySpacing.md),
            Container(
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 2),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.tripSeriesSourceLegend(
                        DateFormat.MMMd(
                          l10n.localeName,
                        ).format(cubit.announcement.departureDate),
                      ),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            if (full) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                l10n.tripSeriesMaxHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (state.status == TripSeriesStatus.failed) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                tripSeriesErrorText(context, state.errorCode),
                key: const Key('trip-series-error'),
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SeriesButtons extends StatelessWidget {
  const _SeriesButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<TripSeriesCubit, TripSeriesState>(
      builder: (context, state) {
        final cubit = context.read<TripSeriesCubit>();
        final n = state.selected.length;
        final busy = state.status == TripSeriesStatus.submitting;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              key: const Key('trip-series-publish'),
              label: n == 0
                  ? l10n.tripSeriesPickDates
                  : l10n.tripSeriesPublishCta(n),
              isLoading: busy && !state.draft,
              onPressed: n == 0 || busy
                  ? null
                  : () => cubit.submit(draft: false),
            ),
            if (n > 0) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('trip-series-drafts'),
                label: l10n.tripSeriesDraftCta(n),
                variant: DonyButtonVariant.secondary,
                isLoading: busy && state.draft,
                onPressed: busy ? null : () => cubit.submit(draft: true),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TemplateOffer extends StatefulWidget {
  const _TemplateOffer();

  @override
  State<_TemplateOffer> createState() => _TemplateOfferState();
}

class _TemplateOfferState extends State<_TemplateOffer> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<TripSeriesCubit>().templateName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<TripSeriesCubit, TripSeriesState>(
      listenWhen: (p, c) => p.templateStatus != c.templateStatus,
      listener: (context, state) {
        if (state.templateStatus == TripSeriesTemplateStatus.saved) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final result = state.result;
        final created = result?.created.length ?? 0;
        final failed = result?.failed.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sans série (feuille ouverte seule, depuis le menu ⋮), pas de
            // pastille « N trajets publiés ».
            if (result != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                    vertical: DonySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.lg),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DonyIcon('check', size: 14, color: cs.primary),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        state.draft
                            ? l10n.tripSeriesBadgeDrafts(created)
                            : l10n.tripSeriesBadgePublished(created),
                        key: const Key('trip-series-badge'),
                        style: tt.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (failed > 0) ...[
                const SizedBox(height: DonySpacing.sm),
                Text(
                  '${l10n.tripSeriesSomeFailed(failed)} '
                  '${tripSeriesErrorText(context, result.failed.first.code)}',
                  key: const Key('trip-series-partial'),
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: DonySpacing.lg),
            ],
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                ),
                alignment: Alignment.center,
                child: DonyIcon('bookmark', size: 28, color: cs.primary),
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l10n.tripTemplateOfferTitle,
              textAlign: TextAlign.center,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              l10n.tripTemplateOfferBody,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.lg),
            DonyTextField(
              key: const Key('trip-template-name'),
              controller: _name,
              label: l10n.tripTemplateNameLabel,
              onChanged: context.read<TripSeriesCubit>().setTemplateName,
              textInputAction: TextInputAction.done,
            ),
            if (state.templateStatus == TripSeriesTemplateStatus.failed) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                l10n.tripTemplateSaveFailed,
                key: const Key('trip-template-error'),
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TemplateButtons extends StatelessWidget {
  const _TemplateButtons({required this.canSkip});

  /// « Non merci » sous le bouton : offre faite après une série, pas
  /// demandée.
  final bool canSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<TripSeriesCubit, TripSeriesState>(
      buildWhen: (p, c) => p.templateStatus != c.templateStatus,
      builder: (context, state) {
        final saving = state.templateStatus == TripSeriesTemplateStatus.saving;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              key: const Key('trip-template-save'),
              label: l10n.tripTemplateSaveCta,
              isLoading: saving,
              onPressed: saving
                  ? null
                  : context.read<TripSeriesCubit>().saveTemplate,
            ),
            if (canSkip) ...[
              const SizedBox(height: DonySpacing.xs),
              DonyButton(
                key: const Key('trip-template-skip'),
                label: l10n.tripTemplateSkip,
                variant: DonyButtonVariant.ghost,
                onPressed: saving
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ],
          ],
        );
      },
    );
  }
}
