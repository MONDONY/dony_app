import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';

/// Lignes du sheet « Solde insuffisant ». Première ligne : titre (bodyMedium),
/// suivantes : détails (bodySmall). Sans [breakdown] (ancien back ou même
/// devise) : textes historiques en devise active. Avec : ce que le
/// portefeuille de la devise du colis couvre et ce qui manque sur la devise
/// active, le prélèvement étant fait dans cet ordre côté serveur.
List<String> commissionShortfallLines({
  required CommissionShortfall? breakdown,
  required double requiredCommission,
  required double availableBalance,
  required String? currency,
}) {
  if (breakdown == null) {
    return [
      'Commission requise : ${formatPriceIn(requiredCommission, currency)}',
      'Solde du portefeuille : ${formatPriceIn(availableBalance, currency)}',
    ];
  }
  final bidName = SupportedCurrency.fromCodeOrDefault(
    breakdown.bidCurrency,
  ).displayName;
  final activeName = SupportedCurrency.fromCodeOrDefault(
    breakdown.activeCurrency,
  ).displayName;
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
      'Commission : $commissionBid',
      'Ton portefeuille $bidName en couvre '
          '${formatPriceIn(breakdown.coveredByBidWallet, breakdown.bidCurrency)}',
      'Il manque ${formatPriceIn(breakdown.remainingBid, breakdown.bidCurrency)}, '
          'soit ${formatPriceIn(breakdown.remainingInActive, breakdown.activeCurrency)}, '
          'et ton portefeuille $activeName n\'a que $activeBalance',
    ];
  }
  return [
    'Commission : $commissionBid, soit '
        '${formatPriceIn(breakdown.remainingInActive, breakdown.activeCurrency)}',
    'Ton portefeuille $activeName n\'a que $activeBalance. '
        'Recharge en $bidSymbol ou en $activeName, ou paie par carte.',
  ];
}
