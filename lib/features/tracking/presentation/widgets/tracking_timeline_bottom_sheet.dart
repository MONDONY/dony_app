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
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/parcel_not_linked_notice.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Parcours d'un colis en lecture seule (maquette B3, « Résultat du
/// suivi ») : numéro, phrase d'état, trajet, puis frise des étapes faites,
/// de l'étape en cours et des étapes à venir.
///
/// [departureCity] et [arrivalCity] `null` quand le colis est inconnu de
/// l'app (lu par QR) : pas de trajet en sous-titre ni de ville dans la phrase
/// d'état. [transportMode] choisit l'icône du trajet (avion par défaut).
/// [trackingNumber] : numéro DON affiché au-dessus du titre, s'il est connu.
/// [onShareTracking] : bouton « Partager le suivi » en bas de la feuille.
Future<void> showTrackingTimelineSheet(
  BuildContext context, {
  required String bidId,
  String? departureCity,
  String? arrivalCity,
  TransportMode? transportMode,
  VoidCallback? onShareTracking,
  String? arrivalInstructions,
  String? trackingNumber,
}) {
  return DonyBottomSheet.show<void>(
    context,
    wrapper: (child) => BlocProvider(
      create: (_) => getIt<TrackingBloc>()..add(TrackingEventsRequested(bidId)),
      child: child,
    ),
    stickyBottom: onShareTracking == null
        ? null
        : BlocBuilder<TrackingBloc, TrackingState>(
            builder: (context, state) {
              if (state is! TrackingEventsLoaded) {
                return const SizedBox.shrink();
              }
              return DonyButton(
                key: const Key('tracking-share'),
                label: context.l10n.trackingTimelineShare,
                iconAsset: 'share-2',
                variant: DonyButtonVariant.secondary,
                onPressed: onShareTracking,
              );
            },
          ),
    child: _TrackingTimelineContent(
      bidId: bidId,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      transportMode: transportMode,
      trackingNumber: trackingNumber,
      arrivalInstructions: arrivalInstructions,
    ),
  );
}

class _TrackingTimelineContent extends StatelessWidget {
  const _TrackingTimelineContent({
    required this.bidId,
    this.departureCity,
    this.arrivalCity,
    this.transportMode,
    this.trackingNumber,
    this.arrivalInstructions,
  });

  final String bidId;
  final String? departureCity;
  final String? arrivalCity;
  final TransportMode? transportMode;
  final String? trackingNumber;
  final String? arrivalInstructions;

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
              departureCity: departureCity,
              arrivalCity: arrivalCity,
              transportMode: transportMode,
              trackingNumber: trackingNumber,
              arrivalInstructions: arrivalInstructions,
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

enum _StepState { done, current, upcoming }

/// Une ligne de la frise.
class _JourneyStep {
  const _JourneyStep(this.state, this.title, {this.event});

  final _StepState state;
  final String title;

  /// Événement enregistré d'une étape faite : heure, lieu, provenance, photo.
  final TrackingEventModel? event;
}

/// Étapes du parcours, dans l'ordre : faites (événements enregistrés), en
/// cours, puis à venir. Le transit, facultatif, n'apparaît que s'il a été
/// scanné.
List<_JourneyStep> _journeySteps(
  AppLocalizations l,
  List<TrackingEventModel> events,
) {
  final sorted = [...events]
    ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
  final departed = sorted.any((e) => e.eventType == 'DEPART');
  final delivered = sorted.any((e) => e.eventType == 'ARRIVEE');
  return [
    for (final event in sorted)
      _JourneyStep(_StepState.done, _doneTitle(l, event), event: event),
    if (!delivered && !departed) ...[
      _JourneyStep(_StepState.current, l.trackingStepHandoverToTraveler),
      _JourneyStep(_StepState.upcoming, l.trackingStepDeparture),
    ],
    if (!delivered && departed)
      _JourneyStep(_StepState.current, l.trackingHeadlineOnTheWay),
    if (!delivered)
      _JourneyStep(_StepState.upcoming, l.trackingStepHandoverToRecipient),
  ];
}

String _doneTitle(AppLocalizations l, TrackingEventModel event) =>
    switch (event.eventType) {
      'DEPART' => l.trackingStepHandedToTraveler,
      'ARRIVEE' => l.trackingStepHandedToRecipient,
      _ => trackingStepLabel(l, event.eventType),
    };

/// Phrase d'état du colis, en titre.
String _headline(
  AppLocalizations l,
  List<TrackingEventModel> events,
  String? arrivalCity,
) {
  if (events.any((e) => e.eventType == 'ARRIVEE')) {
    return l.trackingHeadlineDelivered;
  }
  if (!events.any((e) => e.eventType == 'DEPART')) {
    return l.trackingHeadlineAwaitingHandover;
  }
  final city = arrivalCity?.trim() ?? '';
  return city.isEmpty
      ? l.trackingHeadlineOnTheWay
      : l.trackingHeadlineOnTheWayTo(city);
}

class _Journey extends StatelessWidget {
  const _Journey({
    required this.events,
    this.departureCity,
    this.arrivalCity,
    this.transportMode,
    this.trackingNumber,
    this.arrivalInstructions,
  });

  final List<TrackingEventModel> events;
  final String? departureCity;
  final String? arrivalCity;
  final TransportMode? transportMode;
  final String? trackingNumber;
  final String? arrivalInstructions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final steps = _journeySteps(l, events);
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
          _headline(l, events, arrivalCity),
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
          _JourneyRow(
            step: steps[i],
            // Trait bleu entre deux étapes faites, gris ensuite.
            connector: i == steps.length - 1
                ? null
                : steps[i + 1].state == _StepState.done
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

class _JourneyRow extends StatelessWidget {
  const _JourneyRow({required this.step, required this.connector});

  final _JourneyStep step;

  /// Couleur du trait vers l'étape suivante, `null` pour la dernière.
  final Color? connector;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final event = step.event;
    final line = connector;
    final details = event == null
        ? ''
        : [?event.locationLabel(l), ?event.methodLabel(l)].join(' · ');
    final photo = event?.photoUrl;

    final Widget marker = switch (step.state) {
      _StepState.done => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: DonyIcon('check', size: 12, color: cs.onPrimary),
      ),
      _StepState.current => Container(
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
      _StepState.upcoming => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline, width: 2),
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
                            fontWeight: step.state == _StepState.current
                                ? FontWeight.w700
                                : null,
                            color: step.state == _StepState.upcoming
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                      ),
                      if (event != null) ...[
                        const SizedBox(width: DonySpacing.sm),
                        Text(
                          DateFormat.MMMd(
                            l.localeName,
                          ).add_Hm().format(event.scannedAt.toLocal()),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
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
                  if (photo != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    Semantics(
                      image: true,
                      label: l.trackingStepPhotoLabel,
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
