import 'package:equatable/equatable.dart';
import 'content_category.dart';
import 'parcel_size.dart';

/// Lightweight item returned by the search endpoint (`GET /package-requests`).
/// Includes city-level coords (departure/arrival) for map markers and a public
/// sender profile (no PII).
class PackageRequestSearchItem extends Equatable {
  const PackageRequestSearchItem({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.weightKg,
    required this.parcelSize,
    required this.contentCategory,
    this.targetPriceEur,
    this.photoUrl,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    required this.sender,
  });

  final String id;
  final String departureCity;
  final String arrivalCity;
  final double? departureLat;
  final double? departureLng;
  final double? arrivalLat;
  final double? arrivalLng;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final double weightKg;
  final ParcelSize parcelSize;
  final ContentCategory contentCategory;
  final double? targetPriceEur;
  final String? photoUrl;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final SenderPublicProfile sender;

  factory PackageRequestSearchItem.fromJson(Map<String, dynamic> json) =>
      PackageRequestSearchItem(
        id: json['id'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        departureLat: (json['departureLat'] as num?)?.toDouble(),
        departureLng: (json['departureLng'] as num?)?.toDouble(),
        arrivalLat: (json['arrivalLat'] as num?)?.toDouble(),
        arrivalLng: (json['arrivalLng'] as num?)?.toDouble(),
        desiredDate: DateTime.parse(json['desiredDate'] as String),
        dateToleranceDays: json['dateToleranceDays'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
        contentCategory:
            ContentCategory.fromWire(json['contentCategory'] as String?),
        targetPriceEur: (json['targetPriceEur'] as num?)?.toDouble(),
        photoUrl: json['photoUrl'] as String?,
        pickupNeighborhood: json['pickupNeighborhood'] as String?,
        deliveryNeighborhood: json['deliveryNeighborhood'] as String?,
        sender: SenderPublicProfile.fromJson(
            json['sender'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [
        id, departureCity, arrivalCity,
        departureLat, departureLng, arrivalLat, arrivalLng,
        desiredDate, dateToleranceDays,
        weightKg, parcelSize, contentCategory,
        targetPriceEur, photoUrl,
        pickupNeighborhood, deliveryNeighborhood,
        sender,
      ];
}

class SenderPublicProfile extends Equatable {
  const SenderPublicProfile({
    required this.id,
    required this.displayName,
    required this.averageRating,
    required this.totalRatings,
    required this.kycVerified,
  });

  final String id;
  final String displayName;
  final double averageRating;
  final int totalRatings;
  final bool kycVerified;

  factory SenderPublicProfile.fromJson(Map<String, dynamic> json) =>
      SenderPublicProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        averageRating: (json['averageRating'] as num).toDouble(),
        totalRatings: json['totalRatings'] as int,
        kycVerified: json['kycVerified'] as bool,
      );

  @override
  List<Object?> get props =>
      [id, displayName, averageRating, totalRatings, kycVerified];
}
