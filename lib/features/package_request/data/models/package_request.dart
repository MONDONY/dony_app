import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:equatable/equatable.dart';

enum PackageRequestStatus {
  open('OPEN'),
  negotiating('NEGOTIATING'),
  accepted('ACCEPTED'),
  expired('EXPIRED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  final String wireName;
  const PackageRequestStatus(this.wireName);

  static PackageRequestStatus fromJson(String s) =>
      PackageRequestStatus.values.firstWhere((e) => e.wireName == s);
}

class PackageRequest extends Equatable {
  const PackageRequest({
    required this.id,
    required this.senderId,
    required this.departureCity,
    required this.arrivalCity,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.weightKg,
    required this.parcelSize,
    required this.transportMode,
    required this.contentCategory,
    this.description,
    this.targetPriceEur,
    this.photoUrl,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final double weightKg;
  final ParcelSize parcelSize;
  final TransportMode transportMode;
  final String contentCategory;
  final String? description;
  final double? targetPriceEur;
  final String? photoUrl;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final PackageRequestStatus status;
  final DateTime createdAt;

  factory PackageRequest.fromJson(Map<String, dynamic> json) => PackageRequest(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        desiredDate: DateTime.parse(json['desiredDate'] as String),
        dateToleranceDays: json['dateToleranceDays'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
        transportMode: transportModeFromWire(json['transportMode'] as String?) ?? TransportMode.plane,
        contentCategory: json['contentCategory'] as String,
        description: json['description'] as String?,
        targetPriceEur: (json['targetPriceEur'] as num?)?.toDouble(),
        photoUrl: json['photoUrl'] as String?,
        pickupNeighborhood: json['pickupNeighborhood'] as String?,
        deliveryNeighborhood: json['deliveryNeighborhood'] as String?,
        status: PackageRequestStatus.fromJson(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [
        id, senderId,
        departureCity, arrivalCity,
        desiredDate, dateToleranceDays,
        weightKg, parcelSize, transportMode, contentCategory,
        description, targetPriceEur, photoUrl,
        pickupNeighborhood, deliveryNeighborhood,
        status, createdAt,
      ];
}
