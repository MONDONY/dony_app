// Propriétés analytics partagées entre features, sans PII.

/// Tranche de montant pour l'analytics, **sans symbole monétaire**.
///
/// Les bornes s'entendaient auparavant en euros et portaient le « € » dans leur
/// libellé, alors qu'elles s'appliquaient au montant brut quelle que soit la
/// devise : une proposition de 5 000 XOF, soit environ 7,60 €, atterrissait
/// dans « >100€ » et faussait toute lecture des données. La tranche est donc
/// neutre et la devise est envoyée à côté (`currency`), ce qui permet de
/// segmenter correctement sans jamais convertir de montant ni envoyer le
/// montant exact.
String analyticsAmountBracket(double amount) {
  if (amount < 20) return '<20';
  if (amount < 50) return '20-50';
  if (amount < 100) return '50-100';
  return '>100';
}

/// Valeurs de la propriété `method` des événements d'argent
/// (`payment_*`, `wallet_topup_*`, `wallet_refund_*`).
///
/// Une seule propriété et une seule casse pour le moyen de paiement : le code
/// en mélangeait trois (`method`, `payment_method`, `provider`), en
/// majuscules ou non, et `wallet` désignait tantôt Apple Pay / Google Pay,
/// tantôt le solde Yadony. `provider` reste à côté pour l'opérateur mobile
/// money (Orange Money, Wave…).
abstract final class AnalyticsPaymentMethod {
  static const card = 'card';

  /// Apple Pay / Google Pay.
  static const platformPay = 'platform_pay';
  static const paypal = 'paypal';
  static const mobileMoney = 'mobile_money';

  /// Code de recharge du solde.
  static const voucher = 'voucher';

  /// Solde Yadony.
  static const walletBalance = 'wallet_balance';
  static const cash = 'cash';
}

/// Valeurs de la propriété `context` : le parcours qui déplace l'argent.
abstract final class AnalyticsPaymentContext {
  /// Offre sur un trajet payée à l'envoi.
  static const bid = 'bid';

  /// Fil de négociation d'un trajet.
  static const tripNegotiation = 'trip_negotiation';

  /// Fil de négociation d'une demande d'envoi.
  static const negotiation = 'negotiation';

  /// Paiement d'une offre acceptée (`/payments/pay`).
  static const escrow = 'escrow';
  static const walletTopup = 'wallet_topup';

  /// Commission Yadony d'un accord en espèces.
  static const commission = 'commission';
}

/// Moyen de retour d'un remboursement du solde, depuis le `rail` serveur :
/// `card` (Stripe), `mobile_money` (pawaPay), `manual`, ou `unknown` sur
/// l'ancien contrat.
String analyticsRefundMethod(String? rail) => switch (rail) {
  'STRIPE' => AnalyticsPaymentMethod.card, // i18n-ignore
  'PAWAPAY' => AnalyticsPaymentMethod.mobileMoney, // i18n-ignore
  'MANUAL' => 'manual', // i18n-ignore
  _ => 'unknown',
};
