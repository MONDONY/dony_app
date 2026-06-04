import 'dart:io';

import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';
import '../data/models/content_category.dart';
import '../data/models/parcel_size.dart';
import '../data/models/payment_method.dart';

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
  List<Object?> get props => [departureCity, arrivalCity, desiredDate, dateToleranceDays, transportMode];
}

class FormStep2Submitted extends PackageRequestFormEvent {
  const FormStep2Submitted({
    required this.weightKg,
    required this.parcelSize,
    required this.contentCategory,
    this.description,
  });
  final double weightKg;
  final ParcelSize parcelSize;
  final ContentCategory contentCategory;
  final String? description;

  @override
  List<Object?> get props => [weightKg, parcelSize, contentCategory, description];
}

class FormStep3Submitted extends PackageRequestFormEvent {
  const FormStep3Submitted({
    this.targetPriceEur,
    this.photoFile,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
  });
  final double? targetPriceEur;
  final File? photoFile;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;

  @override
  List<Object?> get props => [targetPriceEur, pickupNeighborhood, deliveryNeighborhood];
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
