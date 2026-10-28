import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_photo_viewer.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// [position] : une ville approximative du voyageur, entre deux étapes.
enum JourneyStepState { done, current, upcoming, position }

/// Une ligne de la frise.
class JourneyStep {
  const JourneyStep(this.state, this.title, {this.event, this.at, this.note});

  final JourneyStepState state;
  final String title;

  /// Heure d'une ville approximative ([JourneyStepState.position]).
  final DateTime? at;

  /// Marque sous la ville : « Maintenant » ou « Dernière position, … ».
  final String? note;

  /// Événement enregistré d'une étape faite : heure, lieu, provenance, photo.
  final TrackingEventModel? event;
}

/// Étapes faites ([sorted], par heure) et villes du voyageur, dans l'ordre du
/// temps. Une ville sans heure ne peut pas être placée : elle est ignorée.
List<JourneyStep> mergedDoneSteps(
  AppLocalizations l,
  List<TrackingEventModel> sorted,
  TravelerTrackingModel? tracking,
  DateTime now,
) {
  final entries = <(DateTime, int, JourneyStep)>[
    for (final event in sorted)
      (
        event.scannedAt,
        0,
        JourneyStep(
          JourneyStepState.done,
          doneStepTitle(l, event),
          event: event,
        ),
      ),
  ];
  if (tracking != null && tracking.history.isNotEmpty) {
    final last = tracking.history.last;
    for (final point in tracking.history) {
      final at = point.at;
      if (at == null) continue;
      String? note;
      if (identical(point, last)) {
        note = switch (tracking.status) {
          TravelerTrackingStatus.enRoute => l.travelerTrackingNow,
          TravelerTrackingStatus.stale => l.travelerTrackingLastPosition(
            travelerTrackingAge(
              l,
              (tracking.lastUpdatedAt ?? at).toLocal(),
              now,
            ),
          ),
          _ => null,
        };
      }
      entries.add((
        at,
        1,
        JourneyStep(
          JourneyStepState.position,
          l.travelerTrackingNearCity(point.city),
          at: at,
          note: note,
        ),
      ));
    }
  }
  // Tri par heure, puis étape avant ville ; List.sort n'étant pas stable,
  // l'ordre d'origine départage deux villes de même heure.
  final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])]
    ..sort((a, b) {
      final byTime = a.$2.$1.compareTo(b.$2.$1);
      if (byTime != 0) return byTime;
      final byKind = a.$2.$2.compareTo(b.$2.$2);
      return byKind != 0 ? byKind : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2.$3];
}

String doneStepTitle(AppLocalizations l, TrackingEventModel event) =>
    switch (event.eventType) {
      'DEPART' => l.trackingStepHandedToTraveler,
      'ARRIVEE' => l.trackingStepHandedToRecipient,
      _ => trackingStepLabel(l, event.eventType),
    };

/// Frise compacte de la carte « Suivi du voyageur » : toutes les étapes faites
/// (remise, transit, arrivée, remise au destinataire) et au plus
/// [maxCities] villes approximatives, les plus récentes, dans l'ordre du
/// temps. [arrived] ajoute « Arrivé » quand le voyageur a déclaré son arrivée
/// sans scan (le colis est `ARRIVED`).
List<JourneyStep> compactJourneySteps(
  AppLocalizations l,
  List<TrackingEventModel> events, {
  TravelerTrackingModel? tracking,
  required DateTime now,
  bool arrived = false,
  int maxCities = 3,
}) {
  final sorted = [...events]
    ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
  final merged = mergedDoneSteps(l, sorted, tracking, now);
  final cityCount = merged
      .where((s) => s.state == JourneyStepState.position)
      .length;
  var skip = cityCount - maxCities;
  final steps = <JourneyStep>[
    for (final step in merged)
      if (step.state != JourneyStepState.position || skip-- <= 0) step,
  ];
  final departed = sorted.any((e) => e.eventType == 'DEPART');
  final delivered = sorted.any((e) => e.eventType == 'ARRIVEE');
  if (arrived && departed && !delivered) {
    steps.add(
      JourneyStep(JourneyStepState.done, l.trackingStepArrivedAtDestination),
    );
  }
  return steps;
}

/// Une ligne de la frise : repère, titre, heure, lieu, photo (ou mention de
/// photo supprimée). Partagée par la feuille du parcours et la carte « Suivi
/// du voyageur ».
class JourneyRow extends StatelessWidget {
  const JourneyRow({super.key, required this.step, required this.connector});

  final JourneyStep step;

  /// Couleur du trait vers l'étape suivante, `null` pour la dernière.
  final Color? connector;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final event = step.event;
    final line = connector;
    final time = event?.scannedAt ?? step.at;
    final details = event == null
        ? ''
        : [?event.locationLabel(l), ?event.methodLabel(l)].join(' · ');
    final photo = event?.photoUrl;
    final photoPurged = event?.photoPurged ?? false;

    final Widget marker = switch (step.state) {
      JourneyStepState.done => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: DonyIcon('check', size: 12, color: cs.onPrimary),
      ),
      JourneyStepState.current => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surface,
          shape: BoxShape.circle,
          border: Border.all(color: cs.secondary, width: 2),
          boxShadow: [
            BoxShadow(
              color: cs.secondary.withValues(alpha: 0.15),
              spreadRadius: 5,
            ),
          ],
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: cs.secondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      JourneyStepState.upcoming => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline, width: 2),
        ),
      ),
      // Ville approximative : simple point, moins lourd qu'une étape.
      JourneyStepState.position => SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    };

    return IntrinsicHeight(
      key: Key('tracking-step-${step.state.name}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                ExcludeSemantics(child: marker),
                if (line != null)
                  Expanded(child: Container(width: 2, color: line)),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: line == null ? 0 : DonySpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: step.state == JourneyStepState.current
                                ? FontWeight.w700
                                : null,
                            color: step.state == JourneyStepState.upcoming
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: DonySpacing.sm),
                        Text(
                          DateFormat.MMMd(
                            l.localeName,
                          ).add_Hm().format(time.toLocal()),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (step.note != null) ...[
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      step.note!,
                      key: const Key('tracking-step-note'),
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      details,
                      key: event?.scanMethod != null
                          ? const Key('tracking-step-method')
                          : null,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  if (photoPurged) ...[
                    const SizedBox(height: DonySpacing.sm),
                    // Photo supprimée par le serveur après la livraison :
                    // vignette neutre explicative, rien à ouvrir.
                    Container(
                      key: const Key('tracking-step-photo-purged'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceWarm,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          Flexible(
                            child: Text(
                              l.trackingPhotoPurged,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (photo != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    // Miniature touchable : la photo s'ouvre en plein écran,
                    // zoomable (FLUTTER-82, elle ne s'agrandissait pas).
                    Semantics(
                      image: true,
                      button: true,
                      label: l.trackingStepPhotoLabel,
                      hint: l.trackingStepPhotoOpen,
                      child: GestureDetector(
                        key: const Key('tracking-step-photo'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            RequestPhotoViewer.show(context, urls: [photo]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                          child: DonyImage(
                            url: photo,
                            width: 64,
                            height: 64,
                            placeholder: (_) => ColoredBox(
                              color: cs.surfaceWarm,
                              child: const SizedBox(width: 64, height: 64),
                            ),
                            errorWidget: (_) => Container(
                              width: 64,
                              height: 64,
                              color: cs.surfaceWarm,
                              alignment: Alignment.center,
                              child: DonyIcon(
                                'image-off',
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
