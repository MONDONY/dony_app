import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/presentation/widgets/journey_timeline.dart';
import 'package:dony/features/tracking/presentation/widgets/parcel_not_linked_notice.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Parcours d'un colis en lecture seule (maquette B3, « Résultat du
/// suivi ») : numéro, phrase d'état, trajet, puis frise des étapes faites,
/// de l'étape en cours et des étapes à venir.
///
/// [departureCity] et [arrivalCity] `null` quand le colis est inconnu de
/// l'app (lu par QR) : pas de trajet en sous-titre ni de ville dans la phrase
/// d'état. [transportMode] choisit l'icône du trajet (avion par défaut).
/// [trackingNumber] : numéro DON affiché au-dessus du titre, s'il est connu.
/// [onShareTracking] : bouton « Partager le suivi » en bas de la feuille.
/// [bidStatus] : statut du colis s'il est connu. `ARRIVED` affiche l'arrivée
/// à destination même sans scan : « Je suis arrivé » ne crée pas d'étape de
/// suivi, et la frise restait sur « En route » (Sentry FLUTTER-5S).
/// [onOpenParcel] : bouton principal « Voir le colis », visible dès
/// l'ouverture, pour un colis de l'utilisateur (« Mes envois » de l'onglet
/// Suivi, FLUTTER-7Z). Avec [onShareTracking], les deux boutons s'empilent.
/// [travelerTracking] : suivi approximatif du voyageur (fiche colis de
/// l'expéditeur). Ses villes (« Près de Lyon ») s'insèrent dans la frise, dans
/// l'ordre du temps, entre les étapes enregistrées ; absent, la frise est
/// inchangée.
Future<void> showTrackingTimelineSheet(
  BuildContext context, {
  required String bidId,
  String? departureCity,
  String? arrivalCity,
  TransportMode? transportMode,
  VoidCallback? onShareTracking,
  String? arrivalInstructions,
  String? trackingNumber,
  String? bidStatus,
  VoidCallback? onOpenParcel,
  TravelerTrackingModel? travelerTracking,
}) {
  return DonyBottomSheet.show<void>(
    context,
    wrapper: (child) => BlocProvider(
      create: (_) => getIt<TrackingBloc>()..add(TrackingEventsRequested(bidId)),
      child: child,
    ),
    stickyBottom: onOpenParcel == null && onShareTracking == null
        ? null
        : _TimelineActions(
            onOpenParcel: onOpenParcel,
            onShareTracking: onShareTracking,
          ),
    child: _TrackingTimelineContent(
      bidId: bidId,
      bidStatus: bidStatus,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      transportMode: transportMode,
      trackingNumber: trackingNumber,
      arrivalInstructions: arrivalInstructions,
      travelerTracking: travelerTracking,
    ),
  );
}

/// Boutons du bas de la feuille : « Voir le colis » tout de suite (ferme la
/// feuille avant d'appeler [onOpenParcel]), « Partager le suivi » une fois le
/// parcours chargé.
class _TimelineActions extends StatelessWidget {
  const _TimelineActions({this.onOpenParcel, this.onShareTracking});

  final VoidCallback? onOpenParcel;
  final VoidCallback? onShareTracking;

  @override
  Widget build(BuildContext context) {
    final open = onOpenParcel;
    final share = onShareTracking;
    final Widget? openButton = open == null
        ? null
        : DonyButton(
            key: const Key('tracking-open-parcel'),
            label: context.l10n.trackingTimelineOpenParcel,
            iconAsset: 'package',
            // La feuille se ferme d'abord, l'appelant ouvre ensuite le colis.
            onPressed: () {
              Navigator.of(context).pop();
              open();
            },
          );
    if (share == null) return openButton ?? const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?openButton,
        BlocBuilder<TrackingBloc, TrackingState>(
          builder: (context, state) {
            if (state is! TrackingEventsLoaded) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(
                top: openButton == null ? 0 : DonySpacing.sm,
              ),
              child: DonyButton(
                key: const Key('tracking-share'),
                label: context.l10n.trackingTimelineShare,
                iconAsset: 'share-2',
                variant: DonyButtonVariant.secondary,
                onPressed: share,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrackingTimelineContent extends StatefulWidget {
  const _TrackingTimelineContent({
    required this.bidId,
    this.bidStatus,
    this.departureCity,
    this.arrivalCity,
    this.transportMode,
    this.trackingNumber,
    this.arrivalInstructions,
    this.travelerTracking,
  });

  final String bidId;
  final String? bidStatus;
  final String? departureCity;
  final String? arrivalCity;
  final TransportMode? transportMode;
  final String? trackingNumber;
  final String? arrivalInstructions;
  final TravelerTrackingModel? travelerTracking;

  @override
  State<_TrackingTimelineContent> createState() =>
      _TrackingTimelineContentState();
}

/// Recharge le parcours au retour dans l'app : la feuille restait figée sur
/// les étapes de son ouverture pendant que le colis avançait.
class _TrackingTimelineContentState extends State<_TrackingTimelineContent>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TrackingBloc>().add(TrackingEventsRequested(widget.bidId));
    }
  }

  String get bidId => widget.bidId;
  String? get departureCity => widget.departureCity;
  String? get arrivalCity => widget.arrivalCity;
  TransportMode? get transportMode => widget.transportMode;
  String? get trackingNumber => widget.trackingNumber;
  String? get arrivalInstructions => widget.arrivalInstructions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ReadOnlyHeader(),
        BlocBuilder<TrackingBloc, TrackingState>(
          builder: (context, state) => switch (state) {
            TrackingEventsLoading() => Padding(
              padding: const EdgeInsets.all(DonySpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(color: cs.primary),
              ),
            ),
            // 403 : colis ni envoyé ni transporté par l'utilisateur. Refus
            // définitif, « Réessayer » n'y changerait rien.
            TrackingEventsError(:final error)
                when error is ForbiddenException =>
              const Padding(
                padding: EdgeInsets.all(DonySpacing.xl),
                child: Center(child: ParcelNotLinkedNotice(centered: true)),
              ),
            TrackingEventsError(:final error) => _ErrorView(
              message: ErrorPresenter.resolve(
                error,
                l10n: context.l10n,
              ).message,
              onRetry: () => context.read<TrackingBloc>().add(
                TrackingEventsRequested(bidId),
              ),
            ),
            TrackingEventsLoaded(:final events) => _Journey(
              events: events,
              arrived: widget.bidStatus == 'ARRIVED',
              departureCity: departureCity,
              arrivalCity: arrivalCity,
              transportMode: transportMode,
              trackingNumber: trackingNumber,
              arrivalInstructions: arrivalInstructions,
              travelerTracking: widget.travelerTracking,
            ).animate().fadeIn(duration: 250.ms, curve: Curves.easeOutCubic),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

/// « Suivi en lecture seule » et la croix de fermeture.
class _ReadOnlyHeader extends StatelessWidget {
  const _ReadOnlyHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Row(
      children: [
        DonyIcon('eye', size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Expanded(
          child: Text(
            l.trackingReadOnlyLabel,
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        IconButton(
          tooltip: l.commonClose,
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
          icon: DonyIcon('x', size: 20, color: cs.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Étapes du parcours, dans l'ordre : faites (événements enregistrés), en
/// cours, puis à venir. Le transit, facultatif, n'apparaît que s'il a été
/// scanné.
///
/// [arrived] : le voyageur a déclaré son arrivée (colis `ARRIVED`). Aucun
/// scan ne la trace : l'étape est faite sans heure, et la remise au
/// destinataire devient l'étape en cours.
///
/// [tracking] : les villes approximatives du voyageur sont fusionnées aux
/// étapes faites par ordre d'heure ; à heure égale, l'étape enregistrée passe
/// avant la ville. La dernière ville est marquée « Maintenant » (voyageur en
/// route) ou « Dernière position, il y a X » (position ancienne).
List<JourneyStep> _journeySteps(
  AppLocalizations l,
  List<TrackingEventModel> events, {
  bool arrived = false,
  TravelerTrackingModel? tracking,
  DateTime? now,
}) {
  final sorted = [...events]
    ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
  final departed = sorted.any((e) => e.eventType == 'DEPART');
  final delivered = sorted.any((e) => e.eventType == 'ARRIVEE');
  final arrivedOnly = arrived && departed && !delivered;
  return [
    ...mergedDoneSteps(l, sorted, tracking, now ?? DateTime.now()),
    if (!delivered && !departed) ...[
      JourneyStep(JourneyStepState.current, l.trackingStepHandoverToTraveler),
      JourneyStep(JourneyStepState.upcoming, l.trackingStepDeparture),
    ],
    if (arrivedOnly) ...[
      JourneyStep(JourneyStepState.done, l.trackingStepArrivedAtDestination),
      JourneyStep(JourneyStepState.current, l.trackingStepHandoverToRecipient),
    ] else ...[
      if (!delivered && departed)
        JourneyStep(JourneyStepState.current, l.trackingHeadlineOnTheWay),
      if (!delivered)
        JourneyStep(
          JourneyStepState.upcoming,
          l.trackingStepHandoverToRecipient,
        ),
    ],
  ];
}

/// Phrase d'état du colis, en titre.
String _headline(
  AppLocalizations l,
  List<TrackingEventModel> events,
  String? arrivalCity, {
  bool arrived = false,
}) {
  if (events.any((e) => e.eventType == 'ARRIVEE')) {
    return l.trackingHeadlineDelivered;
  }
  if (!events.any((e) => e.eventType == 'DEPART')) {
    return l.trackingHeadlineAwaitingHandover;
  }
  final city = arrivalCity?.trim() ?? '';
  if (arrived) {
    return city.isEmpty
        ? l.trackingStepArrivedAtDestination
        : l.trackingHeadlineArrivedIn(city);
  }
  return city.isEmpty
      ? l.trackingHeadlineOnTheWay
      : l.trackingHeadlineOnTheWayTo(city);
}

class _Journey extends StatelessWidget {
  const _Journey({
    required this.events,
    this.arrived = false,
    this.departureCity,
    this.arrivalCity,
    this.transportMode,
    this.trackingNumber,
    this.arrivalInstructions,
    this.travelerTracking,
  });

  final List<TrackingEventModel> events;
  final bool arrived;
  final String? departureCity;
  final String? arrivalCity;
  final TransportMode? transportMode;
  final String? trackingNumber;
  final String? arrivalInstructions;
  final TravelerTrackingModel? travelerTracking;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final steps = _journeySteps(
      l,
      events,
      arrived: arrived,
      tracking: travelerTracking,
    );
    final number = trackingNumber?.trim() ?? '';
    final instructions = arrivalInstructions?.trim() ?? '';
    final from = departureCity?.trim() ?? '';
    final to = arrivalCity?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        if (number.isNotEmpty) ...[
          Text(
            number,
            key: const Key('tracking-number'),
            style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
        ],
        Text(
          _headline(l, events, arrivalCity, arrived: arrived),
          key: const Key('tracking-headline'),
          style: tt.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (from.isNotEmpty && to.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.xs),
          RouteLabel(
            key: const Key('tracking-route'),
            from: from,
            to: to,
            transportMode: transportMode,
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: DonySpacing.xl),
        for (var i = 0; i < steps.length; i++)
          JourneyRow(
            step: steps[i],
            // Trait bleu entre deux étapes faites, gris ensuite.
            connector: i == steps.length - 1
                ? null
                : steps[i + 1].state == JourneyStepState.done ||
                      steps[i + 1].state == JourneyStepState.position
                ? cs.primary
                : cs.outline,
          ),
        // Dès que le voyageur les a saisies : elles servent à récupérer le
        // colis, donc avant la remise au destinataire.
        if (instructions.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.sm),
          DonyStatusBanner(
            key: const Key('tracking-arrival-instructions'),
            type: DonyStatusBannerType.info,
            iconAsset: 'map-pin',
            title: l.tripOwnerArrivalEditingTitle,
            message: instructions,
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('circle-alert', color: cs.error, size: 40),
          const SizedBox(height: DonySpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.lg),
          DonyButton(
            label: context.l10n.commonRetry,
            iconAsset: 'refresh-cw',
            onPressed: onRetry,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}
