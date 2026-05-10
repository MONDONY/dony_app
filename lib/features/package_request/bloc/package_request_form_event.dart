import 'package:equatable/equatable.dart';
import '../data/models/parcel_size.dart';

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
  });
  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final int dateToleranceDays;

  @override
  List<Object?> get props => [departureCity, arrivalCity, desiredDate, dateToleranceDays];
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
  final String contentCategory;
  final String? description;

  @override
  List<Object?> get props => [weightKg, parcelSize, contentCategory, description];
}

class FormStep3Submitted extends PackageRequestFormEvent {
  const FormStep3Submitted({this.targetPriceEur, this.photoUrl, this.pickupNeighborhood, this.deliveryNeighborhood});
  final double? targetPriceEur;
  final String? photoUrl;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;

  @override
  List<Object?> get props => [targetPriceEur, photoUrl, pickupNeighborhood, deliveryNeighborhood];
}

class FormStepBack extends PackageRequestFormEvent {
  const FormStepBack();
}

class FormReset extends PackageRequestFormEvent {
  const FormReset();
}
