import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Montant formaté dans sa devise (sans décimales inutiles).
String formatMoney(double amount, String? currency) => CurrencyFormatter.format(
  amount,
  SupportedCurrency.fromCodeOrDefault(currency),
  compact: true,
);

/// Seuil (valeur absolue) à partir duquel [formatMoneyShort] abrège.
const double kMoneyShortThreshold = 10000;

/// Montant abrégé pour la pastille portefeuille de l'en-tête (FLUTTER-NW) :
/// dès [kMoneyShortThreshold], « 22,1 k F CFA », « 1,2 M F CFA »,
/// « 12,5 k € » (« 22 k » quand la décimale est nulle). Séparateur décimal de
/// la langue de l'app ([localeName]), symbole placé comme dans le format
/// complet de la devise (« £12.5k »). En dessous du seuil : [formatMoney].
///
/// Réservé à la pastille : le montant exact reste affiché partout ailleurs
/// (« Mon argent », portefeuille, libellé d'accessibilité de la pastille).
String formatMoneyShort(double amount, String? currency, String localeName) {
  if (amount.abs() < kMoneyShortThreshold) {
    return formatMoney(amount, currency);
  }
  final c = SupportedCurrency.fromCodeOrDefault(currency);
  final abs = amount.abs();
  double rounded(double divisor) => (abs / divisor * 10).round() / 10;
  var value = rounded(1000);
  var unit = 'k'; // i18n-ignore : symbole d'unité (kilo), identique fr/en
  // 999 950 arrondi donne « 1 000 k » : on passe au million.
  if (abs >= 1000000 || value >= 1000) {
    value = rounded(1000000);
    unit = 'M'; // i18n-ignore : symbole d'unité (méga), identique fr/en
  }
  final number = NumberFormat('#,##0.#', localeName).format(value);
  final sign = amount < 0 ? '-' : '';
  // Même place du symbole que le format complet de la devise.
  final symbolFirst = CurrencyFormatter.format(1, c).startsWith(c.symbol);
  return symbolFirst
      ? '$sign${c.symbol}$number$unit'
      : '$sign$number\u00a0$unit\u00a0${c.symbol}';
}

/// Montants par devise, jamais additionnés : « 155 € · 7 950 F CFA ».
String formatAmounts(List<MoneyAmount> amounts) =>
    amounts.map((a) => formatMoney(a.amount, a.currency)).join(' · ');

/// Date courte d'échéance : « 18 oct. ».
String shortDate(DateTime d, AppLocalizations l) =>
    DateFormat.MMMd(l.localeName).format(d);

/// Jour d'un versement daté : « sam. 11 oct. ».
String dayDate(DateTime d, AppLocalizations l) =>
    DateFormat.MMMEd(l.localeName).format(d);

/// « Paris → Abidjan », ou `null` sans aucune ville.
String? routeOf(String? from, String? to) {
  final parts = [from, to].whereType<String>().where((s) => s.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' → ');
}

/// Ton d'un état court.
enum MoneyTone { neutral, positive, info, attention }

/// État court d'un colis (« à la livraison », « versé le 11 oct. »…), pour
/// les lignes compactes des écrans « Mon argent » et « Mes trajets ».
({String text, MoneyTone tone}) shortStateFor(
  MoneyItemModel item,
  AppLocalizations l,
) {
  switch (item.state) {
    case MoneyState.escrowed:
    case MoneyState.awaitingDeliveryConfirmation:
      return (text: l.moneyShortOnDelivery, tone: MoneyTone.neutral);
    case MoneyState.releaseScheduled:
      final at = item.releaseAt;
      return at == null
          ? (text: l.moneyShortOnDelivery, tone: MoneyTone.neutral)
          : (text: l.moneyShortAuto(shortDate(at, l)), tone: MoneyTone.info);
    case MoneyState.inDispute:
      return (text: l.moneyShortDispute, tone: MoneyTone.attention);
    case MoneyState.onHold:
      return (text: l.moneyShortReview, tone: MoneyTone.attention);
    case MoneyState.payoutInProgress:
      return (text: l.moneyShortInProgress, tone: MoneyTone.info);
    case MoneyState.releasedRecently:
      final at = item.settledAt;
      return (
        text: at == null
            ? l.moneyShortReleasedNoDate
            : l.moneyShortReleased(shortDate(at, l)),
        tone: MoneyTone.positive,
      );
    case MoneyState.refundPending:
      return (text: l.moneyShortRefundPending, tone: MoneyTone.neutral);
    case MoneyState.refundedRecently:
      final at = item.settledAt;
      return (
        text: at == null
            ? l.moneyShortRefundedNoDate
            : l.moneyShortRefunded(shortDate(at, l)),
        tone: MoneyTone.neutral,
      );
    case MoneyState.cash:
      // La commission ne concerne que le voyageur, qui la règle à Yadony.
      final commission = item.role == MoneyRole.traveler
          ? switch (item.cashCommissionStatus) {
              'CHARGED' =>
                l.moneyCashCommissionSettled, // i18n-ignore : code serveur
              'REFUNDED' => l.moneyCashCommissionRefunded, // i18n-ignore
              null => null,
              _ => l.moneyCashCommissionPending,
            }
          : null;
      return (
        text: commission == null
            ? l.moneyShortCash
            : '${l.moneyShortCash} · $commission',
        tone: MoneyTone.neutral,
      );
    case MoneyState.unknown:
      return (text: l.moneyShortUnknown, tone: MoneyTone.neutral);
  }
}
