// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('PackageRequestFormEvent — égalité de valeur', () {
    test('FormStep1Submitted compare villes, date, tolérance et mode', () {
      FormStep1Submitted make({
        String to = 'Dakar',
        int tolerance = 2,
        TransportMode mode = TransportMode.plane,
      }) => FormStep1Submitted(
        departureCity: 'Paris',
        arrivalCity: to,
        desiredDate: DateTime(2026, 7, 2),
        dateToleranceDays: tolerance,
        transportMode: mode,
      );
      expectValueEquality(make, [
        make(to: 'Abidjan'),
        make(tolerance: 3),
        make(mode: TransportMode.boat),
      ]);
    });

    test(
      'FormStep2Submitted compare poids, taille, catégories et description',
      () {
        FormStep2Submitted make({double kg = 3, String? description}) =>
            FormStep2Submitted(
              weightKg: kg,
              parcelSize: ParcelSize.medium,
              categories: const ['DOCS'],
              description: description,
            );
        expectValueEquality(make, [
          make(kg: 4),
          make(description: 'Livres'),
          FormStep2Submitted(weightKg: 3, parcelSize: ParcelSize.small),
        ]);
      },
    );

    test('FormStep3Submitted compare prix, photos et brouillon', () {
      FormStep3Submitted make({double? price = 40, bool draft = false}) =>
          FormStep3Submitted(
            targetPriceEur: price,
            photoKeys: const ['k1'],
            saveAsDraft: draft,
          );
      expectValueEquality(make, [make(price: null), make(draft: true)]);
    });

    test('événements sans champ : égaux entre eux, distincts par type', () {
      expectValueEquality(() => FormStepBack(), [FormReset()]);
      expectValueEquality(() => FormReset(), [FormStepBack()]);
      expect(FormStepBack().props, isEmpty);
    });

    test('bascules et changements à valeur unique', () {
      expectValueEquality(() => PackageRequestNegotiableToggled(true), [
        PackageRequestNegotiableToggled(false),
      ]);
      expectValueEquality(
        () => PackageRequestPaymentMethodToggled(PaymentMethod.cash),
        [PackageRequestPaymentMethodToggled(PaymentMethod.stripe)],
      );
      expectValueEquality(() => PackageRequestTotalBudgetChanged(50), [
        PackageRequestTotalBudgetChanged(null),
      ]);
      expectValueEquality(
        () => PackageRequestCurrencyChanged(SupportedCurrency.eur),
        [PackageRequestCurrencyChanged(SupportedCurrency.usd)],
      );
      expectValueEquality(() => PackageRequestPromoCodeChanged('YADO10'), [
        PackageRequestPromoCodeChanged('YADO20'),
        PackageRequestPromoCodeChanged(null),
      ]);
    });
  });
}
