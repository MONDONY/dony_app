import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      (e, emit) => emit(
        state.copyWith(
          totalBudgetEur: e.value,
          clearTotalBudgetEur: e.value == null,
        ),
      ),
    );
    on<PackageRequestPromoCodeChanged>(
      (e, emit) => emit(
        state.copyWith(
          promoCode: e.value,
          clearPromoCode: e.value == null || e.value!.isEmpty,
        ),
      ),
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
      promoCode: r.promoCode,
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
    final totalBudgetEur = state.totalBudgetEur ?? e.targetPriceEur;
    if (totalBudgetEur == null) {
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.error,
          errorMessage: 'Indiquez un budget pour continuer',
          clearDraftLimitMessage: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: FormSubmissionStatus.submitting,
        targetPriceEur: totalBudgetEur,
        // Chaque nouvelle tentative repart d'un message de limite propre :
        // sinon un draftLimitMessage périmé d'une tentative précédente peut
        // survivre à côté d'un nouvel errorMessage générique posé par le
        // catch ci-dessous.
        clearDraftLimitMessage: true,
      ),
    );
    try {
      final editingId = state.editingRequestId;
      PackageRequest saved;
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
          totalBudgetEur: totalBudgetEur,
          description: state.description,
          // null → conserver les photos existantes ; liste → remplacer l'ensemble.
          photoKeys: e.photoKeys,
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
          promoCode: _blankToNull(state.promoCode),
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
          totalBudgetEur: totalBudgetEur,
          description: state.description,
          photoKeys: e.photoKeys,
          // Le lieu de remise n'est plus saisi à la publication ; il ne
          // subsiste que sur les demandes déjà créées, et l'édition doit le
          // conserver au lieu de l'écraser.
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
          saveAsDraft: e.saveAsDraft,
          promoCode: _blankToNull(state.promoCode),
        );
      }
      if (!e.saveAsDraft && saved.status == PackageRequestStatus.draft) {
        saved = await _repository.publish(saved.id);
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
      final error = unwrapDioError(err);
      if (error is ForbiddenException && error.code == 'draft-limit-reached') {
        emit(
          state.copyWith(
            submissionStatus: FormSubmissionStatus.error,
            draftLimitMessage: error.message,
          ),
        );
      } else {
        emit(
          state.copyWith(
            submissionStatus: FormSubmissionStatus.error,
            errorMessage: error.message,
          ),
        );
      }
    }
  }

  void _onStepBack(FormStepBack e, Emitter<PackageRequestFormState> emit) {
    if (state.currentStep > 0) {
      emit(state.copyWith(currentStep: state.currentStep - 1));
    }
  }

  /// Peut-on encore décocher un mode de paiement ? La règle est lue ici et par
  /// l'écran, qui a besoin de la même réponse pour expliquer son refus.
  static bool canDeselectPaymentMethod(Set<PaymentMethod> selected) =>
      selected.length > 1;

  void _onPaymentMethodToggled(
    PackageRequestPaymentMethodToggled e,
    Emitter<PackageRequestFormState> emit,
  ) {
    final next = {...state.acceptedPaymentMethods};
    if (next.contains(e.method)) {
      // Décocher le dernier mode retenu était absorbé en silence : la case se
      // rendait décochée puis re-cochée, et le tap passait pour une panne. On
      // refuse explicitement, l'écran peut alors dire pourquoi.
      if (!canDeselectPaymentMethod(next)) return;
      next.remove(e.method);
    } else {
      next.add(e.method);
    }
    emit(state.copyWith(acceptedPaymentMethods: next));
  }
}
