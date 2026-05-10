import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';
import '../data/models/package_request.dart';
import '../data/models/parcel_size.dart';

enum FormSubmissionStatus { idle, submitting, success, error }

class PackageRequestFormState extends Equatable {
  const PackageRequestFormState({
    this.currentStep = 0,
    this.departureCity,
    this.arrivalCity,
    this.desiredDate,
    this.dateToleranceDays,
    this.transportMode,
    this.weightKg,
    this.parcelSize,
    this.contentCategory,
    this.description,
    this.targetPriceEur,
    this.photoUrl,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.submissionStatus = FormSubmissionStatus.idle,
    this.errorMessage,
    this.createdRequest,
  });

  final int currentStep;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? desiredDate;
  final int? dateToleranceDays;
  final TransportMode? transportMode;
  final double? weightKg;
  final ParcelSize? parcelSize;
  final String? contentCategory;
  final String? description;
  final double? targetPriceEur;
  final String? photoUrl;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final FormSubmissionStatus submissionStatus;
  final String? errorMessage;
  final PackageRequest? createdRequest;

  PackageRequestFormState copyWith({
    int? currentStep,
    String? departureCity,
    String? arrivalCity,
    DateTime? desiredDate,
    int? dateToleranceDays,
    TransportMode? transportMode,
    double? weightKg,
    ParcelSize? parcelSize,
    String? contentCategory,
    String? description,
    double? targetPriceEur,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
    FormSubmissionStatus? submissionStatus,
    String? errorMessage,
    PackageRequest? createdRequest,
  }) =>
      PackageRequestFormState(
        currentStep: currentStep ?? this.currentStep,
        departureCity: departureCity ?? this.departureCity,
        arrivalCity: arrivalCity ?? this.arrivalCity,
        desiredDate: desiredDate ?? this.desiredDate,
        dateToleranceDays: dateToleranceDays ?? this.dateToleranceDays,
        transportMode: transportMode ?? this.transportMode,
        weightKg: weightKg ?? this.weightKg,
        parcelSize: parcelSize ?? this.parcelSize,
        contentCategory: contentCategory ?? this.contentCategory,
        description: description ?? this.description,
        targetPriceEur: targetPriceEur ?? this.targetPriceEur,
        photoUrl: photoUrl ?? this.photoUrl,
        pickupNeighborhood: pickupNeighborhood ?? this.pickupNeighborhood,
        deliveryNeighborhood: deliveryNeighborhood ?? this.deliveryNeighborhood,
        submissionStatus: submissionStatus ?? this.submissionStatus,
        errorMessage: errorMessage ?? this.errorMessage,
        createdRequest: createdRequest ?? this.createdRequest,
      );

  @override
  List<Object?> get props => [
        currentStep, departureCity, arrivalCity, desiredDate, dateToleranceDays,
        transportMode, weightKg, parcelSize, contentCategory, description,
        targetPriceEur, photoUrl, pickupNeighborhood, deliveryNeighborhood,
        submissionStatus, errorMessage, createdRequest,
      ];
}
