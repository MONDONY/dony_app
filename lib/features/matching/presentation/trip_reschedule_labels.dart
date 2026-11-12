import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/l10n/l10n.dart';

/// Premier motif proposé au report selon le mode du trajet : l'avion garde
/// `FLIGHT_CANCELLED` (accepté par tous les back), les autres modes envoient
/// `TRANSPORT_CANCELLED`. Un mode absent (anciennes données) vaut avion.
TripRescheduleReason firstReasonFor(TransportMode? mode) =>
    transportModeOrPlane(mode) == TransportMode.plane
    ? TripRescheduleReason.flightCancelled
    : TripRescheduleReason.transportCancelled;

/// Libellé d'un motif de report. `FLIGHT_CANCELLED` se lit toujours « Vol
/// annulé » ; `TRANSPORT_CANCELLED` suit le mode du trajet : « Panne ou
/// contretemps » sur la route (le bus s'affiche comme la route), « Transport
/// annulé » ailleurs, y compris sans mode.
String rescheduleReasonLabel(
  AppLocalizations l,
  TripRescheduleReason reason,
  TransportMode? mode,
) => switch (reason) {
  TripRescheduleReason.flightCancelled => l.tripRescheduleReasonFlightCancelled,
  TripRescheduleReason.transportCancelled =>
    mode == TransportMode.car || mode == TransportMode.bus
        ? l.tripRescheduleReasonBreakdown
        : l.tripRescheduleReasonTransportCancelled,
  TripRescheduleReason.postponed => l.tripRescheduleReasonPostponed,
  TripRescheduleReason.other => l.tripRescheduleReasonOther,
};
