abstract class AnnouncementEvent {}

class AnnouncementCreateRequested extends AnnouncementEvent {
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double availableKg;
  final double pricePerKg;

  AnnouncementCreateRequested({
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
  });
}

class AnnouncementListRequested extends AnnouncementEvent {}

class AnnouncementDetailRequested extends AnnouncementEvent {
  final String id;
  AnnouncementDetailRequested(this.id);
}

class AnnouncementUpdateRequested extends AnnouncementEvent {
  final String id;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double availableKg;
  final double pricePerKg;

  AnnouncementUpdateRequested({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
  });
}
