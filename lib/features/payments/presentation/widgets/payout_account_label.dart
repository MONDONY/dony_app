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
) {
  final twin = all.any(
    (other) =>
        other.brand == account.brand &&
        other.country.toUpperCase() != account.country.toUpperCase(),
  );
  if (!twin || account.country.isEmpty) return account.providerLabel;
  return '${brandDisplayName(account.brand)} ${account.country.toUpperCase()}';
}

/// Nom de marque lisible depuis son code (`ORANGE` devient « Orange »). Un
/// sigle court (`MTN`) reste en majuscules.
String brandDisplayName(String brand) {
  final b = brand.trim();
  if (b.length <= 3) return b.toUpperCase();
  return b[0].toUpperCase() + b.substring(1).toLowerCase();
}
