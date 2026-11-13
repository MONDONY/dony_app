import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/arrival_range.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_delay_labels.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_photo_viewer.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/data/models/trip_milestones.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// [position] : une ville approximative du voyageur, entre deux étapes.
enum JourneyStepState { done, current, upcoming, position }

/// Une ligne de la frise.
class JourneyStep {
  const JourneyStep(
    this.state,
    this.title, {
    this.event,
    this.at,
    this.note,
    this.detail,
    this.dateOnly = false,
  });

  final JourneyStepState state;
  final String title;

  /// Heure d'une ville approximative ([JourneyStepState.position]), ou jour
  /// d'un jalon du trajet ([dateOnly]).
  final DateTime? at;

  /// [at] est un jour du calendrier (jalon du trajet : « 2 déc. ») : affiché
  /// sans heure ni conversion de fuseau.
  final bool dateOnly;

  /// Marque sous la ville : « Maintenant » ou « Dernière position, … ».
  final String? note;

  /// Précision sous un jalon du trajet sans événement enregistré (« Estimé
  /// du 11 au 18 janv. », dernier retard annoncé).
  final String? detail;

  /// Événement enregistré d'une étape faite : heure, lieu, provenance, photo.
  final TrackingEventModel? event;
}

/// Étapes faites ([sorted], par heure) et villes du voyageur, dans l'ordre du
/// temps. Une ville sans heure ne peut pas être placée : elle est ignorée.
/// [mode] : mode du trajet, qui nomme les étapes ([doneStepTitle]).
List<JourneyStep> mergedDoneSteps(
  AppLocalizations l,
  List<TrackingEventModel> sorted,
  TravelerTrackingModel? tracking,
  DateTime now, {
  TransportMode? mode,
}) {
  final entries = <(DateTime, int, JourneyStep)>[
    for (final event in sorted)
      (
        event.scannedAt,
        0,
        JourneyStep(
          JourneyStepState.done,
          doneStepTitle(l, event, mode: mode),
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

/// Titre d'une étape faite. En bateau, la remise (`DEPART`) est le dépôt à
/// l'entrepôt ; tout autre mode (avion, route, inconnu) garde les libellés
/// neutres.
String doneStepTitle(
  AppLocalizations l,
  TrackingEventModel event, {
  TransportMode? mode,
}) => switch (event.eventType) {
  'DEPART' when mode == TransportMode.boat => l.trackingBoatStepDeposited,
  'DEPART' => l.trackingStepHandedToTraveler,
  'ARRIVEE' => l.trackingStepHandedToRecipient,
  _ => trackingStepLabel(l, event.eventType, mode: mode),
};

/// Frise compacte de la carte « Suivi du voyageur » : toutes les étapes faites
/// (remise, transit, arrivée, remise au destinataire) et au plus
/// [maxCities] villes approximatives, les plus récentes, dans l'ordre du
/// temps. [arrived] ajoute « Arrivé » quand le voyageur a déclaré son arrivée
/// sans scan (le colis est `ARRIVED`) ; en bateau, « Arrivé au port de
/// [arrivalCity] ».
List<JourneyStep> compactJourneySteps(
  AppLocalizations l,
  List<TrackingEventModel> events, {
  TravelerTrackingModel? tracking,
  required DateTime now,
  bool arrived = false,
  int maxCities = 3,
  TransportMode? mode,
  String? arrivalCity,
}) {
  final sorted = [...events]
    ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
  final merged = mergedDoneSteps(l, sorted, tracking, now, mode: mode);
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
      JourneyStep(
        JourneyStepState.done,
        mode == TransportMode.boat
            ? boatPortArrivalLabel(l, arrivalCity)
            : l.trackingStepArrivedAtDestination,
      ),
    );
  }
  return steps;
}

/// Avancement d'un colis bateau, lu sur ses étapes scannées, son statut et
/// les jalons du trajet.
typedef BoatJourneyProgress = ({
  bool deposited,
  bool departed,
  bool atPort,
  bool delivered,
});

/// Où en est un colis bateau.
///
/// - Remis au destinataire : étape `ARRIVEE` scannée.
/// - Arrivé au port : remis, ou trajet marqué arrivé (colis `ARRIVED`).
/// - Bateau parti : arrivé, transit scanné, colis `IN_TRANSIT`, retard annoncé
///   (le transporteur ne peut l'annoncer qu'une fois parti) ou départ prévu
///   passé pour un colis déposé.
/// - Déposé : dépôt (`DEPART`) scanné, ou bateau parti.
BoatJourneyProgress boatJourneyProgress(
  List<TrackingEventModel> events, {
  String? bidStatus,
  TripMilestones? milestones,
  required DateTime now,
}) {
  bool scanned(String type) => events.any((e) => e.eventType == type);
  final delivered = scanned('ARRIVEE');
  final atPort = delivered || bidStatus == 'ARRIVED';
  final depositScanned = scanned('DEPART');
  final departed =
      atPort ||
      scanned('TRANSIT') ||
      bidStatus == 'IN_TRANSIT' ||
      milestones?.latestDelay != null ||
      (depositScanned && (milestones?.departurePassed(now) ?? false));
  return (
    deposited: depositScanned || departed,
    departed: departed,
    atPort: atPort,
    delivered: delivered,
  );
}

/// Phrase d'état de la frise d'un colis bateau (maquette FriseMer).
String boatJourneyHeadline(
  AppLocalizations l,
  BoatJourneyProgress progress,
  String? arrivalCity,
) {
  if (progress.delivered) return l.trackingHeadlineDelivered;
  if (progress.atPort) return boatPortArrivalLabel(l, arrivalCity);
  if (progress.departed) {
    final city = arrivalCity?.trim() ?? '';
    return city.isEmpty
        ? l.trackingBoatStepAtSea
        : l.trackingBoatHeadlineAtSeaTo(city);
  }
  if (progress.deposited) return l.trackingBoatStepDeposited;
  return l.trackingBoatHeadlineAwaitingDeposit;
}

/// Frise d'un colis bateau (maquette FriseMer) : « Déposé à l'entrepôt »
/// (étape `DEPART`), « Bateau parti » (départ du trajet), « En mer » (en cours,
/// avec le dernier retard annoncé), « Arrivé au port de … » (arrivée estimée
/// du … au …), puis la remise au destinataire. Les jalons du trajet
/// s'intercalent entre les étapes scannées du colis, dans l'ordre du voyage ;
/// les transits scannés suivent le départ du bateau.
///
/// Jamais les villes approximatives du voyageur : la position d'un bateau se
/// lit sur ses jalons et ses retards, pas sur un téléphone.
List<JourneyStep> boatJourneySteps(
  AppLocalizations l,
  List<TrackingEventModel> events, {
  String? bidStatus,
  TripMilestones? milestones,
  String? departureCity,
  String? arrivalCity,
  required DateTime now,
}) {
  const mode = TransportMode.boat;
  final sorted = [...events]
    ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
  final progress = boatJourneyProgress(
    sorted,
    bidStatus: bidStatus,
    milestones: milestones,
    now: now,
  );
  JourneyStep done(TrackingEventModel event) => JourneyStep(
    JourneyStepState.done,
    doneStepTitle(l, event, mode: mode),
    event: event,
  );
  final deposits = sorted.where((e) => e.eventType == 'DEPART');
  final deliveries = sorted.where((e) => e.eventType == 'ARRIVEE');
  final onTheWay = sorted.where(
    (e) => e.eventType != 'DEPART' && e.eventType != 'ARRIVEE',
  );
  final from = departureCity?.trim();
  final departureCityLabel = from == null || from.isEmpty ? null : from;

  // Jour du départ prévu : la date du trajet, sinon le jour de son instant.
  final departureDay =
      milestones?.departureDate ?? milestones?.departureAt?.toLocal();
  final days = departureDay == null
      ? null
      : arrivalRangeDays(l, departureDay, null, now: now).from;

  final delay = milestones?.latestDelay;
  final delayNote = delay == null
      ? null
      : l.trackingBoatDelayNote(
          delay.message?.trim() ?? tripDelayInfoReasonLabel(l, delay, mode),
        );

  final earliest = milestones?.estimatedArrival;
  String? estimate;
  if (earliest != null) {
    final range = arrivalRangeDays(
      l,
      earliest,
      milestones?.estimatedArrivalMax,
      now: now,
    );
    final to = range.to;
    estimate = to == null
        ? l.trackingBoatEstimatedDate(range.from)
        : l.trackingBoatEstimatedRange(range.from, to);
  }
  final port = boatPortArrivalLabel(l, arrivalCity);

  return [
    // Dépôt à l'entrepôt.
    if (deposits.isNotEmpty)
      ...deposits.map(done)
    else if (progress.deposited)
      JourneyStep(JourneyStepState.done, l.trackingBoatStepDeposited)
    else
      JourneyStep(
        JourneyStepState.current,
        l.trackingBoatStepDeposit,
        detail: departureCityLabel,
      ),
    // Départ du bateau, jalon du trajet.
    if (progress.departed)
      JourneyStep(
        JourneyStepState.done,
        l.trackingBoatStepDeparted,
        at: departureDay,
        dateOnly: true,
        detail: departureCityLabel,
      )
    else
      JourneyStep(
        progress.deposited
            ? JourneyStepState.current
            : JourneyStepState.upcoming,
        l.trackingBoatStepDeparture,
        detail: days == null ? null : l.trackingBoatPlannedDeparture(days),
      ),
    // Transits scannés, une fois parti.
    ...onTheWay.map(done),
    if (progress.departed && !progress.atPort)
      JourneyStep(
        JourneyStepState.current,
        l.trackingBoatStepAtSea,
        detail: delayNote,
      ),
    // Arrivée au port, jalon du trajet.
    if (progress.atPort)
      JourneyStep(JourneyStepState.done, port)
    else
      JourneyStep(JourneyStepState.upcoming, port, detail: estimate),
    // Remise au destinataire.
    if (deliveries.isNotEmpty)
      ...deliveries.map(done)
    else
      JourneyStep(
        progress.atPort ? JourneyStepState.current : JourneyStepState.upcoming,
        l.trackingStepHandoverToRecipient,
      ),
  ];
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
    // Jalon du trajet : jour seul (« 2 déc. »), tel que servi ; étape ou ville :
    // jour et heure de l'appareil.
    final timeLabel = time == null
        ? null
        : event == null && step.dateOnly
        ? DateFormat.MMMd(l.localeName).format(time)
        : DateFormat.MMMd(l.localeName).add_Hm().format(time.toLocal());
    final details = event == null
        ? (step.detail?.trim() ?? '')
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
                      if (timeLabel != null) ...[
                        const SizedBox(width: DonySpacing.sm),
                        Text(
                          timeLabel,
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
                      key: event == null
                          ? const Key('tracking-step-detail')
                          : event.scanMethod != null
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
