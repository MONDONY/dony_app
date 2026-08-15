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

  DateTime get earliestDate =>
      desiredDate.subtract(Duration(days: dateToleranceDays));
  DateTime get latestDate => desiredDate.add(Duration(days: dateToleranceDays));

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
  ];
}
