import 'package:dony/features/payments/bloc/mobile_money_account_active.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mobileMoneyAccountCurrencyFrom', () {
    test('compte actif : devise de l\'opérateur', () {
      const state = MobileMoneyAccountLoaded(
        MobileMoneyAccount(
          status: MobileMoneyAccountStatus.active,
          currency: 'XOF',
        ),
      );

      expect(mobileMoneyAccountActiveFrom(state), isTrue);
      expect(mobileMoneyAccountCurrencyFrom(state), 'XOF');
    });

    test('compte désactivé : aucune devise', () {
      const state = MobileMoneyAccountLoaded(
        MobileMoneyAccount(
          status: MobileMoneyAccountStatus.disabled,
          currency: 'XOF',
        ),
      );

      expect(mobileMoneyAccountActiveFrom(state), isFalse);
      expect(mobileMoneyAccountCurrencyFrom(state), isNull);
    });

    test('compte pas encore chargé : aucune devise', () {
      const state = MobileMoneyAccountInitial();

      expect(mobileMoneyAccountActiveFrom(state), isFalse);
      expect(mobileMoneyAccountCurrencyFrom(state), isNull);
    });
  });
}
