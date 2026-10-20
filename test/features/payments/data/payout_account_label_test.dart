import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/payout_account_label.dart';
import 'package:flutter_test/flutter_test.dart';

const _orangeCi = MobileMoneyPayoutAccount(
  id: 'a1',
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •••• 56',
);

void main() {
  group('payoutAccountLabel', () {
    const orangeSn = MobileMoneyPayoutAccount(
      id: 'a3',
      provider: 'ORANGE_SEN',
      providerLabel: 'Orange Money',
      brand: 'ORANGE',
      country: 'SN',
      currency: 'XOF',
      msisdnMasked: '',
    );
    const mtnCi = MobileMoneyPayoutAccount(
      id: 'a2',
      provider: 'MTN_MOMO_CIV',
      providerLabel: 'MTN MoMo',
      brand: 'MTN',
      country: 'CI',
      currency: 'XOF',
      msisdnMasked: '',
    );

    test('marque et pays seulement en doublon', () {
      expect(
        payoutAccountLabel(_orangeCi, const [_orangeCi, mtnCi]),
        'Orange Money',
      );
      expect(
        payoutAccountLabel(_orangeCi, const [_orangeCi, orangeSn]),
        'Orange CI',
      );
      expect(
        payoutAccountLabel(orangeSn, const [_orangeCi, orangeSn]),
        'Orange SN',
      );
      expect(
        payoutAccountLabel(mtnCi, const [_orangeCi, orangeSn, mtnCi]),
        'MTN MoMo',
      );
    });
  });

  group('brandCountryLabel', () {
    test('pays vide : repli même en doublon', () {
      expect(
        brandCountryLabel(
          brand: 'ORANGE',
          country: '',
          fallback: 'Orange Money',
          all: const [
            (brand: 'ORANGE', country: 'CI'),
            (brand: 'ORANGE', country: ''),
          ],
        ),
        'Orange Money',
      );
    });

    test('même pays en casse différente : pas un doublon', () {
      expect(
        brandCountryLabel(
          brand: 'ORANGE',
          country: 'ci',
          fallback: 'Orange Money',
          all: const [
            (brand: 'ORANGE', country: 'CI'),
            (brand: 'ORANGE', country: 'ci'),
          ],
        ),
        'Orange Money',
      );
    });
  });

  test('brandDisplayName : sigle court en majuscules, sinon capitalisé', () {
    expect(brandDisplayName('MTN'), 'MTN');
    expect(brandDisplayName('moov'), 'Moov');
    expect(brandDisplayName(' ORANGE '), 'Orange');
  });
}
