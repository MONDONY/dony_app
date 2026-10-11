// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('MobileMoneyAccountEvent — égalité de valeur', () {
    test('événements sans champ : égaux entre eux, distincts par type', () {
      expectValueEquality(() => MobileMoneyAccountRequested(), [
        MobileMoneyAccountDisableRequested(),
      ]);
      expectValueEquality(() => MobileMoneyAccountDisableRequested(), [
        MobileMoneyAccountRequested(),
      ]);
      expectValueEquality(() => MobileMoneyAccountProvidersCleared(), [
        MobileMoneyAccountChangeNumberRequested(),
      ]);
      expectValueEquality(() => MobileMoneyAccountChangeNumberRequested(), [
        MobileMoneyAccountChangeNumberCancelled(),
      ]);
      expectValueEquality(() => MobileMoneyAccountChangeNumberCancelled(), [
        MobileMoneyAccountChangeNumberRequested(),
      ]);
    });

    test('activation et opérateurs : numéro et liste comparés', () {
      expectValueEquality(
        () => MobileMoneyAccountActivateRequested(
          phoneNumber: '+221770000000',
          providers: const ['WAVE'],
        ),
        [
          MobileMoneyAccountActivateRequested(phoneNumber: '+221770000000'),
          MobileMoneyAccountActivateRequested(providers: const ['WAVE']),
        ],
      );
      expectValueEquality(
        () => MobileMoneyAccountProvidersRequested(phoneNumber: '+2217'),
        [MobileMoneyAccountProvidersRequested()],
      );
      expectValueEquality(
        () => MobileMoneyAccountProvidersUpdateRequested(const ['OM']),
        [
          MobileMoneyAccountProvidersUpdateRequested(const ['OM', 'WAVE']),
        ],
      );
    });
  });
}
