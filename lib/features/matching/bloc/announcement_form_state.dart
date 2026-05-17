import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';

enum CapacityUnit { suitcase23kg, suitcase32kg, kgFree }

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
    }
  }

  String get label {
    switch (this) {
      case CapacityUnit.suitcase23kg:
        return '1 valise 23 kg';
      case CapacityUnit.suitcase32kg:
        return '1 valise 32 kg';
      case CapacityUnit.kgFree:
        return 'Kg libre';
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
    }
  }
}

class AnnouncementFormState extends Equatable {
  final String? departureCity;
  final String? arrivalCity;
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
  final List<String> acceptedTypes;
  final List<String> rejectedTypes;

  const AnnouncementFormState({
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.pricePerKg,
    this.availableKg,
    this.capacityUnit = CapacityUnit.suitcase23kg,
    this.description,
    this.priceWarning,
    this.isSubmitting = false,
    this.transportMode,
    this.pickupAddress,
    this.deliveryAddress,
    this.cashAccepted = false,
    this.acceptedTypes = const [],
    this.rejectedTypes = const [],
  });

  bool get isFormValid =>
      departureCity != null &&
      departureCity!.isNotEmpty &&
      arrivalCity != null &&
      arrivalCity!.isNotEmpty &&
      departureDate != null &&
      departureDate!
          .isAfter(DateTime.now().subtract(const Duration(days: 1))) &&
      pricePerKg != null &&
      pricePerKg! > 0 &&
      availableKg != null &&
      availableKg! >= 1;

  bool get isStep1Valid =>
      departureCity != null &&
      departureCity!.isNotEmpty &&
      arrivalCity != null &&
      arrivalCity!.isNotEmpty &&
      departureDate != null;

  bool get isStep2Valid =>
      pickupAddress != null && deliveryAddress != null;

  bool get isStep3Valid => pricePerKg != null && pricePerKg! > 0;

  AnnouncementFormState copyWith({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDate,
    double? pricePerKg,
    double? availableKg,
    CapacityUnit? capacityUnit,
    String? description,
    PriceWarning? Function()? priceWarningGetter,
    bool? isSubmitting,
    TransportMode? Function()? transportModeGetter,
    AddressData? Function()? pickupAddressGetter,
    AddressData? Function()? deliveryAddressGetter,
    bool? cashAccepted,
    List<String>? acceptedTypes,
    List<String>? rejectedTypes,
  }) {
    return AnnouncementFormState(
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureDate: departureDate ?? this.departureDate,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      availableKg: availableKg ?? this.availableKg,
      capacityUnit: capacityUnit ?? this.capacityUnit,
      description: description ?? this.description,
      priceWarning:
          priceWarningGetter != null ? priceWarningGetter() : this.priceWarning,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      transportMode:
          transportModeGetter != null ? transportModeGetter() : this.transportMode,
      pickupAddress:
          pickupAddressGetter != null ? pickupAddressGetter() : this.pickupAddress,
      deliveryAddress:
          deliveryAddressGetter != null ? deliveryAddressGetter() : this.deliveryAddress,
      cashAccepted: cashAccepted ?? this.cashAccepted,
      acceptedTypes: acceptedTypes ?? this.acceptedTypes,
      rejectedTypes: rejectedTypes ?? this.rejectedTypes,
    );
  }

  @override
  List<Object?> get props => [
        departureCity,
        arrivalCity,
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
        acceptedTypes,
        rejectedTypes,
      ];
}
