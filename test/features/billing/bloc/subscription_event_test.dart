// Constructeurs appelés à l'exécution : deux instances `const` identiques
// court-circuitent la comparaison Equatable.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  test('SubscriptionRequested : sans champ, distinct de l’ouverture du '
      'portail', () {
    expectValueEquality(() => SubscriptionRequested(), [
      ProPortalOpenRequested(ProPortalTarget.manage),
    ]);
    expect(SubscriptionRequested().props, isEmpty);
  });

  test('ProPortalOpenRequested : la cible distingue', () {
    expectValueEquality(() => ProPortalOpenRequested(ProPortalTarget.upgrade), [
      ProPortalOpenRequested(ProPortalTarget.manage),
    ]);
  });
}
