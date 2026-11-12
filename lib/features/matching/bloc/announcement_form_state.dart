import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';

enum CapacityUnit { suitcase23kg, suitcase32kg, kgFree, custom }

enum PricingMode { kg, mixed }

enum PriceWarning { tooLow, tooHigh }

extension CapacityUnitWire on CapacityUnit {
  String toWire() {
    switch (this) {
      case CapacityUnit.suitcase23kg:
        return 'SUITCASE_23KG';
      case CapacityUnit.suitcase32kg:
        return 'SUITCASE_32KG';
      case CapacityUnit.kgFree:
        return 'KG_FREE';
      case CapacityUnit.custom:
        return 'KG_EXACT';
    }
  }

  double? get maxKg {
    switch (this) {
      case CapacityUnit.suitcase23kg:
        return 23.0;
      case CapacityUnit.suitcase32kg:
        return 32.0;
      case CapacityUnit.kgFree:
        return null;
      case CapacityUnit.custom:
        return null;
    }
  }

  /// Ramène [kg] à un nombre entier de valises (au moins une) pour les
  /// unités valise, laisse les autres unités telles quelles.
  ///
  /// Le compteur de valises affiche déjà `round(kg / maxKg)` valises : un
  /// trajet ne doit jamais partir avec un poids que l'écran ne montrait pas
  /// (YADONY-FLUTTER-PROD-18, valise de 23 kg envoyée à 15 kg).
  double normalizeKg(double kg) {
    final unitKg = maxKg;
    if (unitKg == null) return kg;
    final count = (kg / unitKg).round().clamp(1, 999999);
    return count * unitKg;
  }
}

/// Unité de capacité d'un formulaire de trajet vierge.
const CapacityUnit defaultCapacityUnit = CapacityUnit.suitcase23kg;

/// Kg disponibles d'un formulaire de trajet vierge : une valise de
/// [defaultCapacityUnit]. Les notifiers de kg des écrans partent de cette
/// valeur, la même que celle affichée par le compteur de valises : un écart
/// entre les deux faisait publier 15 kg pour une valise de 23 kg
/// (YADONY-FLUTTER-PROD-18).
const double defaultAvailableKg = 23.0;

/// Plus petit poids max par colis accepté, en kilos : le poids minimum d'une
/// demande (D19).
const double minMaxParcelWeightKg = 0.5;

class AnnouncementFormState extends Equatable {
  final String? departureCity;
  final String? arrivalCity;

  /// Code pays ISO-2 (ex: "US") du départ / arrivée, capturé depuis le
  /// `CityModel.countryCode` lors de la sélection ville. Envoyé au backend.
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime? departureDate;
  final double? pricePerKg;
  final double? availableKg;
  final CapacityUnit capacityUnit;
  final String? description;
  final PriceWarning? priceWarning;
  final bool isSubmitting;

  // Nouveaux champs pour l'aperçu
  final TransportMode? transportMode;
  final AddressData? pickupAddress;
  final AddressData? deliveryAddress;
  final bool cashAccepted;

  /// Le voyageur accepte le paiement par mobile money (Orange Money, Wave,
  /// MTN via pawaPay) sur ce trajet. Uniquement pertinent pour un trajet en
  /// zone CFA (XOF/XAF) — la validité de la devise se vérifie côté écran,
  /// pas ici.
  final bool mobileMoneyAccepted;

  /// Le voyageur accepte les propositions de prix des expéditeurs sur ce
  /// trajet. `false` par défaut : un trajet reste à prix ferme tant que le
  /// voyageur ne l'ouvre pas explicitement.
  final bool negotiable;
  final List<String> acceptedTypes;
  final List<String> rejectedTypes;

  // Mode de tarification + aperçu grille
  final PricingMode pricingMode;
  final List<GridPreviewItem> gridPreviewItems;

  /// Taille max d'un colis, route seulement, facultative.
  final ItemSize? maxItemSize;

  /// Poids max par colis en kilos, route seulement, facultatif.
  final double? maxParcelWeightKg;

  const AnnouncementFormState({
    this.departureCity,
    this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    this.departureDate,
    this.pricePerKg,
    this.availableKg,
    this.capacityUnit = defaultCapacityUnit,
    this.description,
    this.priceWarning,
    this.isSubmitting = false,
    this.transportMode,
    this.pickupAddress,
    this.deliveryAddress,
    this.cashAccepted = false,
    this.mobileMoneyAccepted = false,
    this.negotiable = false,
    this.acceptedTypes = const [],
    this.rejectedTypes = const [],
    this.pricingMode = PricingMode.kg,
    this.gridPreviewItems = const [],
    this.maxItemSize,
    this.maxParcelWeightKg,
  });

  /// Capacité maximale saisissable pour le mode du trajet (avion par défaut
  /// tant qu'aucun mode n'est choisi).
  int get capacityMaxKg =>
      TripCapacityLimits.maxKgFor(transportModeOrPlane(transportMode));

  /// Capacité au-delà du plafond du mode (ex. 1 200 kg saisis en route puis
  /// passage en avion). Le kilo libre n'a qu'une capacité technique.
  bool get capacityTooHigh =>
      capacityUnit != CapacityUnit.kgFree && (availableKg ?? 0) > capacityMaxKg;

  /// Poids max par colis : vide, ou entre 0,5 kg et la capacité du trajet
  /// (999 999 kg en kilo libre, dont la capacité est technique).
  bool get isMaxParcelWeightValid {
    final w = maxParcelWeightKg;
    if (w == null) return true;
    final kg = availableKg;
    final upper = capacityUnit == CapacityUnit.kgFree || kg == null
        ? TripCapacityLimits.heavyMaxKg.toDouble()
        : kg;
    return w >= minMaxParcelWeightKg &&
        w <= upper &&
        w <= TripCapacityLimits.heavyMaxKg;
  }

  /// « Continuer » de l'étape Capacité, côté kilos (les adresses sont
  /// vérifiées par l'écran). La taille ne bloque jamais (C24).
  bool get isCapacityStepValid => !capacityTooHigh && isMaxParcelWeightValid;

  bool get isFormValid =>
      departureCity != null &&
      departureCity!.isNotEmpty &&
      arrivalCity != null &&
      arrivalCity!.isNotEmpty &&
      departureDate != null &&
      departureDate!.isAfter(
        DateTime.now().subtract(const Duration(days: 1)),
      ) &&
      availableKg != null &&
      availableKg! >= 1 &&
      isStep3Valid;

  bool get isStep1Valid =>
      departureCity != null &&
      departureCity!.isNotEmpty &&
      arrivalCity != null &&
      arrivalCity!.isNotEmpty &&
      departureDate != null;

  bool get isStep2Valid => pickupAddress != null && deliveryAddress != null;

  bool get isStep3Valid {
    switch (pricingMode) {
      case PricingMode.kg:
        return pricePerKg != null && pricePerKg! > 0;
      case PricingMode.mixed:
        return (pricePerKg != null && pricePerKg! > 0) ||
            gridPreviewItems.isNotEmpty;
    }
  }

  AnnouncementFormState copyWith({
    String? departureCity,
    String? arrivalCity,
    String? departureCountryCode,
    String? arrivalCountryCode,
    String? Function()? departureCountryCodeGetter,
    String? Function()? arrivalCountryCodeGetter,
    DateTime? departureDate,
    double? pricePerKg,
    double? Function()? pricePerKgGetter,
    double? Function()? availableKgGetter,
    CapacityUnit? capacityUnit,
    String? description,
    PriceWarning? Function()? priceWarningGetter,
    bool? isSubmitting,
    TransportMode? Function()? transportModeGetter,
    AddressData? Function()? pickupAddressGetter,
    AddressData? Function()? deliveryAddressGetter,
    bool? cashAccepted,
    bool? mobileMoneyAccepted,
    bool? negotiable,
    List<String>? acceptedTypes,
    List<String>? rejectedTypes,
    PricingMode? pricingMode,
    List<GridPreviewItem>? gridPreviewItems,
    ItemSize? Function()? maxItemSizeGetter,
    double? Function()? maxParcelWeightKgGetter,
  }) {
    return AnnouncementFormState(
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureCountryCode: departureCountryCodeGetter != null
          ? departureCountryCodeGetter()
          : (departureCountryCode ?? this.departureCountryCode),
      arrivalCountryCode: arrivalCountryCodeGetter != null
          ? arrivalCountryCodeGetter()
          : (arrivalCountryCode ?? this.arrivalCountryCode),
      departureDate: departureDate ?? this.departureDate,
      pricePerKg: pricePerKgGetter != null
          ? pricePerKgGetter()
          : (pricePerKg ?? this.pricePerKg),
      availableKg: availableKgGetter != null
          ? availableKgGetter()
          : availableKg,
      capacityUnit: capacityUnit ?? this.capacityUnit,
      description: description ?? this.description,
      priceWarning: priceWarningGetter != null
          ? priceWarningGetter()
          : priceWarning,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      transportMode: transportModeGetter != null
          ? transportModeGetter()
          : transportMode,
      pickupAddress: pickupAddressGetter != null
          ? pickupAddressGetter()
          : pickupAddress,
      deliveryAddress: deliveryAddressGetter != null
          ? deliveryAddressGetter()
          : deliveryAddress,
      cashAccepted: cashAccepted ?? this.cashAccepted,
      mobileMoneyAccepted: mobileMoneyAccepted ?? this.mobileMoneyAccepted,
      negotiable: negotiable ?? this.negotiable,
      acceptedTypes: acceptedTypes ?? this.acceptedTypes,
      rejectedTypes: rejectedTypes ?? this.rejectedTypes,
      pricingMode: pricingMode ?? this.pricingMode,
      gridPreviewItems: gridPreviewItems ?? this.gridPreviewItems,
      maxItemSize: maxItemSizeGetter != null
          ? maxItemSizeGetter()
          : maxItemSize,
      maxParcelWeightKg: maxParcelWeightKgGetter != null
          ? maxParcelWeightKgGetter()
          : maxParcelWeightKg,
    );
  }

  @override
  List<Object?> get props => [
    departureCity,
    arrivalCity,
    departureCountryCode,
    arrivalCountryCode,
    departureDate,
    pricePerKg,
    availableKg,
    capacityUnit,
    description,
    priceWarning,
    isSubmitting,
    transportMode,
    pickupAddress,
    deliveryAddress,
    cashAccepted,
    mobileMoneyAccepted,
    negotiable,
    acceptedTypes,
    rejectedTypes,
    pricingMode,
    gridPreviewItems,
    maxItemSize,
    maxParcelWeightKg,
  ];
}
