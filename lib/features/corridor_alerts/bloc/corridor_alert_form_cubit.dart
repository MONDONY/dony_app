import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/corridor_alert_repository.dart';
import '../data/models/alert_direction.dart';
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
    this.direction = AlertDirection.travelerWantsPackages,
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
  final AlertDirection direction;

  bool get isValid =>
      (departureCity?.trim().isNotEmpty ?? false) &&
      (arrivalCity?.trim().isNotEmpty ?? false);

  static const _unset = Object();

  CorridorAlertFormState copyWith({
    String? departureCity,
    String? arrivalCity,
    String? departureCountryCode,
    String? arrivalCountryCode,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
    Object? minWeightKg = _unset,
    List<String>? contentCategories,
    CorridorAlertFormStatus? status,
    Object? errorMessage = _unset,
    AlertDirection? direction,
  }) =>
      CorridorAlertFormState(
        departureCity: departureCity ?? this.departureCity,
        arrivalCity: arrivalCity ?? this.arrivalCity,
        departureCountryCode:
            departureCountryCode ?? this.departureCountryCode,
        arrivalCountryCode: arrivalCountryCode ?? this.arrivalCountryCode,
        dateFrom: identical(dateFrom, _unset)
            ? this.dateFrom
            : dateFrom as DateTime?,
        dateTo:
            identical(dateTo, _unset) ? this.dateTo : dateTo as DateTime?,
        minWeightKg: identical(minWeightKg, _unset)
            ? this.minWeightKg
            : minWeightKg as double?,
        contentCategories: contentCategories ?? this.contentCategories,
        status: status ?? this.status,
        errorMessage: identical(errorMessage, _unset)
            ? this.errorMessage
            : errorMessage as String?,
        direction: direction ?? this.direction,
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
        direction,
      ];
}

class CorridorAlertFormCubit extends Cubit<CorridorAlertFormState> {
  CorridorAlertFormCubit(this._repository, this._analytics,
      {CorridorAlertModel? editing,
      AlertDirection initialDirection = AlertDirection.travelerWantsPackages})
      : _editingId = editing?.id,
        super(
          editing == null
              ? CorridorAlertFormState(direction: initialDirection)
              : CorridorAlertFormState(
                  departureCity: editing.departureCity,
                  arrivalCity: editing.arrivalCity,
                  departureCountryCode: editing.departureCountryCode,
                  arrivalCountryCode: editing.arrivalCountryCode,
                  dateFrom: editing.dateFrom,
                  dateTo: editing.dateTo,
                  minWeightKg: editing.minWeightKg,
                  contentCategories: editing.contentCategories,
                  direction: editing.direction,
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

  void clearDateWindow() =>
      emit(state.copyWith(dateFrom: null, dateTo: null));

  void setMinWeight(double? kg) => emit(state.copyWith(minWeightKg: kg));

  void setDirection(AlertDirection d) => emit(state.copyWith(direction: d));

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
      direction: state.direction,
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
