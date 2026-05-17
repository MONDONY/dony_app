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
      ];
}
