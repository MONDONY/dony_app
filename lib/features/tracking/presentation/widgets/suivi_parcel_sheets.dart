import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validate_content.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Colis lu sur un autre trajet du voyageur. Rend `true` si l'utilisateur
/// choisit de passer sur ce trajet, `false`/`null` pour scanner autre chose.
Future<bool?> showSuiviOtherTripSheet(
  BuildContext context, {
  required BidModel bid,
  required AnnouncementModel trip,
}) {
  final l = context.l10n;
  return DonyBottomSheet.show<bool>(
    context,
    stickyBottom: _SheetActions(
      primaryKey: const Key('suivi-switch-trip'),
      primaryLabel: l.suiviSwitchToTrip,
    ),
    child: _ParcelNotice(
      title: l.suiviOtherTripTitle,
      body: l.suiviOtherTripBody(
        suiviParcelLabel(bid),
        suiviShortDate(l, trip.departureDate),
      ),
      trip: trip,
    ),
  );
}

/// Colis absent des trajets du voyageur. Rend `true` pour suivre son
/// parcours, `false`/`null` pour scanner autre chose.
Future<bool?> showSuiviUnknownParcelSheet(BuildContext context) {
  final l = context.l10n;
  return DonyBottomSheet.show<bool>(
    context,
    stickyBottom: _SheetActions(
      primaryKey: const Key('suivi-follow-parcel'),
      primaryLabel: l.suiviFollowParcel,
    ),
    child: _ParcelNotice(
      title: l.suiviUnknownParcelTitle,
      body: l.suiviUnknownParcelBody,
    ),
  );
}

class _ParcelNotice extends StatelessWidget {
  const _ParcelNotice({required this.title, required this.body, this.trip});

  final String title;
  final String body;

  /// Trajet du colis, affiché sous l'explication.
  final AnnouncementModel? trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: DonyColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: const DonyIcon('package', size: 22, color: DonyColors.accent),
        ),
        const SizedBox(height: DonySpacing.base),
        Text(title, style: tt.headlineMedium),
        const SizedBox(height: DonySpacing.sm),
        Text(
          body,
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (trip case final trip?) ...[
          const SizedBox(height: DonySpacing.md),
          RouteLabel(
            key: const Key('suivi-other-trip-route'),
            from: trip.departureCity,
            to: trip.arrivalCity,
            transportMode: trip.transportMode,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.primaryKey, required this.primaryLabel});

  final Key primaryKey;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: primaryKey,
          label: primaryLabel,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('suivi-scan-another'),
          label: context.l10n.suiviScanAnother,
          variant: DonyButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Récapitulatif d'un colis identifié par son numéro (QR illisible) :
/// trajet, étapes déjà faites, étape à valider. Rend `true` quand le
/// voyageur enchaîne sur la photo, obligatoire sans QR.
Future<bool?> showSuiviNumberRecapSheet(
  BuildContext context, {
  required BidModel bid,
  required AnnouncementModel trip,
  required String step,
}) {
  final l = context.l10n;
  return DonyBottomSheet.show<bool>(
    context,
    title: l.suiviNumberRecapTitle,
    stickyBottom: DonyButton(
      key: const Key('suivi-number-photo'),
      label: l.suiviPhotoAndValidate(step),
      iconAsset: 'camera',
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
    ),
    child: _NumberRecap(bid: bid, trip: trip, step: step),
  );
}

class _NumberRecap extends StatelessWidget {
  const _NumberRecap({
    required this.bid,
    required this.trip,
    required this.step,
  });

  final BidModel bid;
  final AnnouncementModel trip;
  final String step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final label = suiviParcelLabel(bid);
    final progress = colisStepProgress(bid);
    final done = [
      if (progress.depart) trackingStepLabel(l, 'DEPART'),
      if (progress.transit) trackingStepLabel(l, 'TRANSIT'),
    ];
    final weight = bid.weightKg;
    final details = [
      if (weight != null) formatWeightKg(l, weight),
      ?bid.trackingNumber,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyCard(
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.surfaceWarm,
                        child: Text(
                          label.characters.first.toUpperCase(),
                          style: tt.titleMedium?.copyWith(
                            color: DonyColors.terra800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.suiviParcelOf(label),
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (details.isNotEmpty)
                            Text(
                              details,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.base),
                _RecapRow(
                  label: l.suiviRecapTrip,
                  child: RouteLabel(
                    from: trip.departureCity,
                    to: trip.arrivalCity,
                    transportMode: trip.transportMode,
                    style: tt.bodyMedium,
                  ),
                ),
                _RecapRow(
                  label: l.suiviRecapDone,
                  value: done.isEmpty
                      ? l.suiviRecapNothingDone
                      : done.join(', '),
                ),
                _RecapRow(
                  label: l.suiviRecapToValidate,
                  value: trackingStepLabel(l, step),
                  strong: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceWarm,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DonyIcon('camera', size: 18, color: DonyColors.accent),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    l.suiviNumberPhotoNotice,
                    style: tt.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.label,
    this.value,
    this.child,
    this.strong = false,
  }) : assert((value == null) != (child == null));

  final String label;
  final String? value;

  /// Valeur composée (trajet), à la place de [value].
  final Widget? child;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            flex: 3,
            child:
                child ??
                Text(
                  value!,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: strong ? FontWeight.w700 : null,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// « Forcer une étape » : rattrapage d'un oubli. Rend l'étape choisie
/// (`DEPART`/`TRANSIT`/`ARRIVEE`), `null` si la feuille est fermée.
Future<String?> showSuiviForceStepSheet(BuildContext context) {
  final l = context.l10n;
  return DonyBottomSheet.show<String>(
    context,
    title: l.suiviForceStep,
    subtitle: l.suiviStepModeHelp,
    child: const _ForceStepChoices(),
  );
}

class _ForceStepChoices extends StatelessWidget {
  const _ForceStepChoices();

  // Codes d'étape envoyés au back, jamais affichés (i18n-ignore).
  static const _steps = ['DEPART', 'TRANSIT', 'ARRIVEE'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in _steps)
          InkWell(
            key: Key('suivi-force-$step'),
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            onTap: () => Navigator.of(context).pop(step),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trackingStepLabel(l, step), style: tt.titleMedium),
                        // Seul le transit est facultatif : départ et remise
                        // restent obligatoires.
                        if (step == 'TRANSIT')
                          Text(
                            l.trackingStepOptional,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DonyIcon(
                    'chevron-right',
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
