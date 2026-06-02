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

  // Round-trip complet via le sérialiseur généré : préserve TOUS les champs
  // (acceptedPaymentMethods, pricingMode, priceGridItems, transportMode, ...).
  // L'ancien _toMap manuel omettait acceptedPaymentMethods → un trajet rouvert
  // depuis les favoris retombait sur {stripe} et ne proposait plus le cash.
  // jsonEncode appelle automatiquement .toJson() sur les objets imbriqués
  // (AddressData, TravelerProfile) via son toEncodable par défaut.
  String _encode(List<AnnouncementModel> trips) =>
      jsonEncode(trips.map((a) => a.toJson()).toList());
}
