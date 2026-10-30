import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Code parrain venu d'un lien d'invitation (`yadony://referral?code=XXX`),
/// gardé jusqu'à l'inscription.
///
/// Un code parrain n'est pas une donnée sensible : SharedPreferences suffit.
/// La valeur est aussi gardée en mémoire pour être lue sans attendre ; le
/// chargement depuis le disque est lancé à la construction.
///
/// Après une nouvelle inscription, `PendingReferralRedeemer` l'applique tout
/// seul puis l'efface.
class PendingReferralCodeStore {
  PendingReferralCodeStore({
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now {
    _loading = _load();
  }

  static const _codeKey = 'pending_referral_code';
  static const _savedAtKey = 'pending_referral_code_saved_at';

  /// Au-delà, le lien est considéré comme oublié : on ne le ressort plus.
  static const maxAge = Duration(days: 30);

  /// Format accepté, le même que la page web `yadony.com/r/CODE`.
  static final RegExp _codePattern = RegExp(r'^[A-Z0-9-]{4,20}$');

  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  late final Future<void> _loading;
  String? _code;

  /// Code en attente, ou `null`.
  String? get current => _code;

  /// Attend la fin de la lecture initiale (tests, appelants asynchrones).
  Future<void> get ready => _loading;

  /// Normalise [raw] (majuscules, espaces retirés) et rend le code s'il est
  /// valide, `null` sinon.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final code = raw.trim().toUpperCase();
    return _codePattern.hasMatch(code) ? code : null;
  }

  Future<void> save(String code) async {
    final normalized = normalize(code);
    if (normalized == null) return;
    _code = normalized;
    try {
      final prefs = await _prefs();
      await prefs.setString(_codeKey, normalized);
      await prefs.setInt(_savedAtKey, _now().millisecondsSinceEpoch);
    } catch (_) {
      // Stockage indisponible : la valeur en mémoire suffit pour la session.
    }
  }

  Future<void> clear() async {
    _code = null;
    try {
      final prefs = await _prefs();
      await prefs.remove(_codeKey);
      await prefs.remove(_savedAtKey);
    } catch (_) {
      // Rien à faire : la valeur en mémoire est déjà effacée.
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await _prefs();
      final stored = normalize(prefs.getString(_codeKey));
      final savedAt = prefs.getInt(_savedAtKey);
      if (stored == null || savedAt == null) return;
      final age = _now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (age > maxAge) {
        unawaited(clear());
        return;
      }
      // Un `save` arrivé pendant la lecture garde la main.
      _code ??= stored;
    } catch (_) {
      // Lecture impossible : pas de code en attente.
    }
  }
}
