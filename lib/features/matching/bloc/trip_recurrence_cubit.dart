import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Rythme d'un trajet récurrent choisi à l'étape 1 de la création.
enum TripRecurrenceFrequency {
  weekly('weekly'),
  biweekly('biweekly'),
  monthly('monthly');

  const TripRecurrenceFrequency(this.wire);

  /// Nom technique (analytics, brouillon local).
  final String wire;

  static TripRecurrenceFrequency? fromWire(Object? raw) {
    for (final f in values) {
      if (f.wire == raw) return f;
    }
    return null;
  }
}

/// Dates d'un trajet récurrent, calculées à partir de la date de départ.
abstract final class TripRecurrenceDates {
  /// Dates proposées d'office après le premier trajet, par rythme : un peu
  /// plus d'un mois de trajets chaque semaine, environ trois mois sinon. Le
  /// voyageur ajuste ensuite au calendrier (« Choisir les dates »).
  static int defaultCount(TripRecurrenceFrequency f) => switch (f) {
    TripRecurrenceFrequency.weekly => 4,
    TripRecurrenceFrequency.biweekly => 3,
    TripRecurrenceFrequency.monthly => 3,
  };

  /// Premier jour hors calendrier de série : le calendrier ne va pas au-delà
  /// de [TripSeriesCubit.monthsAhead] mois après le mois courant.
  static DateTime limitFor(DateTime today) =>
      DateTime(today.year, today.month + TripSeriesCubit.monthsAhead + 1);

  /// Le [index]-ième jour après [start] au rythme [f] (index 1 = la date
  /// suivante). Chaque mois : même jour du mois, ramené au dernier jour d'un
  /// mois plus court (31 janvier → 28 ou 29 février → 31 mars).
  static DateTime nth(DateTime start, TripRecurrenceFrequency f, int index) {
    final d = DateTime(start.year, start.month, start.day);
    switch (f) {
      case TripRecurrenceFrequency.weekly:
        return DateTime(d.year, d.month, d.day + 7 * index);
      case TripRecurrenceFrequency.biweekly:
        return DateTime(d.year, d.month, d.day + 14 * index);
      case TripRecurrenceFrequency.monthly:
        final lastDay = DateTime(d.year, d.month + index + 1, 0).day;
        final day = d.day > lastDay ? lastDay : d.day;
        return DateTime(d.year, d.month + index, day);
    }
  }

  /// Dates suivant le premier trajet (celui-ci exclu), au plus [count] et au
  /// plus [TripSeriesCubit.maxDates] (plafond du back), toutes avant
  /// [limitFor].
  static List<DateTime> compute(
    DateTime start,
    TripRecurrenceFrequency f, {
    required DateTime today,
    int? count,
  }) {
    final wanted = (count ?? defaultCount(f)).clamp(
      0,
      TripSeriesCubit.maxDates,
    );
    final limit = limitFor(today);
    final out = <DateTime>[];
    for (var i = 1; out.length < wanted; i++) {
      final next = nth(start, f, i);
      if (!next.isBefore(limit)) break;
      out.add(next);
    }
    return out;
  }
}

class TripRecurrenceState extends Equatable {
  const TripRecurrenceState({
    this.enabled = false,
    this.frequency = TripRecurrenceFrequency.monthly,
    this.departureDate,
    this.dates = const [],
    this.customized = false,
    required this.visibleMonth,
  });

  final bool enabled;
  final TripRecurrenceFrequency frequency;

  /// Jour du premier trajet (minuit local), null tant qu'il n'est pas choisi.
  final DateTime? departureDate;

  /// Dates des trajets suivants (le premier exclu), triées.
  final List<DateTime> dates;

  /// Dates retouchées au calendrier plutôt que calculées par le rythme.
  final bool customized;

  /// Mois affiché par le calendrier « Choisir les dates ».
  final DateTime visibleMonth;

  /// Dates envoyées à la série après la publication : aucune si la
  /// récurrence est éteinte ou sans date de départ.
  List<DateTime> get seriesDates =>
      enabled && departureDate != null ? dates : const [];

  /// Trajets publiés en tout : le premier, plus la série.
  int get totalTrips => 1 + dates.length;

  TripRecurrenceState copyWith({
    bool? enabled,
    TripRecurrenceFrequency? frequency,
    DateTime? departureDate,
    bool clearDepartureDate = false,
    List<DateTime>? dates,
    bool? customized,
    DateTime? visibleMonth,
  }) => TripRecurrenceState(
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    departureDate: clearDepartureDate
        ? null
        : departureDate ?? this.departureDate,
    dates: dates ?? this.dates,
    customized: customized ?? this.customized,
    visibleMonth: visibleMonth ?? this.visibleMonth,
  );

  @override
  List<Object?> get props => [
    enabled,
    frequency,
    departureDate,
    dates,
    customized,
    visibleMonth,
  ];
}

/// Récurrence d'un trajet choisie à l'étape 1 de sa création : rythme,
/// dates calculées à partir du départ, retouches au calendrier. La série
/// elle-même est créée après la publication par [TripSeriesCubit]
/// (`POST /announcements/{id}/series`).
class TripRecurrenceCubit extends Cubit<TripRecurrenceState> {
  TripRecurrenceCubit(this._analytics, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(TripRecurrenceState(visibleMonth: _month((now ?? DateTime.now)())));

  final AnalyticsService _analytics;
  final DateTime Function() _now;

  /// Retouche déjà comptée depuis la dernière ouverture du calendrier.
  bool _customizeLogged = false;

  static DateTime _month(DateTime d) => DateTime(d.year, d.month);
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _today => _day(_now());

  /// Jour du premier trajet, entouré au calendrier.
  DateTime? get sourceDay => state.departureDate;

  List<DateTime> _computed(DateTime? start, TripRecurrenceFrequency f) =>
      start == null
      ? const []
      : TripRecurrenceDates.compute(start, f, today: _today);

  /// Interrupteur « Vous faites ce trajet souvent ? ».
  void setEnabled(bool enabled) {
    if (enabled == state.enabled) return;
    emit(
      state.copyWith(
        enabled: enabled,
        dates: _computed(state.departureDate, state.frequency),
        customized: false,
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripRecurrenceToggled,
        properties: {'enabled': enabled},
      ),
    );
  }

  /// Puce de rythme : les dates sont recalculées, une retouche est perdue.
  void chooseFrequency(TripRecurrenceFrequency f) {
    if (f == state.frequency && !state.customized) return;
    emit(
      state.copyWith(
        frequency: f,
        dates: _computed(state.departureDate, f),
        customized: false,
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripRecurrenceFrequencyChosen,
        properties: {'frequency': f.wire},
      ),
    );
  }

  /// Date de départ du formulaire changée : les dates suivantes en découlent
  /// (une retouche au calendrier ne vaut plus pour un autre départ).
  void departureDateChanged(DateTime? date) {
    final day = date == null ? null : _day(date);
    if (day == state.departureDate) return;
    emit(
      state.copyWith(
        departureDate: day,
        clearDepartureDate: day == null,
        dates: _computed(day, state.frequency),
        customized: false,
      ),
    );
  }

  /// Brouillon local rechargé : rien n'est mesuré.
  void restore({required bool enabled, TripRecurrenceFrequency? frequency}) {
    final f = frequency ?? state.frequency;
    emit(
      state.copyWith(
        enabled: enabled,
        frequency: f,
        dates: _computed(state.departureDate, f),
        customized: false,
      ),
    );
  }

  // ── Calendrier « Choisir les dates » ────────────────────────────────────

  void customDatesOpened() {
    _customizeLogged = false;
    final first = state.dates.isNotEmpty
        ? state.dates.first
        : state.departureDate ?? _now();
    final month = _month(first);
    emit(
      state.copyWith(
        visibleMonth: month.isBefore(_month(_now())) ? _month(_now()) : month,
      ),
    );
  }

  /// Jour cochable : à venir, autre que le premier trajet, dans la fenêtre
  /// du calendrier.
  bool isSelectable(DateTime day) {
    final d = _day(day);
    return !d.isBefore(_today) &&
        d != state.departureDate &&
        d.isBefore(TripRecurrenceDates.limitFor(_today));
  }

  bool get canGoBack => state.visibleMonth.isAfter(_month(_now()));

  bool get canGoForward {
    final limit = DateTime(
      _now().year,
      _now().month + TripSeriesCubit.monthsAhead,
    );
    return state.visibleMonth.isBefore(limit);
  }

  void showMonth(int delta) {
    if (delta < 0 && !canGoBack) return;
    if (delta > 0 && !canGoForward) return;
    final m = state.visibleMonth;
    emit(state.copyWith(visibleMonth: DateTime(m.year, m.month + delta)));
  }

  void toggleDate(DateTime day) {
    final d = _day(day);
    if (!isSelectable(d)) return;
    final dates = [...state.dates];
    if (dates.contains(d)) {
      dates.remove(d);
    } else {
      if (dates.length >= TripSeriesCubit.maxDates) return;
      dates
        ..add(d)
        ..sort();
    }
    emit(state.copyWith(dates: dates, customized: true));
    if (!_customizeLogged) {
      _customizeLogged = true;
      unawaited(
        _analytics.logEvent(AnalyticsEvents.tripRecurrenceDatesCustomized),
      );
    }
  }
}
