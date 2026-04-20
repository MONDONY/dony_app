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
