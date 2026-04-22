import 'package:json_annotation/json_annotation.dart';

part 'announcement_model.g.dart';

@JsonSerializable()
class TravelerProfile {
  final String id;
  final String? displayName;
  final double? averageRating;
  final int? totalTrips;
  final bool kiloPro;

  const TravelerProfile({
    required this.id,
    this.displayName,
    this.averageRating,
    this.totalTrips,
    this.kiloPro = false,
  });

  factory TravelerProfile.fromJson(Map<String, dynamic> json) =>
      _$TravelerProfileFromJson(json);

  Map<String, dynamic> toJson() => _$TravelerProfileToJson(this);
}

@JsonSerializable()
class AnnouncementModel {
  final String id;
  final String travelerId;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double availableKg;
  final double pricePerKg;
  final String status;
  final int? bidsCount;
  final TravelerProfile? traveler;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnouncementModel({
    required this.id,
    required this.travelerId,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
    required this.status,
    this.bidsCount,
    this.traveler,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementModelFromJson(json);

  Map<String, dynamic> toJson() => _$AnnouncementModelToJson(this);
}
