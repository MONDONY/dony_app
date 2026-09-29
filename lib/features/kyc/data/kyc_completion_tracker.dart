import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Garantit qu'un compte n'émet `kyc_completed` qu'une fois par appareil.
///
/// L'écran de statut KYC recharge le statut à chaque ouverture : un compte déjà
/// vérifié qui y revenait réémettait l'événement, et les compteurs du tableau de
/// bord comptaient des vérifications qui n'avaient pas eu lieu.
class KycCompletionTracker {
  KycCompletionTracker(this._prefs, {String? Function()? currentUid})
    : _currentUid =
          currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final Box<dynamic> _prefs;
  final String? Function() _currentUid;

  static const keyPrefix = 'analytics_kyc_completed_logged_';

  /// `true` la première fois pour le compte courant, `false` ensuite. Rend
  /// `true` quand le stockage est illisible : mieux vaut un doublon rare qu'une
  /// vérification jamais comptée.
  Future<bool> claim() async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return true;
    try {
      final key = '$keyPrefix$uid';
      if (_prefs.get(key) == true) return false;
      await _prefs.put(key, true);
      return true;
    } catch (_) {
      return true;
    }
  }
}
