import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('défauts = formulaire vierge', () {
    final f = TripFormFields();
    expect(f.currency.value, SupportedCurrency.eur);
    expect(f.availableKg.value, 15);
    expect(f.priceOption.value, -1);
    expect(f.pricePerKg, isNull);
    expect(f.kgPriceEnabled.value, isTrue);
    expect(f.cashEnabled.value, isFalse);
    expect(f.mobileMoneyEnabled.value, isFalse);
    expect(f.negotiable.value, isFalse);
    expect(f.selectedContent.value, contains('Vêtements & tissus'));
    expect(f.presets, [5, 6, 7, 8]);
    f.dispose();
  });

  test('presets suivent la devise', () {
    final f = TripFormFields(initialCurrency: SupportedCurrency.xof);
    expect(f.presets, [1000, 1500, 2000, 3000]);
    f.currency.value = SupportedCurrency.eur;
    expect(f.presets, [5, 6, 7, 8]);
    f.dispose();
  });

  test('selectPrice : chip exacte, sinon Autre prix, null efface', () {
    final f = TripFormFields();
    f.selectPrice(7);
    expect(f.priceOption.value, 2);
    expect(f.isCustomPrice, isFalse);
    expect(f.pricePerKg, 7);

    f.selectPrice(9.5);
    expect(f.isCustomPrice, isTrue);
    expect(f.customPrice.value, 9.5);
    // Ruling contrôleur : selectPrice écrit avec formatKgPrice, qui rend
    // « 9.50 » pour 9,5 (2 décimales si non entier).
    expect(f.customPriceCtrl.text, '9.50');
    expect(f.pricePerKg, 9.5);

    f.selectPrice(null);
    expect(f.priceOption.value, -1);
    expect(f.pricePerKg, isNull);
    f.dispose();
  });

  test('pricePerKg nul quand le prix au kilo est désactivé', () {
    final f = TripFormFields();
    f.selectPrice(6);
    f.kgPriceEnabled.value = false;
    expect(f.pricePerKg, isNull);
    f.dispose();
  });

  test(
    'acceptedPaymentMethodsFor : Stripe selon devise et compte, cash forcé sans Stripe',
    () {
      final f = TripFormFields();
      expect(f.acceptedPaymentMethodsFor(stripeConfigured: true), ['STRIPE']);
      expect(f.acceptedPaymentMethodsFor(stripeConfigured: false), ['CASH']);
      f.cashEnabled.value = true;
      f.mobileMoneyEnabled.value = true;
      expect(f.acceptedPaymentMethodsFor(stripeConfigured: true), [
        'STRIPE',
        'CASH',
        'MOBILE_MONEY',
      ]);
      f.currency.value = SupportedCurrency.xof; // pas de carte en zone CFA
      expect(f.acceptedPaymentMethodsFor(stripeConfigured: true), [
        'CASH',
        'MOBILE_MONEY',
      ]);
      f.dispose();
    },
  );
}
