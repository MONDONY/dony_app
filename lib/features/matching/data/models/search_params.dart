class SearchParams {
  final String departureCity;
  final String arrivalCity;
  final DateTime? date;
  final double weightKg;
  final double maxPricePerKg;
  final bool kiloProOnly;
  final bool ratingFilter;
  final bool weekendFilter;
  final bool priceFilter;

  const SearchParams({
    required this.departureCity,
    required this.arrivalCity,
    this.date,
    this.weightKg = 6,
    this.maxPricePerKg = 25,
    this.kiloProOnly = false,
    this.ratingFilter = false,
    this.weekendFilter = false,
    this.priceFilter = false,
  });
}
