import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:equatable/equatable.dart';

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
    this.centerLat,
    this.centerLng,
    this.radiusKm,
    this.centerLabel,
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

  // ── Zone de remise optionnelle (alertes trajet) ──────────────────────────
  final double? centerLat;
  final double? centerLng;
  final int? radiusKm;
  final String? centerLabel;

  bool get hasZone =>
      centerLat != null && centerLng != null && radiusKm != null;

  bool get isValid =>
      (departureCity?.trim().isNotEmpty ?? false) &&
      (arrivalCity?.trim().isNotEmpty ?? false);

  static const _unset = Object();

  CorridorAlertFormState copyWith({
    Object? departureCity = _unset,
    Object? arrivalCity = _unset,
    Object? departureCountryCode = _unset,
    Object? arrivalCountryCode = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
    Object? minWeightKg = _unset,
    List<String>? contentCategories,
    CorridorAlertFormStatus? status,
    Object? errorMessage = _unset,
    AlertDirection? direction,
    Object? centerLat = _unset,
    Object? centerLng = _unset,
    Object? radiusKm = _unset,
    Object? centerLabel = _unset,
  }) => CorridorAlertFormState(
    departureCity: identical(departureCity, _unset)
        ? this.departureCity
        : departureCity as String?,
    arrivalCity: identical(arrivalCity, _unset)
        ? this.arrivalCity
        : arrivalCity as String?,
    departureCountryCode: identical(departureCountryCode, _unset)
        ? this.departureCountryCode
        : departureCountryCode as String?,
    arrivalCountryCode: identical(arrivalCountryCode, _unset)
        ? this.arrivalCountryCode
        : arrivalCountryCode as String?,
    dateFrom: identical(dateFrom, _unset)
        ? this.dateFrom
        : dateFrom as DateTime?,
    dateTo: identical(dateTo, _unset) ? this.dateTo : dateTo as DateTime?,
    minWeightKg: identical(minWeightKg, _unset)
        ? this.minWeightKg
        : minWeightKg as double?,
    contentCategories: contentCategories ?? this.contentCategories,
    status: status ?? this.status,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    direction: direction ?? this.direction,
    centerLat: identical(centerLat, _unset)
        ? this.centerLat
        : centerLat as double?,
    centerLng: identical(centerLng, _unset)
        ? this.centerLng
        : centerLng as double?,
    radiusKm: identical(radiusKm, _unset) ? this.radiusKm : radiusKm as int?,
    centerLabel: identical(centerLabel, _unset)
        ? this.centerLabel
        : centerLabel as String?,
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
    centerLat,
    centerLng,
    radiusKm,
    centerLabel,
  ];
}

class CorridorAlertFormCubit extends Cubit<CorridorAlertFormState> {
  CorridorAlertFormCubit(
    this._repository,
    this._analytics, {
    CorridorAlertModel? editing,
    AlertDirection initialDirection = AlertDirection.travelerWantsPackages,
    HiveService? hiveService,
  }) : _editingId = editing?.id,
       _hiveService = hiveService,
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
                 centerLat: editing.centerLat,
                 centerLng: editing.centerLng,
                 radiusKm: editing.radiusKm,
                 centerLabel: editing.centerLabel,
               ),
       );

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;
  final HiveService? _hiveService;
  final String? _editingId;

  bool get isEditing => _editingId != null;

  void setDeparture(String city, String? countryCode) => emit(
    state.copyWith(departureCity: city, departureCountryCode: countryCode),
  );

  void setArrival(String city, String? countryCode) =>
      emit(state.copyWith(arrivalCity: city, arrivalCountryCode: countryCode));

  void clearDeparture() =>
      emit(state.copyWith(departureCity: null, departureCountryCode: null));

  void clearArrival() =>
      emit(state.copyWith(arrivalCity: null, arrivalCountryCode: null));

  /// Échange départ et arrivée (ville + code pays).
  void swapCorridor() => emit(
    state.copyWith(
      departureCity: state.arrivalCity,
      arrivalCity: state.departureCity,
      departureCountryCode: state.arrivalCountryCode,
      arrivalCountryCode: state.departureCountryCode,
    ),
  );

  void setDateWindow(DateTime from, DateTime to) =>
      emit(state.copyWith(dateFrom: from, dateTo: to));

  void clearDateWindow() => emit(state.copyWith(dateFrom: null, dateTo: null));

  void setMinWeight(double? kg) => emit(state.copyWith(minWeightKg: kg));

  void setDirection(AlertDirection d) => emit(state.copyWith(direction: d));

  /// Définit la zone de remise (centre + rayon + label). Réservé aux alertes
  /// trajet ; l'UI ne l'expose que pour `senderWantsTrips`.
  void setZone({
    required double lat,
    required double lng,
    required int radiusKm,
    String? label,
  }) => emit(
    state.copyWith(
      centerLat: lat,
      centerLng: lng,
      radiusKm: radiusKm,
      centerLabel: label,
    ),
  );

  void clearZone() => emit(
    state.copyWith(
      centerLat: null,
      centerLng: null,
      radiusKm: null,
      centerLabel: null,
    ),
  );

  /// Remplace la sélection complète.
  ///
  /// Le sélecteur de contenu émet l'ensemble voulu ; le redécomposer en
  /// toggles produisait un `emit` par élément, donc autant de reconstructions
  /// du formulaire pour un seul geste.
  void setCategories(List<String> categories) =>
      emit(state.copyWith(contentCategories: List<String>.from(categories)));

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
      centerLat: state.centerLat,
      centerLng: state.centerLng,
      radiusKm: state.radiusKm,
      centerLabel: state.centerLabel,
    );
    try {
      if (_editingId != null) {
        await _repository.update(_editingId, draft);
        unawaited(_analytics.logEvent(AnalyticsEvents.corridorAlertUpdated));
      } else {
        await _repository.create(draft);
        unawaited(_analytics.logEvent(AnalyticsEvents.corridorAlertCreated));
      }
      final hive = _hiveService;
      if (hive != null) {
        unawaited(
          hive.userPrefs.put(HiveService.kHasActiveCorridorAlert, true),
        );
      }
      emit(state.copyWith(status: CorridorAlertFormStatus.success));
    } catch (err) {
      emit(
        state.copyWith(
          status: CorridorAlertFormStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }
}
