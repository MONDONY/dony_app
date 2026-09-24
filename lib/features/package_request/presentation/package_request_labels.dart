import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Libellé affiché d'une taille de colis.
extension ParcelSizeL10n on ParcelSize {
  String label(AppLocalizations l) => switch (this) {
    ParcelSize.small => l.parcelSizeSmall,
    ParcelSize.medium => l.parcelSizeMedium,
    ParcelSize.large => l.parcelSizeLarge,
  };
}

/// Libellé affiché d'un moyen de paiement.
extension PaymentMethodL10n on PaymentMethod {
  String label(AppLocalizations l) {
    switch (this) {
      case PaymentMethod.stripe:
        return l.paymentMethodCard;
      case PaymentMethod.cash:
        return l.paymentMethodCash;
      case PaymentMethod.wave:
        return 'Wave'; // i18n-ignore — nom de marque
      case PaymentMethod.orangeMoney:
        return 'Orange Money'; // i18n-ignore — nom de marque
      case PaymentMethod.mobileMoney:
        return l.paymentMethodMobileMoney;
    }
  }
}

/// Libellé de prix du fil de négociation, adapté au rôle du lecteur.
///
/// - Le voyageur voit son net : « Tu reçois 35,00 € ».
/// - L'expéditeur voit le brut qu'il paie : « Tu paies 39,20 € » (utilise
///   [gross] si fourni, sinon le calcule depuis [net]).
String threadPriceLabel(
  AppLocalizations l,
  double net,
  double? gross,
  bool isTraveler, [
  String? currencyCode,
]) {
  if (isTraveler) {
    return l.requestThreadYouReceive(PriceDisplay.money(net, currencyCode));
  }
  final g = gross ?? PriceDisplay.grossFromNet(net);
  return l.requestThreadYouPay(PriceDisplay.money(g, currencyCode));
}

/// Fourchette de poids autorisée pour une demande d'envoi, dérivée de
/// [PackageRequestLimits] plutôt que retapée en dur.
String weightRangeLabel(AppLocalizations l) => l.requestWeightRange(
  formatKg(l, PackageRequestLimits.minWeightKg),
  formatKg(l, PackageRequestLimits.maxWeightKg),
);

/// Formate un poids en kilos — décimale unique avec le séparateur de la
/// langue (virgule en français, point en anglais), entier sans décimale.
/// Anciennement figé sur la virgule quelle que soit la langue.
String formatKg(AppLocalizations l, double v) =>
    NumberFormat('#0.#', l.localeName).format(v);

/// Nom de repli affiché quand le profil expéditeur n'a pas de nom (compte
/// invité, ancien payload sans `senderDisplayName`).
String senderFallbackName(AppLocalizations l) => l.requestSenderFallbackName;

/// Tolérance compacte « ±Nj » (« j » = jour, traduit en « d » en anglais).
/// Réutilisée par toutes les cartes de demande affichant une date souhaitée.
String toleranceCompactLabel(AppLocalizations l, int days) =>
    l.requestToleranceDays(days);

/// Nombre d'avis reçus par un expéditeur (« N avis » / « N reviews »).
String reviewCountLabel(AppLocalizations l, int count) =>
    l.requestReviewCount(count);

/// Date courte « jour/mois/année » sans mot. Le français garde l'ancien
/// rendu brut sans zéro de tête (`DateFormat.yMd` en ajoute un — 06/10/2026
/// au lieu de 6/10/2026 — ce qui changerait le texte affiché) ; l'anglais
/// utilise le squelette `yMd`, qui n'a pas de rendu antérieur à préserver.
String shortDayMonthYear(AppLocalizations l, DateTime date) =>
    l.localeName == 'fr'
    ? '${date.day}/${date.month}/${date.year}'
    : DateFormat.yMd(l.localeName).format(date);

/// Date courte « jour/mois » sans année ni mot. Même raison que
/// [shortDayMonthYear] : `DateFormat.Md('fr')` ajoute un zéro de tête que
/// l'ancien rendu n'avait pas.
String shortDayMonth(AppLocalizations l, DateTime date) => l.localeName == 'fr'
    ? '${date.day}/${date.month}'
    : DateFormat.Md(l.localeName).format(date);
