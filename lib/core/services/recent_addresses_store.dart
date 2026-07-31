import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';

/// Cache local des dernières adresses résolues (recherche ou GPS), pour
/// éviter un appel Google (Places/Geocoding) quand l'utilisateur reprend
/// une adresse déjà utilisée récemment. Une instance par sheet
/// (pickup/delivery) via [storageKey] — les deux usages ne se mélangent pas.
class RecentAddressesStore {
  RecentAddressesStore(this._hive, this.storageKey);

  final HiveService _hive;
  final String storageKey;

  static const maxEntries = 3;

  List<AddressData> getAll() {
    final raw = _hive.userPrefs.get(storageKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => AddressData.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> add(AddressData address) async {
    final deduped = getAll().where((a) => a.label != address.label).toList();
    final updated = [address, ...deduped].take(maxEntries).toList();
    await _hive.userPrefs.put(
      storageKey,
      updated.map((a) => a.toJson()).toList(),
    );
  }
}
