import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';

/// Libellé affiché d'un compte de versement parmi [all].
///
/// D'ordinaire le libellé de l'opérateur (« Orange Money »). Quand une autre
/// ligne de [all] porte la même marque dans un autre pays (`ORANGE_CIV` et
/// `ORANGE_SEN`), « Orange Money » ne dit plus de quel compte il s'agit : le
/// libellé devient la marque suivie du code pays (« Orange CI »,
/// « Orange SN »), comme les pastilles de la fiche d'un trajet.
String payoutAccountLabel(
  MobileMoneyPayoutAccount account,
  List<MobileMoneyPayoutAccount> all,
) => brandCountryLabel(
  brand: account.brand,
  country: account.country,
  fallback: account.providerLabel,
  all: [for (final a in all) (brand: a.brand, country: a.country)],
);

/// Cœur de [payoutAccountLabel], valable pour tout réseau décrit par sa marque
/// et son pays (compte de versement, pastille de la fiche d'un trajet,
/// opérateur habituel de l'expéditeur) : [fallback] tant que la marque n'est
/// portée que par un pays dans [all], sinon la marque suivie du code pays.
String brandCountryLabel({
  required String brand,
  required String country,
  required String fallback,
  required Iterable<({String brand, String country})> all,
}) {
  final twin = all.any(
    (other) =>
        other.brand == brand &&
        other.country.toUpperCase() != country.toUpperCase(),
  );
  if (!twin || country.isEmpty) return fallback;
  return '${brandDisplayName(brand)} ${country.toUpperCase()}';
}

/// Nom de marque lisible depuis son code (`ORANGE` devient « Orange »). Un
/// sigle court (`MTN`) reste en majuscules.
String brandDisplayName(String brand) {
  final b = brand.trim();
  if (b.length <= 3) return b.toUpperCase();
  return b[0].toUpperCase() + b.substring(1).toLowerCase();
}
