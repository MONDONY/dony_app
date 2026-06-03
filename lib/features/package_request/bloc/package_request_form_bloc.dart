import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/package_request_repository.dart';
import 'package_request_form_event.dart';
import 'package_request_form_state.dart';

class PackageRequestFormBloc extends Bloc<PackageRequestFormEvent, PackageRequestFormState> {
  PackageRequestFormBloc(this._repository, [this._analytics])
      : super(const PackageRequestFormState()) {
    on<FormStep1Submitted>(_onStep1);
    on<FormStep2Submitted>(_onStep2);
    on<FormStep3Submitted>(_onStep3);
    on<FormStepBack>(_onStepBack);
    on<FormReset>((_, emit) => emit(const PackageRequestFormState()));
  }

  final PackageRequestRepository _repository;
  final AnalyticsService? _analytics;

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
      final created = await _repository.create(
        departureCity: state.departureCity!,
        arrivalCity: state.arrivalCity!,
        desiredDate: state.desiredDate!,
        dateToleranceDays: state.dateToleranceDays!,
        weightKg: state.weightKg!,
        parcelSize: state.parcelSize!,
        transportMode: state.transportMode!,
        contentCategory: state.contentCategory!,
        description: state.description,
        targetPriceEur: e.targetPriceEur,
        photoUrl: photoUrl,
        pickupNeighborhood: e.pickupNeighborhood,
        deliveryNeighborhood: e.deliveryNeighborhood,
      );
      emit(state.copyWith(
        submissionStatus: FormSubmissionStatus.success,
        createdRequest: created,
      ));
      unawaited(_analytics?.logEvent(
        AnalyticsEvents.packageRequestCreated,
        properties: {'corridor': '${state.departureCity}→${state.arrivalCity}'},
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
}
