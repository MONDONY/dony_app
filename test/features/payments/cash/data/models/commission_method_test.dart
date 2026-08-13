import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses from JSON', () {
    final json = {
      'brand': 'visa',
      'last4': '4242',
      'expMonth': 12,
      'expYear': 2028,
      'expirationStatus': 'VALID',
    };
    final m = CommissionMethod.fromJson(json);
    expect(m.brand, 'visa');
    expect(m.last4, '4242');
    expect(m.expMonth, 12);
    expect(m.expYear, 2028);
    expect(m.expirationStatus, ExpirationStatus.valid);
  });

  test('formats expiry as MM/YYYY', () {
    const m = CommissionMethod(
      brand: 'visa',
      last4: '4242',
      expMonth: 3,
      expYear: 2027,
      expirationStatus: ExpirationStatus.valid,
    );
    expect(m.formattedExpiry, '03/2027');
  });

  test('maskedNumber uses bullet characters', () {
    const m = CommissionMethod(
      brand: 'mastercard',
      last4: '1234',
      expMonth: 1,
      expYear: 2030,
      expirationStatus: ExpirationStatus.expiresSoon,
    );
    expect(m.maskedNumber, '•••• •••• •••• 1234');
  });

  test('parses EXPIRES_SOON and EXPIRED statuses', () {
    final m1 = CommissionMethod.fromJson({
      'brand': 'visa',
      'last4': '0001',
      'expMonth': 1,
      'expYear': 2025,
      'expirationStatus': 'EXPIRES_SOON',
    });
    expect(m1.expirationStatus, ExpirationStatus.expiresSoon);

    final m2 = CommissionMethod.fromJson({
      'brand': 'visa',
      'last4': '0002',
      'expMonth': 1,
      'expYear': 2024,
      'expirationStatus': 'EXPIRED',
    });
    expect(m2.expirationStatus, ExpirationStatus.expired);
  });
}
