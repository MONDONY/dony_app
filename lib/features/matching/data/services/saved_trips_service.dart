import 'dart:convert';

import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';

class SavedTripsService {
  static const _key = 'saved_trips';
  final HiveService _hive;

  SavedTripsService(this._hive);

  List<AnnouncementModel> getSavedTrips() {
    final raw = _hive.userPrefs.get(_key) as String?;
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AnnouncementModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool isSaved(String id) => getSavedTrips().any((t) => t.id == id);

  Future<void> saveTrip(AnnouncementModel announcement) async {
    final trips = getSavedTrips();
    if (!trips.any((t) => t.id == announcement.id)) {
      trips.add(announcement);
      await _hive.userPrefs.put(_key, _encode(trips));
    }
  }

  Future<void> removeTrip(String id) async {
    final trips = getSavedTrips().where((t) => t.id != id).toList();
    await _hive.userPrefs.put(_key, _encode(trips));
  }

  String _encode(List<AnnouncementModel> trips) =>
      jsonEncode(trips.map(_toMap).toList());

  Map<String, dynamic> _toMap(AnnouncementModel a) => {
        'id': a.id,
        'travelerId': a.travelerId,
        'departureCity': a.departureCity,
        'arrivalCity': a.arrivalCity,
        'departureDate': a.departureDate.toIso8601String(),
        'departureTime': a.departureTime,
        'arrivalTime': a.arrivalTime,
        'pickupAddress': a.pickupAddress?.toJson(),
        'deliveryAddress': a.deliveryAddress?.toJson(),
        'availableKg': a.availableKg,
        'pricePerKg': a.pricePerKg,
        'status': a.status,
        'bidsCount': a.bidsCount,
        'traveler': a.traveler != null
            ? {
                'id': a.traveler!.id,
                'displayName': a.traveler!.displayName,
                'averageRating': a.traveler!.averageRating,
                'totalTrips': a.traveler!.totalTrips,
                'kiloPro': a.traveler!.kiloPro,
              }
            : null,
        'createdAt': a.createdAt.toIso8601String(),
        'updatedAt': a.updatedAt.toIso8601String(),
      };
}
