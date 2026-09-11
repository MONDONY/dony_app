import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter/material.dart';

enum PaymentMethod {
  stripe('STRIPE'),
  cash('CASH'),
  wave('WAVE'),
  orangeMoney('ORANGE_MONEY'),
  mobileMoney('MOBILE_MONEY');

  final String wireName;
  const PaymentMethod(this.wireName);

  /// Valeur reçue de l'API, ou null si l'app ne la connaît pas : une nouvelle
  /// méthode côté backend ne doit jamais faire planter un parsing.
  static PaymentMethod? tryFromWire(String? s) {
    if (s == null) return null;
    for (final e in PaymentMethod.values) {
      if (e.wireName == s) return e;
    }
    return null;
  }

  static PaymentMethod fromWire(String s) =>
      tryFromWire(s) ??
      (throw ArgumentError.value(s, 'PaymentMethod', 'valeur inconnue'));

  /// Ignore les valeurs inconnues au lieu de planter sur toute la liste.
  static Set<PaymentMethod> setFromJson(List<dynamic>? l) => (l ?? const [])
      .map((e) => tryFromWire(e as String?))
      .whereType<PaymentMethod>()
      .toSet();

  /// Ordre canonique d'affichage : carte d'abord, puis cash, puis mobile money.
  static const List<PaymentMethod> canonicalOrder = [
    PaymentMethod.stripe,
    PaymentMethod.cash,
    PaymentMethod.mobileMoney,
    PaymentMethod.wave,
    PaymentMethod.orangeMoney,
  ];

  /// Méthodes proposables dans [currency] : la devise borne les rails, comme
  /// `CurrencyPaymentRails` côté backend. La carte n'existe pas en zone CFA
  /// (pas de Stripe Connect), le mobile money n'existe qu'en zone CFA
  /// (pawaPay en XOF et XAF). Une demande en franc CFA cochait la carte par
  /// défaut et le fil la proposait au voyageur : c'est la devise qui décide.
  static List<PaymentMethod> selectableIn(SupportedCurrency currency) => [
    if (currency.isStripeEligible) PaymentMethod.stripe,
    if (currency.isMobileMoneyEligible) PaymentMethod.mobileMoney,
    PaymentMethod.cash,
  ];

  String get displayLabel {
    switch (this) {
      case PaymentMethod.stripe:
        return 'Carte';
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.wave:
        return 'Wave';
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.mobileMoney:
        return 'Mobile money';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.stripe:
        return Icons.credit_card_rounded;
      case PaymentMethod.cash:
        return Icons.payments_rounded;
      case PaymentMethod.wave:
        return Icons.waves_rounded;
      case PaymentMethod.orangeMoney:
        return Icons.phone_android_rounded;
      case PaymentMethod.mobileMoney:
        return Icons.phone_android_rounded;
    }
  }
}
