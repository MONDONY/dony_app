import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Trajets épinglés en tête de « Mes trajets » (FLUTTER-FS).
class PinnedTripsState extends Equatable {
  const PinnedTripsState(this.ids);

  final Set<String> ids;

  bool isPinned(String id) => ids.contains(id);

  @override
  List<Object?> get props => [ids];
}

/// Épinglage de ses propres trajets, propre à l'appareil.
///
/// Rien ne part au serveur : c'est un rangement personnel, comme l'ordre de
/// ses conversations. Les identifiants vivent dans la boîte Hive
/// `user_prefs`, vidée à la déconnexion. Distinct des favoris (signet), qui
/// portent sur les trajets des autres et sont synchronisés.
class PinnedTripsCubit extends Cubit<PinnedTripsState> {
  PinnedTripsCubit(this._box) : super(PinnedTripsState(_read(_box)));

  final Box _box;

  static Set<String> _read(Box box) {
    try {
      final raw = box.get(HiveService.kPinnedTripIds);
      if (raw is List) return raw.whereType<String>().toSet();
    } catch (_) {
      // Une valeur illisible ne doit pas empêcher l'écran de s'ouvrir.
    }
    return const {};
  }

  /// Un trajet terminé ou annulé ne s'épingle pas : il n'attend plus rien.
  static bool canPin(AnnouncementModel trip) =>
      trip.status != 'COMPLETED' && trip.status != 'CANCELLED';

  Future<void> toggle(String id) {
    final next = {...state.ids};
    if (!next.remove(id)) next.add(id);
    return _save(next);
  }

  /// Retire les épingles des trajets terminés, annulés ou disparus de la
  /// liste (supprimés). Appelé à chaque chargement complet de « Mes trajets ».
  Future<void> syncWith(List<AnnouncementModel> trips) async {
    if (state.ids.isEmpty) return;
    final pinnable = {
      for (final t in trips)
        if (canPin(t)) t.id,
    };
    final next = state.ids.where(pinnable.contains).toSet();
    if (next.length != state.ids.length) await _save(next);
  }

  Future<void> _save(Set<String> ids) async {
    emit(PinnedTripsState(ids));
    try {
      await _box.put(HiveService.kPinnedTripIds, ids.toList());
    } catch (_) {
      // L'épingle reste valable pour la session, même si l'écriture échoue.
    }
  }
}
