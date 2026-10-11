// Constructeurs appelés à l'exécution : deux instances `const` identiques
// court-circuitent la comparaison Equatable.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  test('MobileMoneyStatusPolled : la portée (offre ou fil) distingue', () {
    expectValueEquality(
      () => MobileMoneyStatusPolled(scope: MobileMoneyScope.bid('b-1')),
      [
        MobileMoneyStatusPolled(scope: MobileMoneyScope.bid('b-2')),
        MobileMoneyStatusPolled(scope: MobileMoneyScope.negotiation('b-1')),
        MobileMoneyPaymentOpened(scope: MobileMoneyScope.bid('b-1')),
      ],
    );
  });
}
