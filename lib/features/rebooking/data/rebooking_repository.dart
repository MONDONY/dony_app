class PastBookingItem {
  final String bidId;
  final String travelerId;
  final String travelerName;
  final String? travelerBadge;
  final String departureCity;
  final String arrivalCity;
  final DateTime lastTripDate;
  final int completedTripsWithThisTraveler;

  const PastBookingItem({
    required this.bidId,
    required this.travelerId,
    required this.travelerName,
    required this.travelerBadge,
    required this.departureCity,
    required this.arrivalCity,
    required this.lastTripDate,
    required this.completedTripsWithThisTraveler,
  });

  factory PastBookingItem.fromJson(Map<String, dynamic> json) => PastBookingItem(
        bidId: json['bidId'] as String,
        travelerId: json['travelerId'] as String,
        travelerName: json['travelerName'] as String,
        travelerBadge: json['travelerBadge'] as String?,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        lastTripDate: DateTime.parse(json['lastTripDate'] as String),
        completedTripsWithThisTraveler:
            (json['completedTripsWithThisTraveler'] as num).toInt(),
      );
}

class RebookResult {
  final String status;
  final String? newBidId;

  const RebookResult({required this.status, required this.newBidId});

  factory RebookResult.fromJson(Map<String, dynamic> json) => RebookResult(
        status: json['status'] as String,
        newBidId: json['newBidId'] as String?,
      );
}

abstract class RebookingRepository {
  Future<List<PastBookingItem>> getPastBookings();
  Future<RebookResult> rebook(String pastBidId);
  Future<void> subscribeToTraveler(String travelerId);
}
