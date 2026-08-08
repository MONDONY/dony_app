import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';
import '../data/models/package_request.dart';
import '../data/models/parcel_size.dart';
import '../data/models/payment_method.dart';

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
    this.categories = const [],
    this.description,
    this.targetPriceEur,
    this.photoUrl,
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.negotiable = true,
    this.acceptedPaymentMethods = const {PaymentMethod.stripe},
    this.totalBudgetEur,
    this.promoCode,
    this.submissionStatus = FormSubmissionStatus.idle,
    this.errorMessage,
    this.draftLimitMessage,
    this.createdRequest,
    this.editingRequestId,
  });

  final int currentStep;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? desiredDate;
  final int? dateToleranceDays;
  final TransportMode? transportMode;
  final double? weightKg;
  final ParcelSize? parcelSize;

  /// Catégories de colis sélectionnées (libellés libres, comme une annonce).
  final List<String> categories;

  final String? description;
  final double? targetPriceEur;
  final String? photoUrl;
  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final bool negotiable;
  final Set<PaymentMethod> acceptedPaymentMethods;
  final double? totalBudgetEur;

  /// Code promo saisi à la publication (brut) — appliqué automatiquement au
  /// paiement, jamais resaisi plus tard (cf. AcceptOfferBottomSheet).
  final String? promoCode;
  final FormSubmissionStatus submissionStatus;
  final String? errorMessage;
  final String? draftLimitMessage;
  final PackageRequest? createdRequest;

  /// Non-null en mode édition : id de la demande modifiée (sinon création).
  final String? editingRequestId;

  bool get isEditing => editingRequestId != null;

  PackageRequestFormState copyWith({
    int? currentStep,
    String? departureCity,
    String? arrivalCity,
    DateTime? desiredDate,
    int? dateToleranceDays,
    TransportMode? transportMode,
    double? weightKg,
    ParcelSize? parcelSize,
    List<String>? categories,
    String? description,
    double? targetPriceEur,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
    bool? negotiable,
    Set<PaymentMethod>? acceptedPaymentMethods,
    double? totalBudgetEur,
    // Le pattern `champ ?? this.champ` ne peut pas ramener un nullable à
    // null (un budget effacé retomberait sur l'ancien) — ce flag porte
    // l'intention explicite d'effacement pour ce seul champ.
    bool clearTotalBudgetEur = false,
    String? promoCode,
    bool clearPromoCode = false,
    FormSubmissionStatus? submissionStatus,
    String? errorMessage,
    String? draftLimitMessage,
    // Même pattern que clearTotalBudgetEur : un message de limite affiché
    // une fois doit pouvoir être effacé, pas seulement remplacé.
    bool clearDraftLimitMessage = false,
    PackageRequest? createdRequest,
    String? editingRequestId,
  }) => PackageRequestFormState(
    currentStep: currentStep ?? this.currentStep,
    departureCity: departureCity ?? this.departureCity,
    arrivalCity: arrivalCity ?? this.arrivalCity,
    desiredDate: desiredDate ?? this.desiredDate,
    dateToleranceDays: dateToleranceDays ?? this.dateToleranceDays,
    transportMode: transportMode ?? this.transportMode,
    weightKg: weightKg ?? this.weightKg,
    parcelSize: parcelSize ?? this.parcelSize,
    categories: categories ?? this.categories,
    description: description ?? this.description,
    targetPriceEur: targetPriceEur ?? this.targetPriceEur,
    photoUrl: photoUrl ?? this.photoUrl,
    pickupNeighborhood: pickupNeighborhood ?? this.pickupNeighborhood,
    deliveryNeighborhood: deliveryNeighborhood ?? this.deliveryNeighborhood,
    negotiable: negotiable ?? this.negotiable,
    acceptedPaymentMethods:
        acceptedPaymentMethods ?? this.acceptedPaymentMethods,
    totalBudgetEur:
        clearTotalBudgetEur ? null : (totalBudgetEur ?? this.totalBudgetEur),
    promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
    submissionStatus: submissionStatus ?? this.submissionStatus,
    errorMessage: errorMessage ?? this.errorMessage,
    draftLimitMessage: clearDraftLimitMessage
        ? null
        : (draftLimitMessage ?? this.draftLimitMessage),
    createdRequest: createdRequest ?? this.createdRequest,
    editingRequestId: editingRequestId ?? this.editingRequestId,
  );

  @override
  List<Object?> get props => [
    currentStep,
    departureCity,
    arrivalCity,
    desiredDate,
    dateToleranceDays,
    transportMode,
    weightKg,
    parcelSize,
    categories,
    description,
    targetPriceEur,
    photoUrl,
    pickupNeighborhood,
    deliveryNeighborhood,
    negotiable,
    acceptedPaymentMethods,
    totalBudgetEur,
    promoCode,
    submissionStatus,
    errorMessage,
    draftLimitMessage,
    createdRequest,
    editingRequestId,
  ];
}
