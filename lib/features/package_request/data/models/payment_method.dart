import 'package:flutter/material.dart';

enum PaymentMethod {
  stripe('STRIPE'),
  cash('CASH'),
  wave('WAVE'),
  orangeMoney('ORANGE_MONEY');

  final String wireName;
  const PaymentMethod(this.wireName);

  static PaymentMethod fromWire(String s) =>
      PaymentMethod.values.firstWhere((e) => e.wireName == s);

  static Set<PaymentMethod> setFromJson(List<dynamic>? l) =>
      (l ?? const []).map((e) => fromWire(e as String)).toSet();

  /// Ordre canonique d'affichage : carte d'abord, puis cash, puis mobile money.
  static const List<PaymentMethod> canonicalOrder = [
    PaymentMethod.stripe,
    PaymentMethod.cash,
    PaymentMethod.wave,
    PaymentMethod.orangeMoney,
  ];

  /// Méthodes proposables sur une nouvelle demande. Le mobile money est
  /// retiré (backend : request/mobile-money-payment-retired) mais reste dans
  /// l'enum pour désérialiser et afficher les demandes existantes.
  static const List<PaymentMethod> selectable = [
    PaymentMethod.stripe,
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
    }
  }
}
