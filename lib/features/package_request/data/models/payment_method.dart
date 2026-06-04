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

  String get displayLabel {
    switch (this) {
      case PaymentMethod.stripe:
        return 'Carte';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.wave:
        return 'Wave';
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
    }
  }
}
