import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:equatable/equatable.dart';

/// Locks the corridor / weight / transport mode / agreed price of a brand-new
/// announcement that the traveler creates in the context of an AWAITING_TRIP
/// negotiation thread. These fields are derived from the package_request and
/// must NOT be editable in the create-announcement form.
class LockedTripContext extends Equatable {
  const LockedTripContext({
    this.threadId,
    required this.packageRequestId,
    required this.departureCity,
    required this.arrivalCity,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.weightKg,
    required this.transportMode,
    required this.agreedPriceEur,
    this.paymentMethod = PaymentMethod.stripe,
    this.currency = 'EUR',
    this.offerAvailableKg,
    this.offerBody,
    this.preferredDate,
  });

  /// Null when creating this dedicated trip as part of a brand-new offer (no
  /// negotiation thread exists yet — the offer and the trip are created
  /// atomically, see `NegotiationStartWithDedicatedTripRequested`). Non-null
  /// when recovering from an existing AWAITING_TRIP thread (refuseTrip loop),
  /// where the trip is linked to that thread via
  /// `NegotiationCreateDedicatedTripRequested`.
  final String? threadId;
  final String packageRequestId;
  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final double weightKg;
  final TransportMode transportMode;
  final double agreedPriceEur;

  /// The payment method selected by the traveler in the link-trip screen.
  final PaymentMethod paymentMethod;
  final String currency;

  /// Only set when [threadId] is null (atomic offer + dedicated-trip flow):
  /// the capacity the traveler typed in the offer form's "CAPACITÉ" field,
  /// which may differ from [weightKg] (the package request's own weight —
  /// just the default). Falls back to [weightKg] when null.
  final double? offerAvailableKg;

  /// Only set when [threadId] is null: the optional message the traveler
  /// typed in the offer form, carried through to the atomically-created
  /// negotiation thread.
  final String? offerBody;

  /// Date de voyage choisie par le voyageur dans la feuille d'offre, déjà
  /// bornée à [travelWindow] : pré-remplit le départ du trajet dédié. Null
  /// (boucle refuseTrip) : le formulaire part de [desiredDate].
  final DateTime? preferredDate;

  DateTime get earliestDate =>
      desiredDate.subtract(Duration(days: dateToleranceDays));
  DateTime get latestDate => desiredDate.add(Duration(days: dateToleranceDays));

  /// Fenêtre où la date de voyage est acceptée, pour ce contexte.
  ({DateTime first, DateTime last}) get travelWindow => travelDateWindow(
    desiredDate: desiredDate,
    toleranceDays: dateToleranceDays,
  );

  /// Seule source de la fenêtre de dates d'une demande, partagée par la
  /// feuille d'offre et la création d'un trajet dédié : [souhaitée −
  /// tolérance ; souhaitée + tolérance], comme le valide le back, sans jamais
  /// commencer avant aujourd'hui (le back refuse une date passée). Bornes en
  /// jours calendaires (sans heure). Une fenêtre déjà entièrement passée se
  /// réduit à aujourd'hui plutôt que de donner un `lastDate` antérieur au
  /// `firstDate`, qui ferait échouer `showDatePicker`.
  static ({DateTime first, DateTime last}) travelDateWindow({
    required DateTime desiredDate,
    required int toleranceDays,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    // Arithmétique calendaire (et non `Duration`) : un passage à l'heure
    // d'été ne doit pas décaler la borne d'un jour.
    final earliest = DateTime(
      desiredDate.year,
      desiredDate.month,
      desiredDate.day - toleranceDays,
    );
    final latest = DateTime(
      desiredDate.year,
      desiredDate.month,
      desiredDate.day + toleranceDays,
    );
    final first = earliest.isBefore(day) ? day : earliest;
    return (first: first, last: latest.isBefore(first) ? first : latest);
  }

  /// Ramène [date] dans [window] (jour calendaire, sans heure).
  static DateTime clampToWindow(
    DateTime date,
    ({DateTime first, DateTime last}) window,
  ) {
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(window.first)) return window.first;
    if (d.isAfter(window.last)) return window.last;
    return d;
  }

  @override
  List<Object?> get props => [
    threadId,
    packageRequestId,
    departureCity,
    arrivalCity,
    desiredDate,
    dateToleranceDays,
    weightKg,
    transportMode,
    agreedPriceEur,
    paymentMethod,
    currency,
    offerAvailableKg,
    offerBody,
    preferredDate,
  ];
}
