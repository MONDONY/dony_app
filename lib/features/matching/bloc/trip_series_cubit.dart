import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/features/matching/data/models/trip_template_from_announcement.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TripSeriesStatus { editing, submitting, done, failed }

enum TripSeriesTemplateStatus { idle, saving, saved, failed }

class TripSeriesState extends Equatable {
  const TripSeriesState({
    required this.visibleMonth,
    this.selected = const [],
    this.status = TripSeriesStatus.editing,
    this.draft = false,
    this.result,
    this.errorCode,
    this.errorSeq = 0,
    this.templateStatus = TripSeriesTemplateStatus.idle,
  });

  /// Premier jour du mois affiché dans le calendrier.
  final DateTime visibleMonth;

  /// Jours cochés (minuit local), triés.
  final List<DateTime> selected;
  final TripSeriesStatus status;

  /// Mode du dernier envoi : brouillons (vrai) ou publication.
  final bool draft;
  final TripSeriesResult? result;

  /// Code du refus : métier du back (`draft-limit-reached`…) ou `unknown`.
  final String? errorCode;
  final int errorSeq;
  final TripSeriesTemplateStatus templateStatus;

  TripSeriesState copyWith({
    DateTime? visibleMonth,
    List<DateTime>? selected,
    TripSeriesStatus? status,
    bool? draft,
    TripSeriesResult? result,
    String? errorCode,
    int? errorSeq,
    TripSeriesTemplateStatus? templateStatus,
  }) => TripSeriesState(
    visibleMonth: visibleMonth ?? this.visibleMonth,
    selected: selected ?? this.selected,
    status: status ?? this.status,
    draft: draft ?? this.draft,
    result: result ?? this.result,
    errorCode: errorCode ?? this.errorCode,
    errorSeq: errorSeq ?? this.errorSeq,
    templateStatus: templateStatus ?? this.templateStatus,
  );

  @override
  List<Object?> get props => [
    visibleMonth,
    selected,
    status,
    draft,
    result,
    errorCode,
    errorSeq,
    templateStatus,
  ];
}

/// Trajet récurrent par dates précises, depuis l'écran de succès d'un trajet
/// direct : dates cochées dans le calendrier, série créée (publiée ou en
/// brouillons, yadony-back #525), puis modèle de trajet enregistré.
class TripSeriesCubit extends Cubit<TripSeriesState> {
  TripSeriesCubit(
    this.announcement,
    this._announcements,
    this._templates,
    this._analytics, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(
         TripSeriesState(
           visibleMonth: _month(
             (now ?? DateTime.now)().isAfter(announcement.departureDate)
                 ? (now ?? DateTime.now)()
                 : announcement.departureDate,
           ),
         ),
       );

  /// Plafond du back (`@Size(max = 12)`).
  static const maxDates = 12;

  /// Le calendrier ne va pas au-delà d'un an.
  static const monthsAhead = 12;

  final AnnouncementModel announcement;
  final AnnouncementRepository _announcements;
  final TripTemplateRepository _templates;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  static DateTime _month(DateTime d) => DateTime(d.year, d.month);
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _today => _day(_now());
  DateTime get sourceDay => _day(announcement.departureDate);

  /// Jour sélectionnable : à venir et différent du trajet d'origine.
  bool isSelectable(DateTime day) {
    final d = _day(day);
    return !d.isBefore(_today) && d != sourceDay;
  }

  bool get canGoBack => state.visibleMonth.isAfter(_month(_now()));

  bool get canGoForward {
    final limit = DateTime(_now().year, _now().month + monthsAhead);
    return state.visibleMonth.isBefore(limit);
  }

  void trackOpened() =>
      unawaited(_analytics.logEvent(AnalyticsEvents.tripSeriesOpened));

  void toggle(DateTime day) {
    if (state.status == TripSeriesStatus.submitting) return;
    final d = _day(day);
    if (!isSelectable(d)) return;
    final selected = [...state.selected];
    if (selected.contains(d)) {
      selected.remove(d);
    } else {
      if (selected.length >= maxDates) return;
      selected
        ..add(d)
        ..sort();
    }
    emit(state.copyWith(selected: selected, status: TripSeriesStatus.editing));
  }

  void showMonth(int delta) {
    if (delta < 0 && !canGoBack) return;
    if (delta > 0 && !canGoForward) return;
    final m = state.visibleMonth;
    emit(state.copyWith(visibleMonth: DateTime(m.year, m.month + delta)));
  }

  Future<void> submit({required bool draft}) async {
    if (state.selected.isEmpty || state.status == TripSeriesStatus.submitting) {
      return;
    }
    emit(state.copyWith(status: TripSeriesStatus.submitting, draft: draft));
    try {
      final result = await _announcements.createSeries(
        announcement.id,
        dates: state.selected,
        saveAsDraft: draft,
      );
      if (isClosed) return;
      if (result.created.isEmpty) {
        _fail(result.failed.isEmpty ? 'unknown' : result.failed.first.code);
        return;
      }
      emit(state.copyWith(status: TripSeriesStatus.done, result: result));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripSeriesCreated,
          properties: {
            'count': result.created.length,
            'failed': result.failed.length,
            'draft': draft,
          },
        ),
      );
    } on AppException catch (e) {
      if (isClosed) return;
      _fail(e.code ?? 'unknown');
    } on Object {
      if (isClosed) return;
      _fail('unknown');
    }
  }

  void _fail(String code) => emit(
    state.copyWith(
      status: TripSeriesStatus.failed,
      errorCode: code,
      errorSeq: state.errorSeq + 1,
    ),
  );

  String get _defaultName =>
      '${announcement.departureCity} → ${announcement.arrivalCity}';

  /// Nom saisi dans la feuille du modèle ; l'itinéraire par défaut.
  late String templateName = _defaultName;

  void setTemplateName(String value) => templateName = value;

  /// « Enregistrer le modèle » : le trajet devient un modèle (sans dates).
  Future<void> saveTemplate() async {
    if (state.templateStatus == TripSeriesTemplateStatus.saving) return;
    final trimmed = templateName.trim();
    final name = trimmed.isEmpty ? _defaultName : trimmed;
    emit(state.copyWith(templateStatus: TripSeriesTemplateStatus.saving));
    try {
      await _templates.create(
        tripTemplateFromAnnouncement(announcement, label: name).toJson(),
      );
      if (isClosed) return;
      emit(state.copyWith(templateStatus: TripSeriesTemplateStatus.saved));
      unawaited(_analytics.logEvent(AnalyticsEvents.tripSeriesTemplateSaved));
    } on Object {
      if (isClosed) return;
      emit(state.copyWith(templateStatus: TripSeriesTemplateStatus.failed));
    }
  }
}
