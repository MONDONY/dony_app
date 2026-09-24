import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:dony/l10n/l10n.dart';

/// Lignes du sheet « Solde insuffisant ». Première ligne : titre (bodyMedium),
/// suivantes : détails (bodySmall). Sans [breakdown] (ancien back ou même
/// devise) : textes historiques en devise active. Avec : ce que le
/// portefeuille de la devise du colis couvre et ce qui manque sur la devise
/// active, le prélèvement étant fait dans cet ordre côté serveur.
List<String> commissionShortfallLines(
  AppLocalizations l, {
  required CommissionShortfall? breakdown,
  required double requiredCommission,
  required double availableBalance,
  required String? currency,
}) {
  if (breakdown == null) {
    return [
      l.walletShortfallRequired(formatPriceIn(requiredCommission, currency)),
      l.walletShortfallBalance(formatPriceIn(availableBalance, currency)),
    ];
  }
  final bidName = SupportedCurrency.fromCodeOrDefault(
    breakdown.bidCurrency,
  ).name(l);
  final activeName = SupportedCurrency.fromCodeOrDefault(
    breakdown.activeCurrency,
  ).name(l);
  final bidSymbol = SupportedCurrency.fromCodeOrDefault(
    breakdown.bidCurrency,
  ).symbol;
  final commissionBid = formatPriceIn(
    breakdown.commission,
    breakdown.bidCurrency,
  );
  final activeBalance = formatPriceIn(
    breakdown.activeBalance,
    breakdown.activeCurrency,
  );

  if (breakdown.coveredByBidWallet > 0) {
    return [
      l.walletShortfallCommission(commissionBid),
      l.walletShortfallCovered(
        bidName,
        formatPriceIn(breakdown.coveredByBidWallet, breakdown.bidCurrency),
      ),
      l.walletShortfallMissing(
        formatPriceIn(breakdown.remainingBid, breakdown.bidCurrency),
        formatPriceIn(breakdown.remainingInActive, breakdown.activeCurrency),
        activeName,
        activeBalance,
      ),
    ];
  }
  return [
    l.walletShortfallCommissionConverted(
      commissionBid,
      formatPriceIn(breakdown.remainingInActive, breakdown.activeCurrency),
    ),
    l.walletShortfallTopUpHint(activeName, activeBalance, bidSymbol),
  ];
}
