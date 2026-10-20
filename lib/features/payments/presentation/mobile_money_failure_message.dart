import 'package:dony/l10n/l10n.dart';

/// Texte d'un échec final de paiement mobile money : celui du code Yadony
/// dans la langue de l'app, sinon le motif déjà traduit par le back (code
/// inconnu de cette version), sinon un message générique.
///
/// Partagé par la recharge du portefeuille et le paiement d'un colis : le
/// back rend les mêmes sept codes dans les deux cas.
String mobileMoneyFailureMessage(
  AppLocalizations l, {
  String? code,
  String? fallback,
}) {
  // Codes Yadony du back (liste fermée), jamais affichés.
  final byCode = switch (code) {
    'insufficient-balance' =>
      l.walletTopupFailureInsufficientBalance, // i18n-ignore
    'not-approved' => l.walletTopupFailureNotApproved, // i18n-ignore
    'payer-limit-reached' => l.walletTopupFailurePayerLimit, // i18n-ignore
    'invalid-number' => l.walletTopupFailureInvalidNumber, // i18n-ignore
    'provider-unavailable' =>
      l.walletTopupFailureProviderUnavailable, // i18n-ignore
    'expired' => l.walletTopupFailureExpired, // i18n-ignore
    'other' => l.walletTopupFailureOther, // i18n-ignore
    _ => null,
  };
  return byCode ?? fallback ?? l.walletTopupFailureOther;
}
