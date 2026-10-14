import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Montant de récompense dans la langue de l'app (« 5 € », « €5 »), sans
/// décimales quand il est rond.
String formatReferralAmount(
  AppLocalizations l,
  double amount,
  String? currency,
) => CurrencyFormatter.format(
  amount,
  SupportedCurrency.fromCodeOrDefault(currency),
  locale: l.localeName,
  compact: true,
);

/// Récompense « crédit sur le solde » promise par le barème courant.
String formatRewardWalletAmount(AppLocalizations l, ReferralInfo info) =>
    formatReferralAmount(
      l,
      info.effectiveRewardWalletAmount,
      info.effectiveRewardWalletCurrency,
    );

/// Crédit réellement obtenu pour [referee], avec repli sur le barème.
String formatRefereeWalletAmount(
  AppLocalizations l,
  Referee referee,
  ReferralInfo info,
) => formatReferralAmount(
  l,
  referee.walletAmount ?? info.effectiveRewardWalletAmount,
  referee.walletCurrency ?? info.effectiveRewardWalletCurrency,
);

/// « 2 oct. » / « Oct 2 ».
String formatReferralShortDate(AppLocalizations l, DateTime date) =>
    DateFormat.MMMd(l.localeName).format(date.toLocal());

/// « 14 avr. 2027 » / « Apr 14, 2027 ».
String formatReferralDate(AppLocalizations l, DateTime date) =>
    DateFormat.yMMMd(l.localeName).format(date.toLocal());
