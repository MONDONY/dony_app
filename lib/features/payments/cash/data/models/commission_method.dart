enum ExpirationStatus { valid, expiresSoon, expired }

class CommissionMethod {
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final ExpirationStatus expirationStatus;

  const CommissionMethod({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.expirationStatus,
  });

  factory CommissionMethod.fromJson(Map<String, dynamic> json) =>
      CommissionMethod(
        brand: json['brand'] as String,
        last4: json['last4'] as String,
        expMonth: json['expMonth'] as int,
        expYear: json['expYear'] as int,
        expirationStatus: _parseStatus(json['expirationStatus'] as String),
      );

  static ExpirationStatus _parseStatus(String s) => switch (s) {
    'EXPIRES_SOON' => ExpirationStatus.expiresSoon,
    'EXPIRED' => ExpirationStatus.expired,
    _ => ExpirationStatus.valid,
  };

  String get formattedExpiry =>
      '${expMonth.toString().padLeft(2, '0')}/$expYear';
  String get maskedNumber => '•••• •••• •••• $last4';
}
