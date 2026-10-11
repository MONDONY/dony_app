// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('BusinessPrefsEvent — égalité de valeur', () {
    test('préférences existantes', () {
      expectValueEquality(() => WeightUnitChanged('kg'), [
        WeightUnitChanged('lb'),
      ]);
      expectValueEquality(() => CurrencyChanged('EUR'), [
        CurrencyChanged('XOF'),
        CountryChanged('EUR'),
      ]);
      expectValueEquality(() => CountryChanged('SN'), [CountryChanged('CI')]);
      expectValueEquality(() => PickupRadiusChanged(10), [
        PickupRadiusChanged(20),
      ]);
    });

    test('nouvelles préférences, valeur nulle comprise', () {
      expectValueEquality(() => DefaultWeightChanged(5), [
        DefaultWeightChanged(6),
      ]);
      expectValueEquality(() => MinBidPriceChanged(15), [
        MinBidPriceChanged(25),
      ]);
      expectValueEquality(() => ContactModeChanged('CHAT'), [
        ContactModeChanged(null),
      ]);
      expectValueEquality(() => ResponseDelayChanged(24), [
        ResponseDelayChanged(null),
      ]);
      expectValueEquality(() => DisplayCurrencyChanged('XOF'), [
        DisplayCurrencyChanged('EUR'),
      ]);
    });

    test('synchronisation et remise à zéro : sans champ, distinctes', () {
      expectValueEquality(() => BusinessPrefsSyncRequested(), [
        BusinessPrefsReset(),
      ]);
      expectValueEquality(() => BusinessPrefsReset(), [
        BusinessPrefsSyncRequested(),
      ]);
      expect(BusinessPrefsReset().props, isEmpty);
    });
  });
}
