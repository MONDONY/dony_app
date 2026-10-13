import 'package:hive_flutter/hive_flutter.dart';

/// Mémorise les colis (bidId) pour lesquels la feuille de notation s'est déjà
/// ouverte d'elle-même (FLUTTER-P2).
///
/// Le shell vérifie au montage s'il reste une note en attente : sans mémoire,
/// la feuille se rouvrait à chaque lancement tant que la note n'était pas
/// donnée. Elle ne s'ouvre plus automatiquement qu'une fois par colis ; le
/// rappel reste ensuite discret (pastille « À noter » sur la carte du colis,
/// bouton « Noter » du détail).
///
/// Propre à l'appareil, dans la box `user_prefs`. La liste est bornée aux
/// [maxEntries] derniers colis : un colis plus ancien sorti de la liste
/// pourrait être reproposé une fois, sans gravité.
class RatingPromptTracker {
  RatingPromptTracker(this._prefs);

  final Box<dynamic> _prefs;

  static const storageKey = 'rating_prompted_bid_ids';
  static const maxEntries = 200;

  List<String> _read() {
    try {
      final raw = _prefs.get(storageKey);
      if (raw is! List) return const [];
      return raw.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Réserve l'ouverture automatique pour [bidId] : `true` la première fois
  /// (l'appelant ouvre la feuille), `false` ensuite. Un stockage illisible
  /// rend `false` : mieux vaut un rappel manqué qu'une feuille qui revient à
  /// chaque lancement.
  Future<bool> claim(String bidId) async {
    try {
      final ids = _read();
      if (ids.contains(bidId)) return false;
      final updated = [...ids, bidId];
      final start = updated.length > maxEntries
          ? updated.length - maxEntries
          : 0;
      await _prefs.put(storageKey, updated.sublist(start));
      return true;
    } catch (_) {
      return false;
    }
  }
}
