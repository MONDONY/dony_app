import 'package:json_annotation/json_annotation.dart';

part 'announcement_model.g.dart';

@JsonSerializable()
class TravelerProfile {
  final String id;
  final String? displayName;
  final String? phoneNumber;
  final double? averageRating;
  final int? totalTrips;
  final bool kiloPro;

  const TravelerProfile({
    required this.id,
    this.displayName,
    this.phoneNumber,
    this.averageRating,
    this.totalTrips,
    this.kiloPro = false,
  });

  factory TravelerProfile.fromJson(Map<String, dynamic> json) =>
      _$TravelerProfileFromJson(json);

  Map<String, dynamic> toJson() => _$TravelerProfileToJson(this);

  /// Nom à afficher : displayName en priorité, puis phoneNumber si nom null, puis 'Voyageur'.
  String get resolvedName {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (phoneNumber != null && phoneNumber!.isNotEmpty) return phoneNumber!;
    return 'Voyageur';
  }

  /// Initiales : basées sur le nom si disponible, sinon sur le numéro, sinon '?'.
  String get resolvedInitials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return displayName![0].toUpperCase();
    }
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      final digits = phoneNumber!.replaceAll(RegExp(r'[^\d]'), '');
      return digits.isNotEmpty ? digits[0] : '?';
    }
    return '?';
  }
}

@JsonSerializable()
class AnnouncementModel {
  final String id;
  final String travelerId;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  // "HH:mm" format, null if not set
  final String? departureTime;
  final String? arrivalTime;
  final String? departureLocation;
  final String? arrivalLocation;
  final double availableKg;
  final double pricePerKg;
  final String status;
  final int? bidsCount;
  final TravelerProfile? traveler;
  final String? description;
  final List<String>? acceptedContentTypes;
  final List<String>? refusedTypes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnouncementModel({
    required this.id,
    required this.travelerId,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.departureLocation,
    this.arrivalLocation,
    required this.availableKg,
    required this.pricePerKg,
    required this.status,
    this.bidsCount,
    this.traveler,
    this.description,
    this.acceptedContentTypes,
    this.refusedTypes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementModelFromJson(json);

  Map<String, dynamic> toJson() => _$AnnouncementModelToJson(this);
}
