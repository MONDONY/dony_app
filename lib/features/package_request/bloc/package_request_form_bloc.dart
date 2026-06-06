import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/models/content_category.dart';
import '../data/models/package_request.dart';
import '../data/models/payment_method.dart';
import '../data/models/price_display.dart';
import '../data/package_request_repository.dart';
import 'package_request_form_event.dart';
import 'package_request_form_state.dart';

class PackageRequestFormBloc extends Bloc<PackageRequestFormEvent, PackageRequestFormState> {
  /// [editing] non-null → mode édition : l'état initial est pré-rempli depuis la
  /// demande existante (de façon synchrone, pour que les steps puissent lire ces
  /// valeurs dans leur `initState`). La soumission de l'étape 3 appellera alors
  /// `update` au lieu de `create`.
  PackageRequestFormBloc(
    this._repository, {
    required AnalyticsService analytics,
    PackageRequest? editing,
  })  : _analytics = analytics,
        super(editing != null
            ? _prefilledFrom(editing)
            : const PackageRequestFormState()) {
    on<FormStep1Submitted>(_onStep1);
    on<FormStep2Submitted>(_onStep2);
    on<FormStep2CategoryChanged>(_onStep2CategoryChanged);
    on<FormStep3Submitted>(_onStep3);
    on<FormStepBack>(_onStepBack);
    on<FormReset>((_, emit) => emit(const PackageRequestFormState()));
    on<PackageRequestNegotiableToggled>(
      (e, emit) => emit(state.copyWith(negotiable: e.value)),
    );
    on<PackageRequestPaymentMethodToggled>(_onPaymentMethodToggled);
    on<PackageRequestTotalBudgetChanged>(
      (e, emit) => emit(state.copyWith(totalBudgetEur: e.value)),
    );
  }

  final PackageRequestRepository _repository;
  final AnalyticsService _analytics;

  /// Construit l'état initial pré-rempli pour l'édition. Le budget est reconverti
  /// net → brut (l'utilisateur saisit/voit le brut, le backend stocke le net).
  static PackageRequestFormState _prefilledFrom(PackageRequest r) {
    final gross = r.targetPriceEur != null
        ? PriceDisplay.grossFromNet(r.targetPriceEur!)
        : null;
    return PackageRequestFormState(
      editingRequestId: r.id,
      departureCity: r.departureCity,
      arrivalCity: r.arrivalCity,
      desiredDate: r.desiredDate,
      dateToleranceDays: r.dateToleranceDays,
      transportMode: r.transportMode,
      weightKg: r.weightKg,
      parcelSize: r.parcelSize,
      contentCategory: r.contentCategory,
      description: r.description,
      photoUrl: r.photoUrl,
      pickupNeighborhood: r.pickupNeighborhood,
      deliveryNeighborhood: r.deliveryNeighborhood,
      negotiable: r.negotiable,
      acceptedPaymentMethods: r.acceptedPaymentMethods.isEmpty
          ? const {PaymentMethod.stripe}
          : r.acceptedPaymentMethods,
      totalBudgetEur: gross,
      targetPriceEur: gross,
    );
  }

  void _onStep1(FormStep1Submitted e, Emitter<PackageRequestFormState> emit) {
    emit(state.copyWith(
      currentStep: 1,
      departureCity: e.departureCity,
      arrivalCity: e.arrivalCity,
      desiredDate: e.desiredDate,
      dateToleranceDays: e.dateToleranceDays,
      transportMode: e.transportMode,
    ));
  }

  void _onStep2(FormStep2Submitted e, Emitter<PackageRequestFormState> emit) {
    emit(state.copyWith(
      currentStep: 2,
      weightKg: e.weightKg,
      parcelSize: e.parcelSize,
      contentCategory: e.contentCategory,
      description: e.description,
    ));
  }

  void _onStep2CategoryChanged(
    FormStep2CategoryChanged e,
    Emitter<PackageRequestFormState> emit,
  ) {
    final label = e.label;
    if (label == null || label.isEmpty) {
      // User cleared the custom field; keep ContentCategory.autre but clear label.
      emit(state.copyWith(
        contentCategory: ContentCategory.autre,
        customCategoryLabel: null,
      ));
    } else {
      emit(state.copyWith(
        contentCategory: ContentCategory.autre,
        customCategoryLabel: label,
      ));
    }
  }

  Future<void> _onStep3(FormStep3Submitted e, Emitter<PackageRequestFormState> emit) async {
    emit(state.copyWith(submissionStatus: FormSubmissionStatus.submitting));

    String? photoUrl;
    if (e.photoFile != null) {
      try {
        photoUrl = await _repository.uploadPhoto(e.photoFile!);
      } catch (_) {
        // Upload non-bloquant : on publie sans photo plutôt que d'échouer
      }
    }

    emit(state.copyWith(
      targetPriceEur: e.targetPriceEur,
      photoUrl: photoUrl,
      pickupNeighborhood: e.pickupNeighborhood,
      deliveryNeighborhood: e.deliveryNeighborhood,
    ));
    try {
      final editingId = state.editingRequestId;
      // En édition, conserver la photo existante si l'utilisateur n'en a pas
      // re-uploadé une (photoUrl local null → garder state.photoUrl).
      final resolvedPhotoUrl = photoUrl ?? (editingId != null ? state.photoUrl : null);
      final PackageRequest saved;
      if (editingId != null) {
        saved = await _repository.update(
          editingId,
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate!,
          dateToleranceDays: state.dateToleranceDays!,
          weightKg: state.weightKg!,
          contentCategory: state.contentCategory!,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: state.totalBudgetEur ?? e.targetPriceEur,
          description: state.description,
          photoUrl: resolvedPhotoUrl,
          // state.* conserve les quartiers pré-remplis (l'event step 3 ne les
          // transmet pas → ne pas les écraser à null en édition).
          pickupNeighborhood: state.pickupNeighborhood,
          deliveryNeighborhood: state.deliveryNeighborhood,
        );
      } else {
        saved = await _repository.create(
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate!,
          dateToleranceDays: state.dateToleranceDays!,
          weightKg: state.weightKg!,
          contentCategory: state.contentCategory!,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: state.totalBudgetEur ?? e.targetPriceEur,
          description: state.description,
          photoUrl: photoUrl,
          pickupNeighborhood: e.pickupNeighborhood,
          deliveryNeighborhood: e.deliveryNeighborhood,
        );
      }
      emit(state.copyWith(
        submissionStatus: FormSubmissionStatus.success,
        createdRequest: saved,
      ));
      unawaited(_analytics.logEvent(
        editingId != null
            ? AnalyticsEvents.packageRequestUpdated
            : AnalyticsEvents.packageRequestCreated,
        properties: {
          'corridor': '${state.departureCity}→${state.arrivalCity}',
          'negotiable': state.negotiable,
          'payment_methods':
              state.acceptedPaymentMethods.map((m) => m.wireName).toList(),
        },
      ));
    } catch (err) {
      emit(state.copyWith(
        submissionStatus: FormSubmissionStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }

  void _onStepBack(FormStepBack e, Emitter<PackageRequestFormState> emit) {
    if (state.currentStep > 0) {
      emit(state.copyWith(currentStep: state.currentStep - 1));
    }
  }

  void _onPaymentMethodToggled(
    PackageRequestPaymentMethodToggled e,
    Emitter<PackageRequestFormState> emit,
  ) {
    final next = {...state.acceptedPaymentMethods};
    if (next.contains(e.method)) {
      next.remove(e.method);
    } else {
      next.add(e.method);
    }
    // Guarantee at least one payment method is always selected.
    if (next.isEmpty) next.add(PaymentMethod.stripe);
    emit(state.copyWith(acceptedPaymentMethods: next));
  }
}
