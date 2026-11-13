import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellé d'un motif de retard selon le mode du trajet.
///
/// `EXTENDED_STOPOVER` ne parle d'« escale » qu'en bateau et en avion : sur la
/// route ou sans mode connu, c'est un « arrêt prolongé ». `TRANSPORT_DISRUPTION`
/// reste neutre. `PORT_CONGESTION` n'existe qu'en bateau (le back le refuse
/// ailleurs) : s'il arrive quand même hors bateau, il se lit « Autre raison ».
String tripDelayReasonLabel(
  AppLocalizations l,
  TripDelayReason reason,
  TransportMode? mode,
) => switch (reason) {
  TripDelayReason.portCongestion =>
    mode == TransportMode.boat
        ? l.tripDelayReasonPortCongestion
        : l.tripRescheduleReasonOther,
  TripDelayReason.weather => l.tripDelayReasonWeather,
  TripDelayReason.extendedStopover =>
    {
          TransportMode.boat,
          TransportMode.plane,
        }.contains(transportModeOrPlane(mode))
        ? l.tripDelayReasonExtendedStopover
        : l.tripDelayReasonExtendedStop,
  TripDelayReason.transportDisruption => l.tripDelayReasonTransportDisruption,
  TripDelayReason.other => l.tripRescheduleReasonOther,
};

/// Libellé du motif d'un retard servi par le back ; un motif que l'app ne
/// connaît pas se lit « Autre raison ».
String tripDelayInfoReasonLabel(
  AppLocalizations l,
  TripDelayInfo delay,
  TransportMode? mode,
) {
  final reason = delay.reasonKind;
  return reason == null
      ? l.tripRescheduleReasonOther
      : tripDelayReasonLabel(l, reason, mode);
}
