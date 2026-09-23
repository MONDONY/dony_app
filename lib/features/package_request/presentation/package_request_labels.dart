import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:dony/l10n/l10n.dart';

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
  formatKg(PackageRequestLimits.minWeightKg),
  formatKg(PackageRequestLimits.maxWeightKg),
);

/// Formate un poids en kilos — inchangé depuis l'ancien `PackageRequestLimits
/// ._fr` (déplacé ici, rendu public). Décimale unique avec virgule, entier
/// sans décimale, quelle que soit la langue.
String formatKg(double v) => (v.truncateToDouble() == v
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceFirst('.', ','));

/// Nom de repli affiché quand le profil expéditeur n'a pas de nom (compte
/// invité, ancien payload sans `senderDisplayName`).
String senderFallbackName(AppLocalizations l) => l.requestSenderFallbackName;
