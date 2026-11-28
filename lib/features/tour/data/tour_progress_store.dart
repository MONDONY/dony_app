import 'package:hive_flutter/hive_flutter.dart';

/// Mémoire locale de ce que le petit tour a déjà montré, par compte.
///
/// Trois valeurs, toutes portées par l'UID (la boîte `user_prefs` n'est pas
/// vidée à la déconnexion) :
/// - les bulles vues ou écartées, en masque de bits (une bulle ne revient plus) ;
/// - le moment où la première partie du tour (les quatre premières bulles) s'est
///   terminée, qui sert de point de départ aux bulles différées et à l'assistant ;
/// - le dernier jour où une bulle « au moment utile » s'est affichée, pour n'en
///   montrer qu'une par jour.
///
/// Toute lecture illisible rend « rien de vu » : mieux vaut un tour proposé
/// deux fois qu'un tour jamais montré.
class TourProgressStore {
  TourProgressStore(this._prefs);

  final Box<dynamic> _prefs;

  static const seenPrefix = 'tour_seen_v2_';
  static const doneAtPrefix = 'tour_done_at_v2_';
  static const lastContextualPrefix = 'tour_last_ctx_v2_';

  int readSeen(String uid) {
    try {
      final value = _prefs.get('$seenPrefix$uid');
      return value is int && value >= 0 ? value : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> writeSeen(String uid, int mask) => _put('$seenPrefix$uid', mask);

  DateTime? readDoneAt(String uid) {
    try {
      final value = _prefs.get('$doneAtPrefix$uid');
      return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeDoneAt(String uid, DateTime at) =>
      _put('$doneAtPrefix$uid', at.millisecondsSinceEpoch);

  String? readLastContextualDay(String uid) {
    try {
      final value = _prefs.get('$lastContextualPrefix$uid');
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeLastContextualDay(String uid, String day) =>
      _put('$lastContextualPrefix$uid', day);

  Future<void> _put(String key, Object value) async {
    try {
      await _prefs.put(key, value);
    } catch (_) {
      // Le tour ne vaut pas une erreur visible : au pire il se rejouera.
    }
  }
}
