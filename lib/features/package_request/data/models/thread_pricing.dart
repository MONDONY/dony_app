import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';

/// Prix d'un fil de demande, calculé sur la grille figée du fil.
///
/// Les montants servis par le serveur (`grossPriceEur`, devis) priment
/// toujours : ce calcul n'est qu'un repli, et il doit tomber sur le même
/// montant que le back.
///
/// - Fil avec `commissionGridId` : grille figée du fil, connue du store
///   (chargée par `preloadCommissionGrids` avant l'émission du fil), sinon la
///   grille en vigueur faute de mieux.
/// - Fil sans `commissionGridId` (fil d'avant les grilles, champ absent du
///   back quand il est nul) : taux unique, comme le back qui le calcule ainsi
///   (Ruling A8). Sans grille publiée, c'est aussi le comportement historique.
class ThreadPricer {
  /// Prix sur la grille [gridId], taux unique quand elle est nulle
  /// ([legacyRate], sinon le taux global).
  const ThreadPricer({
    this.gridId,
    this.currency = 'EUR',
    this.legacyRate,
    this.currentNet,
    this.servedGross,
  });

  factory ThreadPricer.of(NegotiationThread thread) => ThreadPricer(
    gridId: thread.commissionGridId,
    currency: thread.currency,
    legacyRate: thread.commissionRate,
    currentNet: thread.currentPriceEur,
    servedGross: thread.grossPriceEur,
  );

  /// Grille figée du fil, `null` pour un fil d'avant les grilles.
  final String? gridId;

  /// Devise du fil.
  final String currency;

  /// Taux figé du fil sans grille (`commissionRate` du back), `null` avant le
  /// premier paiement : le taux global s'applique alors, comme le back
  /// (`displayRate = thread.commissionRate ?? globalRate`).
  final double? legacyRate;

  /// Prix courant (net) du fil et brut que le serveur sert pour lui : une
  /// bulle ou un aperçu au prix courant reprend ce brut, comme l'en-tête et le
  /// bouton « Accepter ».
  final double? currentNet;
  final double? servedGross;

  /// Brut servi par le serveur pour [net] : seulement quand [net] est le prix
  /// courant du fil (à la demi-unité mineure près), `null` sinon.
  double? servedGrossFor(double net) {
    final current = currentNet;
    final gross = servedGross;
    if (current == null || gross == null) return null;
    return (net - current).abs() < _half ? gross : null;
  }

  /// Prix expéditeur pour [net], sans réduction personnelle.
  ///
  /// La grille est relue à chaque appel : une grille figée arrivée en cache
  /// après la construction est prise en compte au prochain rendu.
  SenderPrice priceFor(double net) {
    final id = gridId;
    if (id == null) {
      return senderPriceForNet(
        net,
        currency,
        legacy: true,
        legacyRate: legacyRate,
      );
    }
    return senderPriceForNet(
      net,
      currency,
      grid: CommissionGridStore.byId(id) ?? activeCommissionGrid,
    );
  }

  /// Décomposition à afficher pour [net] : le montant du serveur quand il
  /// existe, sinon le calcul local. [servedCommission] (frais servis, ex.
  /// commission espèces du voyageur) prime sur [servedGross] (brut servi,
  /// frais = brut − net).
  ///
  /// La mention « minimum » n'est reprise du calcul local que s'il retombe sur
  /// les mêmes frais que le serveur (à la demi-unité mineure près) : des frais
  /// servis avec une réduction ne disent rien du minimum.
  SenderPrice resolve(
    double net, {
    double? servedGross,
    double? servedCommission,
  }) {
    final local = priceFor(net);
    final commission =
        servedCommission ?? (servedGross == null ? null : servedGross - net);
    if (commission == null) return local;
    final half = _half;
    return SenderPrice(
      net: net,
      commission: commission,
      gross: net + commission,
      minimumApplied:
          local.minimumApplied && (local.commission - commission).abs() < half,
      fromGrid: local.fromGrid,
    );
  }

  double get _half =>
      halfMinorUnit(SupportedCurrency.fromCodeOrDefault(currency));

  @override
  bool operator ==(Object other) =>
      other is ThreadPricer &&
      other.gridId == gridId &&
      other.currency == currency &&
      other.legacyRate == legacyRate &&
      other.currentNet == currentNet &&
      other.servedGross == servedGross;

  @override
  int get hashCode =>
      Object.hash(gridId, currency, legacyRate, currentNet, servedGross);
}
