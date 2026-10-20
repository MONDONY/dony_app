import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_rate.dart';
import 'package:flutter/foundation.dart';

/// Réponse de `GET /config/commission-grid` : la grille en vigueur et la
/// suivante, déjà programmée (`null` quand rien n'est prévu).
///
/// `current` vaut aussi `null` avant la toute première grille : l'app garde
/// alors le taux unique historique.
class CommissionGridConfig {
  const CommissionGridConfig({this.current, this.next, this.legacyRate});

  /// Aucune grille connue : le comportement historique (taux unique) reste.
  static const none = CommissionGridConfig();

  final CommissionGrid? current;
  final CommissionGrid? next;

  /// Taux unique des objets SANS grille (offres d'avant les paliers), envoyé
  /// par le back récent. `null` quand le back ne l'envoie pas encore ou que
  /// la valeur est hors [0,1[ : l'app garde le taux de
  /// `/config/commission-rate`.
  final double? legacyRate;

  /// Lève une erreur de type ou de format si le JSON est malformé : l'appelant
  /// (`main.dart`, [CommissionGridStore.ensure]) l'attrape et retombe sur
  /// « pas de grille ».
  factory CommissionGridConfig.fromJson(Map<String, dynamic> json) {
    CommissionGrid? read(Object? raw) => raw == null
        ? null
        : CommissionGrid.fromJson(Map<String, dynamic>.from(raw as Map));
    final legacy = json['legacyRate'];
    return CommissionGridConfig(
      current: read(json['current']),
      next: read(json['next']),
      // Champ optionnel : absent ou invalide, ignoré sans casser la grille.
      legacyRate: legacy is num && legacy >= 0 && legacy < 1
          ? legacy.toDouble()
          : null,
    );
  }
}

/// Applique la réponse de `GET /config/commission-grid` au démarrage : les
/// grilles dans [CommissionGridStore], et `legacyRate` (quand il est présent
/// et valide) comme taux des objets sans grille, prioritaire sur
/// `/config/commission-rate` quel que soit l'ordre d'arrivée.
void applyCommissionGridConfig(CommissionGridConfig config) {
  CommissionGridStore.setConfig(config);
  setLegacyCommissionRate(config.legacyRate);
}

/// Mémoire des grilles de commission connues de l'app : celles en vigueur
/// (chargées au démarrage) et celles figées d'une demande, lues à la demande
/// par identifiant et gardées en cache.
abstract final class CommissionGridStore {
  static CommissionGridConfig _config = CommissionGridConfig.none;
  static final Map<String, CommissionGrid> _cache = {};
  static final Map<String, Future<CommissionGrid?>> _inFlight = {};

  /// Remplace les grilles en vigueur (démarrage de l'app).
  static void setConfig(CommissionGridConfig config) => _config = config;

  /// Grille applicable à [nowUtc] : la suivante dès que sa date d'effet est
  /// franchie, sinon la courante. `null` sans grille (taux unique historique).
  static CommissionGrid? activeAt(DateTime nowUtc) {
    final next = _config.next;
    if (next != null && !nowUtc.toUtc().isBefore(next.effectiveFrom)) {
      return next;
    }
    return _config.current;
  }

  /// Grille connue pour cet identifiant (en vigueur, suivante ou en cache).
  static CommissionGrid? byId(String? id) {
    if (id == null) return null;
    final current = _config.current;
    if (current != null && current.id == id) return current;
    final next = _config.next;
    if (next != null && next.id == id) return next;
    return _cache[id];
  }

  /// Garde une grille lue par identifiant.
  static void put(CommissionGrid grid) => _cache[grid.id] = grid;

  /// Grille [id], lue par [fetch] seulement si l'app ne la connaît pas encore,
  /// puis mise en cache. Ne lève jamais : un échec rend `null` (l'appelant
  /// retombe sur la grille en vigueur ou le taux unique). Les appels
  /// simultanés pour un même identifiant partagent une seule lecture.
  static Future<CommissionGrid?> ensure(
    String? id,
    Future<CommissionGrid?> Function(String id) fetch,
  ) {
    if (id == null) return Future.value();
    final known = byId(id);
    if (known != null) return Future.value(known);
    final pending = _inFlight[id];
    if (pending != null) return pending;
    final load = _load(id, fetch);
    _inFlight[id] = load;
    // Retiré après l'ajout, même si [fetch] a échoué de façon synchrone.
    return load.whenComplete(() => _inFlight.remove(id));
  }

  static Future<CommissionGrid?> _load(
    String id,
    Future<CommissionGrid?> Function(String id) fetch,
  ) async {
    try {
      final grid = await fetch(id);
      if (grid != null) put(grid);
      return grid;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    _config = CommissionGridConfig.none;
    _cache.clear();
    _inFlight.clear();
  }
}

/// Grille applicable maintenant, `null` sans grille connue.
CommissionGrid? get activeCommissionGrid =>
    CommissionGridStore.activeAt(DateTime.now().toUtc());
