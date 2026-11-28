import 'package:hive_flutter/hive_flutter.dart';

/// Mémoire locale de l'avancée du petit tour, par compte.
///
/// La valeur est le rang de la prochaine bulle à montrer (0 pour la première).
/// Dès qu'elle atteint le nombre de bulles, le tour est fini pour ce compte :
/// il ne revient plus, ni après une déconnexion, ni après un redémarrage. La
/// boîte `user_prefs` n'est pas vidée à la déconnexion, la clé porte l'UID.
class TourProgressStore {
  TourProgressStore(this._prefs);

  final Box<dynamic> _prefs;

  static const keyPrefix = 'tour_next_step_v1_';

  /// Rang de la prochaine bulle pour [uid], 0 si rien n'est écrit ou si le
  /// stockage est illisible : mieux vaut un tour proposé deux fois qu'un tour
  /// jamais montré.
  int read(String uid) {
    try {
      final value = _prefs.get('$keyPrefix$uid');
      return value is int && value >= 0 ? value : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> write(String uid, int nextStep) async {
    try {
      await _prefs.put('$keyPrefix$uid', nextStep);
    } catch (_) {
      // Le tour ne vaut pas une erreur visible : au pire il se rejouera.
    }
  }
}
