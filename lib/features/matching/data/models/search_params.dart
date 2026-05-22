import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';

class SearchParams {
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? date;
  final double weightKg;
  final double maxPricePerKg;
  final bool kiloProOnly;
  final bool ratingFilter;
  final bool weekendFilter;
  final bool priceFilter;
  final TransportMode? transportMode;
  final bool kycVerifiedOnly;
  final String? contentType;
  final UrgencyFilter? urgencyFilter;

  const SearchParams({
    this.departureCity,
    this.arrivalCity,
    this.date,
    this.weightKg = 6,
    this.maxPricePerKg = 25,
    this.kiloProOnly = false,
    this.ratingFilter = false,
    this.weekendFilter = false,
    this.priceFilter = false,
    this.transportMode,
    this.kycVerifiedOnly = false,
    this.contentType,
    this.urgencyFilter,
  });
}
