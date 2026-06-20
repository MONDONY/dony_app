import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/corridor_alert_repository.dart';
import '../data/models/corridor_alert_model.dart';

enum CorridorAlertFormStatus { editing, submitting, success, error }

class CorridorAlertFormState extends Equatable {
  const CorridorAlertFormState({
    this.departureCity,
    this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    this.dateFrom,
    this.dateTo,
    this.minWeightKg,
    this.contentCategories = const [],
    this.status = CorridorAlertFormStatus.editing,
    this.errorMessage,
  });

  final String? departureCity;
  final String? arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? minWeightKg;
  final List<String> contentCategories;
  final CorridorAlertFormStatus status;
  final String? errorMessage;

  bool get isValid =>
      (departureCity?.trim().isNotEmpty ?? false) &&
      (arrivalCity?.trim().isNotEmpty ?? false);

  CorridorAlertFormState copyWith({
    String? departureCity,
    String? arrivalCity,
    String? departureCountryCode,
    String? arrivalCountryCode,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minWeightKg,
    List<String>? contentCategories,
    CorridorAlertFormStatus? status,
    String? errorMessage,
  }) =>
      CorridorAlertFormState(
        departureCity: departureCity ?? this.departureCity,
        arrivalCity: arrivalCity ?? this.arrivalCity,
        departureCountryCode:
            departureCountryCode ?? this.departureCountryCode,
        arrivalCountryCode: arrivalCountryCode ?? this.arrivalCountryCode,
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        minWeightKg: minWeightKg ?? this.minWeightKg,
        contentCategories: contentCategories ?? this.contentCategories,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [
        departureCity,
        arrivalCity,
        departureCountryCode,
        arrivalCountryCode,
        dateFrom,
        dateTo,
        minWeightKg,
        contentCategories,
        status,
        errorMessage,
      ];
}

class CorridorAlertFormCubit extends Cubit<CorridorAlertFormState> {
  CorridorAlertFormCubit(this._repository, this._analytics,
      {CorridorAlertModel? editing})
      : _editingId = editing?.id,
        super(
          editing == null
              ? const CorridorAlertFormState()
              : CorridorAlertFormState(
                  departureCity: editing.departureCity,
                  arrivalCity: editing.arrivalCity,
                  departureCountryCode: editing.departureCountryCode,
                  arrivalCountryCode: editing.arrivalCountryCode,
                  dateFrom: editing.dateFrom,
                  dateTo: editing.dateTo,
                  minWeightKg: editing.minWeightKg,
                  contentCategories: editing.contentCategories,
                ),
        );

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;
  final String? _editingId;

  bool get isEditing => _editingId != null;

  void setDeparture(String city, String? countryCode) => emit(state.copyWith(
        departureCity: city,
        departureCountryCode: countryCode,
      ));

  void setArrival(String city, String? countryCode) => emit(state.copyWith(
        arrivalCity: city,
        arrivalCountryCode: countryCode,
      ));

  void setDateWindow(DateTime from, DateTime to) =>
      emit(state.copyWith(dateFrom: from, dateTo: to));

  void clearDateWindow() => emit(CorridorAlertFormState(
        departureCity: state.departureCity,
        arrivalCity: state.arrivalCity,
        departureCountryCode: state.departureCountryCode,
        arrivalCountryCode: state.arrivalCountryCode,
        minWeightKg: state.minWeightKg,
        contentCategories: state.contentCategories,
        status: state.status,
        errorMessage: state.errorMessage,
      ));

  void setMinWeight(double? kg) => emit(state.copyWith(minWeightKg: kg));

  void toggleCategory(String category) {
    final next = List<String>.from(state.contentCategories);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    emit(state.copyWith(contentCategories: next));
  }

  Future<void> submit() async {
    if (!state.isValid) {
      return;
    }
    emit(state.copyWith(status: CorridorAlertFormStatus.submitting));
    final draft = CorridorAlertDraft(
      departureCity: state.departureCity!.trim(),
      arrivalCity: state.arrivalCity!.trim(),
      departureCountryCode: state.departureCountryCode,
      arrivalCountryCode: state.arrivalCountryCode,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      minWeightKg: state.minWeightKg,
      contentCategories: state.contentCategories,
    );
    try {
      if (_editingId != null) {
        await _repository.update(_editingId, draft);
        unawaited(
            _analytics.logEvent(AnalyticsEvents.corridorAlertUpdated));
      } else {
        await _repository.create(draft);
        unawaited(
            _analytics.logEvent(AnalyticsEvents.corridorAlertCreated));
      }
      emit(state.copyWith(status: CorridorAlertFormStatus.success));
    } catch (err) {
      emit(state.copyWith(
        status: CorridorAlertFormStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }
}
