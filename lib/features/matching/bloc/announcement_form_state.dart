import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';

enum CapacityUnit { suitcase23kg, suitcase32kg, kgFree, custom }

enum PricingMode { kg, mixed }

enum PriceWarning { tooLow, tooHigh }

/// Unité de vente d'un trajet bateau : le volume (m³, groupage en
/// conteneur) ou le kilo. Un trajet au m³ n'a aucun kilo (ni capacité ni
/// prix au kilo) ; le choix est figé côté serveur dès qu'un colis existe
/// (409 `pricing-unit-locked`).
enum BoatPriceUnit {
  m3,
  kg;

  /// Valeur figée du brouillon local (clé `boatPriceUnit`).
  String get wire => switch (this) {
    BoatPriceUnit.m3 => 'M3',
    BoatPriceUnit.kg => 'KG',
  };

  /// Valeur relue d'un brouillon ; absente ou inconnue : `null`.
  static BoatPriceUnit? fromWire(Object? wire) => switch (wire) {
    'M3' => BoatPriceUnit.m3,
    'KG' => BoatPriceUnit.kg,
    _ => null,
  };
}

/// Plus petit prix au m³ accepté (miroir de `@DecimalMin 0.01` du back) ; pas
/// de borne haute.
const double minPricePerM3 = 0.01;

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

  /// Modification d'un trajet publié : [availableKg] y vaut les kilos
  /// RESTANTS (ils baissent à chaque réservation). Le poids max par colis
  /// n'est alors plus comparé à ce reste (le back n'impose pas cette règle),
  /// seulement au maximum technique.
  final bool isEditingTrip;

  /// Trajet bateau : unité de vente, posée par le formulaire de trajet (le
  /// m³ par défaut, le groupage en conteneur). `null` : formulaire sans
  /// vente au m³ (modèles de trajet, ancien bateau au kilo), tout reste au
  /// kilo. Sans effet hors bateau.
  final BoatPriceUnit? boatPriceUnit;

  /// Trajet bateau au m³ : volume proposé, de 0,1 à 9 999 m³.
  final double? volumeCapacityM3;

  /// Trajet bateau au m³ : prix net par m³ (le voyageur le touche ; les frais
  /// de service s'ajoutent pour l'expéditeur).
  final double? pricePerM3;

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
    this.isEditingTrip = false,
    this.boatPriceUnit,
    this.volumeCapacityM3,
    this.pricePerM3,
  });

  /// Trajet en bateau.
  bool get isBoat => transportMode == TransportMode.boat;

  /// Trajet bateau dont le formulaire choisit l'unité de vente (m³ ou kilo,
  /// sans grille) : le formulaire de trajet du lot 3, jamais un modèle.
  bool get hasBoatPricing => isBoat && boatPriceUnit != null;

  /// Trajet bateau vendu au m³ : aucun kilo ne part au serveur.
  bool get isPricedPerM3 => isBoat && boatPriceUnit == BoatPriceUnit.m3;

  /// Volume proposé dans les bornes (0,1 à 9 999 m³).
  bool get isVolumeValid => TripVolumeLimits.isValid(volumeCapacityM3);

  /// Prix au m³ renseigné, d'au moins 0,01 (pas de borne haute).
  bool get isPricePerM3Valid =>
      pricePerM3 != null && pricePerM3! >= minPricePerM3;

  /// Capacité maximale saisissable pour le mode du trajet (avion par défaut
  /// tant qu'aucun mode n'est choisi).
  int get capacityMaxKg =>
      TripCapacityLimits.maxKgFor(transportModeOrPlane(transportMode));

  /// Capacité au-delà du plafond du mode (ex. 1 200 kg saisis en route puis
  /// passage en avion). Le kilo libre n'a qu'une capacité technique ; un
  /// trajet au m³ n'a pas de kilos.
  bool get capacityTooHigh =>
      !isPricedPerM3 &&
      capacityUnit != CapacityUnit.kgFree &&
      (availableKg ?? 0) > capacityMaxKg;

  /// Poids max par colis : vide, ou entre 0,5 kg et la capacité du trajet
  /// (999 999 kg en kilo libre, dont la capacité est technique, au m³, sans
  /// kilos, et en modification, où [availableKg] n'est que le reste à
  /// réserver).
  bool get isMaxParcelWeightValid {
    final w = maxParcelWeightKg;
    if (w == null) return true;
    final kg = availableKg;
    final upper =
        isPricedPerM3 ||
            capacityUnit == CapacityUnit.kgFree ||
            kg == null ||
            isEditingTrip
        ? TripCapacityLimits.heavyMaxKg.toDouble()
        : kg;
    return w >= minMaxParcelWeightKg &&
        w <= upper &&
        w <= TripCapacityLimits.heavyMaxKg;
  }

  /// « Continuer » de l'étape Capacité, côté capacité (les adresses sont
  /// vérifiées par l'écran) : kilos dans le plafond du mode, ou volume dans
  /// ses bornes au m³. La taille ne bloque jamais (C24).
  bool get isCapacityStepValid =>
      (isPricedPerM3 ? isVolumeValid : !capacityTooHigh) &&
      isMaxParcelWeightValid;

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
    bool? isEditingTrip,
    BoatPriceUnit? boatPriceUnit,
    double? Function()? volumeCapacityM3Getter,
    double? Function()? pricePerM3Getter,
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
      isEditingTrip: isEditingTrip ?? this.isEditingTrip,
      boatPriceUnit: boatPriceUnit ?? this.boatPriceUnit,
      volumeCapacityM3: volumeCapacityM3Getter != null
          ? volumeCapacityM3Getter()
          : volumeCapacityM3,
      pricePerM3: pricePerM3Getter != null ? pricePerM3Getter() : pricePerM3,
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
    isEditingTrip,
    boatPriceUnit,
    volumeCapacityM3,
    pricePerM3,
  ];
}
