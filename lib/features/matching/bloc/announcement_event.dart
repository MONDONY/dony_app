abstract class AnnouncementEvent {}

class AnnouncementCreateRequested extends AnnouncementEvent {
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final String? departureLocation;
  final String? arrivalLocation;
  final double availableKg;
  final double pricePerKg;

  AnnouncementCreateRequested({
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.departureLocation,
    this.arrivalLocation,
    required this.availableKg,
    required this.pricePerKg,
  });
}

class AnnouncementListRequested extends AnnouncementEvent {}

class AnnouncementDetailRequested extends AnnouncementEvent {
  final String id;
  AnnouncementDetailRequested(this.id);
}

class AnnouncementSearchRequested extends AnnouncementEvent {
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDateFrom;
  final DateTime? departureDateTo;
  final double? minAvailableKg;
  final String sortBy; // date | price | rating
  final String sortDir; // asc | desc

  AnnouncementSearchRequested({
    this.departureCity,
    this.arrivalCity,
    this.departureDateFrom,
    this.departureDateTo,
    this.minAvailableKg,
    this.sortBy = 'date',
    this.sortDir = 'asc',
  });
}

class AnnouncementDeleteRequested extends AnnouncementEvent {
  final String id;
  AnnouncementDeleteRequested(this.id);
}

class AnnouncementUpdateRequested extends AnnouncementEvent {
  final String id;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final String? departureLocation;
  final String? arrivalLocation;
  final double availableKg;
  final double pricePerKg;

  AnnouncementUpdateRequested({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.departureLocation,
    this.arrivalLocation,
    required this.availableKg,
    required this.pricePerKg,
  });
}
