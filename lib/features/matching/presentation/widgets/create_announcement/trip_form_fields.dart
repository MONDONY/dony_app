import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter/material.dart';

/// Notifiers et contrôleurs du formulaire de trajet, tels que
/// `LieuxCapaciteStep` et `PrixConditionsStep` les consomment.
///
/// Les valeurs initiales sont celles du formulaire de création vierge
/// (`_TripFormContentState`, create_trip_screen.dart) : un modèle de trajet
/// appliqué sur un formulaire, ou saisi dans l'écran modèle, part du même
/// état. Le propriétaire appelle [dispose].
class TripFormFields {
  TripFormFields({SupportedCurrency initialCurrency = SupportedCurrency.eur})
    : currency = ValueNotifier<SupportedCurrency>(initialCurrency);

  final ValueNotifier<SupportedCurrency> currency;
  final departureCity = ValueNotifier<String?>(null);
  final arrivalCity = ValueNotifier<String?>(null);
  final departureCountryCode = ValueNotifier<String?>(null);
  final arrivalCountryCode = ValueNotifier<String?>(null);
  final departureTime = ValueNotifier<TimeOfDay?>(null);
  final arrivalTime = ValueNotifier<TimeOfDay?>(null);
  final transportMode = ValueNotifier<TransportMode?>(null);
  final pickupAddress = ValueNotifier<AddressData?>(null);
  final deliveryAddress = ValueNotifier<AddressData?>(null);
  final availableKg = ValueNotifier<double>(15);

  /// Index de chip ; -1 = aucune sélection ; `presets.length` = « Autre prix ».
  final priceOption = ValueNotifier<int>(-1);
  final customPrice = ValueNotifier<double>(6.0);
  final kgPriceEnabled = ValueNotifier<bool>(true);
  final cashEnabled = ValueNotifier<bool>(false);
  final mobileMoneyEnabled = ValueNotifier<bool>(false);
  final negotiable = ValueNotifier<bool>(false);
  final selectedContent = ValueNotifier<Set<String>>({
    'Vêtements & tissus',
    'Médicaments traditionnels',
    'Documents & administratif',
  });
  final customAccepted = ValueNotifier<Set<String>>({});
  final refusedTypes = ValueNotifier<Set<String>>({});
  final catalogLabels = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final descriptionCtrl = TextEditingController();
  final customAcceptedCtrl = TextEditingController();
  final refusedCtrl = TextEditingController();
  final customPriceCtrl = TextEditingController();

  List<double> get presets =>
      KgPriceReference.forCurrency(currency.value).presets;

  bool get isCustomPrice => priceOption.value == presets.length;

  /// Net voyageur au kilo, ou nul si non renseigné ou si le prix au kilo est
  /// désactivé (mode grille seule).
  double? get pricePerKg {
    if (!kgPriceEnabled.value || priceOption.value < 0) return null;
    if (isCustomPrice) return customPrice.value;
    return presets[priceOption.value.clamp(0, presets.length - 1)];
  }

  /// Sélectionne la chip qui vaut exactement [price], sinon « Autre prix »
  /// avec le champ prérempli. `null` efface la sélection.
  void selectPrice(double? price) {
    if (price == null) {
      priceOption.value = -1;
      return;
    }
    final idx = presets.indexOf(price);
    if (idx != -1) {
      priceOption.value = idx;
      return;
    }
    customPrice.value = price;
    customPriceCtrl.text = formatKgPrice(price);
    priceOption.value = presets.length;
  }

  /// Moyens de paiement à envoyer, même règle que la soumission du formulaire
  /// de création : la carte seulement si Stripe est configuré et la devise
  /// l'autorise, l'espèce forcée sinon (jamais vide), mobile money sur choix.
  List<String> acceptedPaymentMethodsFor({required bool stripeConfigured}) {
    final stripe = stripeConfigured && currency.value.isStripeEligible;
    return [
      if (stripe) 'STRIPE',
      if (cashEnabled.value || !stripe) 'CASH',
      if (mobileMoneyEnabled.value) 'MOBILE_MONEY',
    ];
  }

  void dispose() {
    currency.dispose();
    departureCity.dispose();
    arrivalCity.dispose();
    departureCountryCode.dispose();
    arrivalCountryCode.dispose();
    departureTime.dispose();
    arrivalTime.dispose();
    transportMode.dispose();
    pickupAddress.dispose();
    deliveryAddress.dispose();
    availableKg.dispose();
    priceOption.dispose();
    customPrice.dispose();
    kgPriceEnabled.dispose();
    cashEnabled.dispose();
    mobileMoneyEnabled.dispose();
    negotiable.dispose();
    selectedContent.dispose();
    customAccepted.dispose();
    refusedTypes.dispose();
    catalogLabels.dispose();
    descriptionCtrl.dispose();
    customAcceptedCtrl.dispose();
    refusedCtrl.dispose();
    customPriceCtrl.dispose();
  }
}
