import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/models/package_request.dart';
import '../data/models/payment_method.dart';
import '../data/models/price_display.dart';
import '../data/package_request_repository.dart';
import 'package_request_form_event.dart';
import 'package_request_form_state.dart';

class PackageRequestFormBloc
    extends Bloc<PackageRequestFormEvent, PackageRequestFormState> {
  /// [editing] non-null → mode édition : l'état initial est pré-rempli depuis la
  /// demande existante (de façon synchrone, pour que les steps puissent lire ces
  /// valeurs dans leur `initState`). La soumission de l'étape 3 appellera alors
  /// `update` au lieu de `create`.
  PackageRequestFormBloc(
    this._repository, {
    required AnalyticsService analytics,
    PackageRequest? editing,
  }) : _analytics = analytics,
       super(
         editing != null
             ? _prefilledFrom(editing)
             : const PackageRequestFormState(),
       ) {
    on<FormStep1Submitted>(_onStep1);
    on<FormStep2Submitted>(_onStep2);
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
      categories: r.categories,
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

  /// Une chaîne vide signifie « champ laissé à blanc » côté formulaire ; le
  /// backend, lui, attend `null` pour l'absence de valeur.
  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  void _onStep1(FormStep1Submitted e, Emitter<PackageRequestFormState> emit) {
    emit(
      state.copyWith(
        currentStep: 1,
        departureCity: e.departureCity,
        arrivalCity: e.arrivalCity,
        desiredDate: e.desiredDate,
        dateToleranceDays: e.dateToleranceDays,
        transportMode: e.transportMode,
        pickupNeighborhood: e.pickupNeighborhood,
      ),
    );
  }

  void _onStep2(FormStep2Submitted e, Emitter<PackageRequestFormState> emit) {
    emit(
      state.copyWith(
        currentStep: 2,
        weightKg: e.weightKg,
        parcelSize: e.parcelSize,
        categories: e.categories,
        description: e.description,
      ),
    );
  }

  Future<void> _onStep3(
    FormStep3Submitted e,
    Emitter<PackageRequestFormState> emit,
  ) async {
    emit(
      state.copyWith(
        submissionStatus: FormSubmissionStatus.submitting,
        targetPriceEur: e.targetPriceEur,
        pickupNeighborhood: e.pickupNeighborhood,
        deliveryNeighborhood: e.deliveryNeighborhood,
      ),
    );
    try {
      final editingId = state.editingRequestId;
      final PackageRequest saved;
      if (editingId != null) {
        saved = await _repository.update(
          editingId,
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate!,
          dateToleranceDays: state.dateToleranceDays!,
          weightKg: state.weightKg!,
          categories: state.categories,
          parcelSize: state.parcelSize!,
          transportMode: state.transportMode!,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: state.totalBudgetEur ?? e.targetPriceEur,
          description: state.description,
          // null → conserver les photos existantes ; liste → remplacer l'ensemble.
          photoKeys: e.photoKeys,
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
        );
      } else {
        saved = await _repository.create(
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate!,
          dateToleranceDays: state.dateToleranceDays!,
          weightKg: state.weightKg!,
          categories: state.categories,
          parcelSize: state.parcelSize!,
          transportMode: state.transportMode!,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: state.totalBudgetEur ?? e.targetPriceEur,
          description: state.description,
          photoKeys: e.photoKeys,
          // Lu depuis l'etat, pas depuis l'event : le lieu de remise est saisi
          // a l'etape 1, or FormStep3Submitted ne le porte jamais. Le chemin
          // creation lisait l'event et perdait donc la valeur, contrairement
          // au chemin edition juste au-dessus.
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
        );
      }
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.success,
          createdRequest: saved,
        ),
      );
      unawaited(
        _analytics.logEvent(
          editingId != null
              ? AnalyticsEvents.packageRequestUpdated
              : AnalyticsEvents.packageRequestCreated,
          properties: {
            'corridor': '${state.departureCity}→${state.arrivalCity}',
            'negotiable': state.negotiable,
            'payment_methods': state.acceptedPaymentMethods
                .map((m) => m.wireName)
                .toList(),
          },
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.error,
          errorMessage: err.toString(),
        ),
      );
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
