// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

MobileMoneyPayoutAccount _account(String id) => MobileMoneyPayoutAccount(
  id: id,
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money CI',
  brand: 'ORANGE',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •• 36',
);

void main() {
  group('MobileMoneyAccountEvent — égalité de valeur', () {
    test('lecture de la liste : égale à elle-même, distincte du retrait', () {
      expectValueEquality(() => MobileMoneyAccountsRequested(), [
        MobileMoneyAccountRemoveRequested(_account('a1')),
      ]);
    });

    test('ajout : numéro et opérateur comparés', () {
      expectValueEquality(
        () => MobileMoneyAccountAddRequested(
          phoneNumber: '+22507000036',
          provider: 'ORANGE_CIV',
        ),
        [
          MobileMoneyAccountAddRequested(
            phoneNumber: '+22507000037',
            provider: 'ORANGE_CIV',
          ),
          MobileMoneyAccountAddRequested(
            phoneNumber: '+22507000036',
            provider: 'WAVE_CIV',
          ),
        ],
      );
    });

    test('changement de numéro : compte et numéro comparés', () {
      expectValueEquality(
        () => MobileMoneyAccountNumberChangeRequested(
          account: _account('a1'),
          phoneNumber: '+22507000036',
        ),
        [
          MobileMoneyAccountNumberChangeRequested(
            account: _account('a2'),
            phoneNumber: '+22507000036',
          ),
          MobileMoneyAccountNumberChangeRequested(
            account: _account('a1'),
            phoneNumber: '+22507000037',
          ),
        ],
      );
    });

    test('retrait : compte comparé', () {
      expectValueEquality(
        () => MobileMoneyAccountRemoveRequested(_account('a1')),
        [MobileMoneyAccountRemoveRequested(_account('a2'))],
      );
    });
  });
}
