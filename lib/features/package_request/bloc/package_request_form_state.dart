import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';
import '../data/models/content_category.dart';
import '../data/models/package_request.dart';
import '../data/models/parcel_size.dart';
import '../data/models/payment_method.dart';

enum FormSubmissionStatus { idle, submitting, success, error }

/// Sentinel used by [PackageRequestFormState.copyWith] to distinguish
/// "not provided" from an explicitly-passed `null` for [customCategoryLabel].
const Object _keep = Object();

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
    this.customCategoryLabel,
    this.description,
    this.targetPriceEur,
    this.photoUrl,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.negotiable = true,
    this.acceptedPaymentMethods = const {PaymentMethod.stripe},
    this.totalBudgetEur,
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
  final ContentCategory? contentCategory;

  /// Free-text label when the user selects "Autre…" and types a custom value.
  /// Non-null only when [contentCategory] == [ContentCategory.autre] and the
  /// user has typed something.
  final String? customCategoryLabel;

  final String? description;
  final double? targetPriceEur;
  final String? photoUrl;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final bool negotiable;
  final Set<PaymentMethod> acceptedPaymentMethods;
  final double? totalBudgetEur;
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
    ContentCategory? contentCategory,
    // Use a sentinel to allow explicitly clearing customCategoryLabel.
    Object? customCategoryLabel = _keep,
    String? description,
    double? targetPriceEur,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
    bool? negotiable,
    Set<PaymentMethod>? acceptedPaymentMethods,
    double? totalBudgetEur,
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
        customCategoryLabel: customCategoryLabel == _keep
            ? this.customCategoryLabel
            : customCategoryLabel as String?,
        description: description ?? this.description,
        targetPriceEur: targetPriceEur ?? this.targetPriceEur,
        photoUrl: photoUrl ?? this.photoUrl,
        pickupNeighborhood: pickupNeighborhood ?? this.pickupNeighborhood,
        deliveryNeighborhood: deliveryNeighborhood ?? this.deliveryNeighborhood,
        negotiable: negotiable ?? this.negotiable,
        acceptedPaymentMethods:
            acceptedPaymentMethods ?? this.acceptedPaymentMethods,
        totalBudgetEur: totalBudgetEur ?? this.totalBudgetEur,
        submissionStatus: submissionStatus ?? this.submissionStatus,
        errorMessage: errorMessage ?? this.errorMessage,
        createdRequest: createdRequest ?? this.createdRequest,
      );

  @override
  List<Object?> get props => [
        currentStep, departureCity, arrivalCity, desiredDate, dateToleranceDays,
        transportMode, weightKg, parcelSize, contentCategory, customCategoryLabel,
        description, targetPriceEur, photoUrl, pickupNeighborhood,
        deliveryNeighborhood, negotiable, acceptedPaymentMethods, totalBudgetEur,
        submissionStatus, errorMessage, createdRequest,
      ];
}
