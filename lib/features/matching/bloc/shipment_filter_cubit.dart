import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange, DateUtils;
import 'package:flutter_bloc/flutter_bloc.dart';

enum ShipmentPeriodBasis { departure, creation }

enum ShipmentPeriodPreset {
  all,
  thisWeek,
  thisMonth,
  last3Months,
  thisYear,
  custom,
}

/// Groupes de statuts pour les puces rapides (miroir de _populateLists).
const kEnvoisEnCours = <String>{'ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT'};
const kEnvoisAVenir = <String>{
  'PENDING',
  'AWAITING_PAYMENT',
  'PAYMENT_ESCROWED',
};
const kEnvoisPasses = <String>{
  'COMPLETED',
  'REJECTED',
  'CANCELLED',
  'NO_SHOW',
  'EXPIRED',
  'PARCEL_REFUSED',
};

const _statusPriority = {
  'IN_TRANSIT': 6,
  'HANDED_OVER': 5,
  'ACCEPTED': 4,
  'PAYMENT_ESCROWED': 3,
  'AWAITING_PAYMENT': 2,
  'PENDING': 1,
  'COMPLETED': 0,
};

class ShipmentFilterState extends Equatable {
  final String query;
  final Set<String> statuses; // {} = tous
  final ShipmentPeriodBasis periodBasis;
  final ShipmentPeriodPreset periodPreset;
  final DateTimeRange? customRange;

  const ShipmentFilterState({
    this.query = '',
    this.statuses = const {},
    this.periodBasis = ShipmentPeriodBasis.departure,
    this.periodPreset = ShipmentPeriodPreset.all,
    this.customRange,
  });

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      periodPreset != ShipmentPeriodPreset.all;

  ShipmentFilterState copyWith({String? query, Set<String>? statuses}) =>
      ShipmentFilterState(
        query: query ?? this.query,
        statuses: statuses ?? this.statuses,
        periodBasis: periodBasis,
        periodPreset: periodPreset,
        customRange: customRange,
      );

  // `statuses` (Set) est comparé sans tenir compte de l'ordre : Equatable utilise
  // DeepCollectionEquality, pas Set.== (qui dépend de l'ordre d'insertion).
  @override
  List<Object?> get props => [
    query,
    statuses,
    periodBasis,
    periodPreset,
    customRange,
  ];
}

bool shipmentMatchesQuery(BidModel b, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  bool m(String? s) => s != null && normalizeSearch(s).contains(q);
  return m(b.departureCity) ||
      m(b.arrivalCity) ||
      m(b.recipientName) ||
      m(b.travelerName) ||
      m(b.trackingNumber);
}

DateTime shipmentDateFor(BidModel b, ShipmentPeriodBasis basis) =>
    basis == ShipmentPeriodBasis.departure
    ? (b.departureDate ?? b.createdAt)
    : b.createdAt;

DateTimeRange? rangeForPreset(
  ShipmentPeriodPreset preset,
  DateTimeRange? custom,
  DateTime now,
) {
  switch (preset) {
    case ShipmentPeriodPreset.all:
      return null;
    case ShipmentPeriodPreset.thisWeek:
      final monday = DateUtils.dateOnly(
        now,
      ).subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(start: monday, end: now);
    case ShipmentPeriodPreset.thisMonth:
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    case ShipmentPeriodPreset.last3Months:
      // dateOnly : on borne au début de journée pour ne pas exclure un envoi
      // daté plus tôt dans la journée que l'heure courante.
      return DateTimeRange(
        start: DateUtils.dateOnly(now.subtract(const Duration(days: 90))),
        end: now,
      );
    case ShipmentPeriodPreset.thisYear:
      return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    case ShipmentPeriodPreset.custom:
      if (custom == null) return null;
      return DateTimeRange(
        start: DateUtils.dateOnly(custom.start),
        end: DateTime(
          custom.end.year,
          custom.end.month,
          custom.end.day,
          23,
          59,
          59,
        ),
      );
  }
}

List<BidModel> _sortShipments(List<BidModel> bids) {
  bids.sort((a, b) {
    final pa = _statusPriority[a.status] ?? 0;
    final pb = _statusPriority[b.status] ?? 0;
    if (pa != pb) return pb.compareTo(pa);
    final da = a.departureDate ?? DateTime(9999);
    final db = b.departureDate ?? DateTime(9999);
    return da.compareTo(db);
  });
  return bids;
}

List<BidModel> applyShipmentFilters(
  List<BidModel> bids,
  ShipmentFilterState f,
  DateTime now,
) {
  Iterable<BidModel> out = bids;
  if (f.statuses.isNotEmpty)
    out = out.where((b) => f.statuses.contains(b.status));
  if (f.query.trim().isNotEmpty)
    out = out.where((b) => shipmentMatchesQuery(b, f.query));
  final range = rangeForPreset(f.periodPreset, f.customRange, now);
  if (range != null) {
    out = out.where((b) {
      final d = shipmentDateFor(b, f.periodBasis);
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    });
  }
  return _sortShipments(out.toList());
}

class ShipmentFilterCubit extends Cubit<ShipmentFilterState> {
  ShipmentFilterCubit(this._analytics) : super(const ShipmentFilterState());
  final AnalyticsService _analytics;

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setStatuses(Set<String> statuses) {
    emit(state.copyWith(statuses: statuses));
    _track();
  }

  void applyQuickPreset(Set<String> group) {
    emit(state.copyWith(statuses: group));
    _track();
  }

  void setPeriod({
    required ShipmentPeriodBasis basis,
    required ShipmentPeriodPreset preset,
    DateTimeRange? range,
  }) {
    emit(
      ShipmentFilterState(
        query: state.query,
        statuses: state.statuses,
        periodBasis: basis,
        periodPreset: preset,
        customRange: preset == ShipmentPeriodPreset.custom ? range : null,
      ),
    );
    _track();
  }

  void reset() => emit(const ShipmentFilterState());

  void _track() {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.shipmentFilterApplied,
        properties: {
          'has_query': state.query.trim().isNotEmpty,
          'status_count': state.statuses.length,
          'period_preset': state.periodPreset.name,
          'period_basis': state.periodBasis.name,
        },
      ),
    );
  }
}
