import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';

/// Lecture d'une grille de commission par identifiant
/// (`IConfigRepository.getCommissionGridById`).
typedef CommissionGridLoader = Future<CommissionGrid?> Function(String id);

/// Attente maximale de la grille figée d'un fil avant de l'afficher : au-delà,
/// le fil s'affiche avec la grille en vigueur et la lecture continue en cache.
const kThreadGridPreloadTimeout = Duration(seconds: 3);

/// Prix d'un fil de demande, calculé sur la grille figée du fil.
///
/// Les montants servis par le serveur (`grossPriceEur`, devis) priment
/// toujours : ce calcul n'est qu'un repli, et il doit tomber sur le même
/// montant que le back.
///
/// - Fil avec `commissionGridId` : grille figée du fil, connue du store
///   (chargée par [preloadCommissionGrids] avant l'émission du fil), sinon la
///   grille en vigueur faute de mieux.
/// - Fil sans `commissionGridId` (fil d'avant les grilles, champ absent du
///   back quand il est nul) : taux unique, comme le back qui le calcule ainsi
///   (Ruling A8). Sans grille publiée, c'est aussi le comportement historique.
class ThreadPricer {
  /// Prix sur la grille [gridId], taux unique quand elle est nulle.
  const ThreadPricer({this.gridId, this.currency = 'EUR'});

  factory ThreadPricer.of(NegotiationThread thread) =>
      ThreadPricer(gridId: thread.commissionGridId, currency: thread.currency);

  /// Grille figée du fil, `null` pour un fil d'avant les grilles.
  final String? gridId;

  /// Devise du fil.
  final String currency;

  /// Prix expéditeur pour [net], sans réduction personnelle.
  ///
  /// La grille est relue à chaque appel : une grille figée arrivée en cache
  /// après la construction est prise en compte au prochain rendu.
  SenderPrice priceFor(double net) {
    final id = gridId;
    if (id == null) return senderPriceForNet(net, currency, legacy: true);
    return senderPriceForNet(
      net,
      currency,
      grid: CommissionGridStore.byId(id) ?? activeCommissionGrid,
    );
  }

  /// Décomposition à afficher pour [net] : le brut [servedGross] du serveur
  /// quand il existe (frais = brut − net), sinon le calcul local.
  ///
  /// La mention « minimum » n'est reprise du calcul local que s'il retombe sur
  /// le même brut que le serveur (à la demi-unité mineure près) : un brut
  /// scellé avec une réduction ne dit rien du minimum.
  SenderPrice resolve(double net, {double? servedGross}) {
    final local = priceFor(net);
    if (servedGross == null) return local;
    final half = _halfMinorUnit(currency);
    return SenderPrice(
      net: net,
      commission: servedGross - net,
      gross: servedGross,
      minimumApplied:
          local.minimumApplied && (local.gross - servedGross).abs() < half,
      fromGrid: local.fromGrid,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThreadPricer &&
      other.gridId == gridId &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(gridId, currency);
}

/// Charge en cache les grilles figées [ids] inconnues de l'app avant
/// d'afficher les fils qui les portent. Ne lève jamais et rend la main au plus
/// tard après [timeout] : un échec ou une lenteur laisse la grille en vigueur
/// s'appliquer (voir [ThreadPricer.priceFor]).
Future<void> preloadCommissionGrids(
  Iterable<String?> ids,
  CommissionGridLoader? loader, {
  Duration timeout = kThreadGridPreloadTimeout,
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

double _halfMinorUnit(String currencyCode) {
  var unit = 1.0;
  final digits = SupportedCurrency.fromCodeOrDefault(currencyCode).minorUnit;
  for (var i = 0; i < digits; i++) {
    unit /= 10;
  }
  return unit / 2;
}
