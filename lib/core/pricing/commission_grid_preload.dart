import 'dart:async';

import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';

/// Lecture d'une grille de commission par identifiant
/// (`IConfigRepository.getCommissionGridById`).
typedef CommissionGridLoader = Future<CommissionGrid?> Function(String id);

/// Attente maximale de la grille figée d'un fil (demande ou trajet) avant de
/// l'afficher : au-delà, le fil s'affiche avec la grille en vigueur et la
/// lecture continue en cache.
const kCommissionGridPreloadTimeout = Duration(seconds: 3);

/// Charge en cache ([CommissionGridStore]) les grilles figées [ids] inconnues
/// de l'app avant d'afficher les fils qui les portent. Ne lève jamais et rend
/// la main au plus tard après [timeout] : un échec ou une lenteur laisse la
/// grille en vigueur s'appliquer aux aperçus de prix.
Future<void> preloadCommissionGrids(
  Iterable<String?> ids,
  CommissionGridLoader? loader, {
  Duration timeout = kCommissionGridPreloadTimeout,
}) async {
  if (loader == null) return;
  final missing = ids
      .whereType<String>()
      .where((id) => CommissionGridStore.byId(id) == null)
      .toSet();
  if (missing.isEmpty) return;
  try {
    await Future.wait(
      missing.map((id) => CommissionGridStore.ensure(id, loader)),
    ).timeout(timeout);
  } on TimeoutException {
    // La lecture continue en arrière-plan et remplira le cache.
  }
}
