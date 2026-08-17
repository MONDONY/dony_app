import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:equatable/equatable.dart';

sealed class PackageRequestFormEvent extends Equatable {
  const PackageRequestFormEvent();
  @override
  List<Object?> get props => [];
}

class FormStep1Submitted extends PackageRequestFormEvent {
  const FormStep1Submitted({
    required this.departureCity,
    required this.arrivalCity,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.transportMode,
  });
  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final TransportMode transportMode;

  @override
  List<Object?> get props => [
    departureCity,
    arrivalCity,
    desiredDate,
    dateToleranceDays,
    transportMode,
  ];
}

class FormStep2Submitted extends PackageRequestFormEvent {
  const FormStep2Submitted({
    required this.weightKg,
    required this.parcelSize,
    this.categories = const [],
    this.description,
  });
  final double weightKg;
  final ParcelSize parcelSize;
  final List<String> categories;
  final String? description;

  @override
  List<Object?> get props => [weightKg, parcelSize, categories, description];
}

class FormStep3Submitted extends PackageRequestFormEvent {
  const FormStep3Submitted({
    this.targetPriceEur,
    this.photoKeys,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.saveAsDraft = false,
  });
  final double? targetPriceEur;

  /// Clés S3 des photos colis. null = conserver (édition) ; liste = remplacer.
  final List<String>? photoKeys;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;

  /// true → POST avec saveAsDraft. Ignoré en édition : un brouillon édité
  /// reste un brouillon côté backend, aucun signal à envoyer.
  final bool saveAsDraft;

  @override
  List<Object?> get props => [
    targetPriceEur,
    pickupNeighborhood,
    deliveryNeighborhood,
    saveAsDraft,
  ];
}

class FormStepBack extends PackageRequestFormEvent {
  const FormStepBack();
}

class FormReset extends PackageRequestFormEvent {
  const FormReset();
}

class PackageRequestNegotiableToggled extends PackageRequestFormEvent {
  const PackageRequestNegotiableToggled(this.value);
  final bool value;

  @override
  List<Object?> get props => [value];
}

class PackageRequestPaymentMethodToggled extends PackageRequestFormEvent {
  const PackageRequestPaymentMethodToggled(this.method);
  final PaymentMethod method;

  @override
  List<Object?> get props => [method];
}

class PackageRequestTotalBudgetChanged extends PackageRequestFormEvent {
  const PackageRequestTotalBudgetChanged(this.value);
  final double? value;

  @override
  List<Object?> get props => [value];
}

class PackageRequestPromoCodeChanged extends PackageRequestFormEvent {
  const PackageRequestPromoCodeChanged(this.value);

  /// null ou vide → efface le code (cf. copyWith(clearPromoCode: true)).
  final String? value;

  @override
  List<Object?> get props => [value];
}
