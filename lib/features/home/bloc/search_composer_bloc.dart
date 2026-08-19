import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

/// Porte l'écran de composition d'une recherche.
///
/// Deux chemins mènent au même état : la phrase, qui passe par le parseur, et les
/// filtres réglés au doigt, qui n'y passent pas. Le compteur se met à jour dans les
/// deux cas, c'est lui qui remplace la liste de résultats absente de cet écran.
class SearchComposerBloc extends Bloc<SearchComposerEvent, SearchComposerState> {
  SearchComposerBloc(
    this._parseRepository,
    this._announcementRepository,
    this._packageRequestRepository,
    this._analytics, {
    required SearchMode mode,
    required HomeSearchFilters initialFilters,
  })  : _mode = mode,
        super(SearchComposerState(filters: initialFilters)) {
    on<SearchComposerStarted>(_onStarted);
    on<SearchComposerPhraseSubmitted>(_onPhraseSubmitted);
    on<SearchComposerUnresolvedAnswered>(_onUnresolvedAnswered);
    on<SearchComposerCleared>(_onCleared);

    // Le réglage au doigt produit une rafale d'événements : on ne compte
    // qu'après la dernière, sinon chaque tap déclenche une requête.
    on<SearchComposerFiltersChanged>(
      _onFiltersChanged,
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 400))
          .switchMap(mapper),
    );
  }

  final SearchParseRepository _parseRepository;
  final AnnouncementRepository _announcementRepository;
  final PackageRequestRepository _packageRequestRepository;
  final AnalyticsService _analytics;
  final SearchMode _mode;

  Future<void> _onStarted(
    SearchComposerStarted event,
    Emitter<SearchComposerState> emit,
  ) async {
    unawaited(_analytics.logEvent(
      AnalyticsEvents.searchComposerOpened,
      properties: {'mode': _mode.name},
    ));
    await _refreshCount(emit, state.filters);
  }

  Future<void> _onPhraseSubmitted(
    SearchComposerPhraseSubmitted event,
    Emitter<SearchComposerState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    emit(state.copyWith(isParsing: true, phrase: text, clearError: true));

    try {
      final result = await _parseRepository.parse(text, _mode);
      final applied = result.applyTo(state.filters);

      emit(state.copyWith(
        filters: applied,
        recognized: result.recognized,
        unresolved: result.unresolved,
        isParsing: false,
      ));

      // La phrase elle-même n'est jamais envoyée : seules des mesures agrégées.
      unawaited(_analytics.logEvent(
        AnalyticsEvents.searchPhraseParsed,
        properties: {
          'recognized_count': result.recognized.length,
          'unresolved_count': result.unresolved.length,
          'used_voice': event.fromVoice,
        },
      ));

      if (result.recognized.isEmpty) {
        unawaited(_analytics.logEvent(
          AnalyticsEvents.searchParseFailed,
          properties: {
            'unresolved_kinds': result.unresolved.map((u) => u.kind.name).toList(),
          },
        ));
      }

      await _refreshCount(emit, applied);
    } catch (e) {
      // Les filtres déjà réglés survivent à un échec du parseur : l'écran reste
      // utilisable au doigt, ce qui est tout l'intérêt de la parité.
      emit(state.copyWith(isParsing: false, error: unwrapDioError(e)));
    }
  }

  Future<void> _onFiltersChanged(
    SearchComposerFiltersChanged event,
    Emitter<SearchComposerState> emit,
  ) async {
    emit(state.copyWith(filters: event.filters));
    await _refreshCount(emit, event.filters);
  }

  Future<void> _onUnresolvedAnswered(
    SearchComposerUnresolvedAnswered event,
    Emitter<SearchComposerState> emit,
  ) async {
    var filters = state.filters;

    switch (event.kind) {
      case UnresolvedKind.priceVague:
        final price = double.tryParse(event.value);
        if (price != null) filters = filters.copyWith(maxPricePerKg: price);
      case UnresolvedKind.cityUnknown:
      case UnresolvedKind.cityAmbiguous:
        filters = filters.copyWith(arrivalCity: event.value);
      case UnresolvedKind.dateVague:
        final date = DateTime.tryParse(event.value);
        if (date != null) filters = filters.copyWith(customDate: date);
    }

    emit(state.copyWith(
      filters: filters,
      unresolved: state.unresolved.where((u) => u.kind != event.kind).toList(),
    ));

    await _refreshCount(emit, filters);
  }

  Future<void> _onCleared(
    SearchComposerCleared event,
    Emitter<SearchComposerState> emit,
  ) async {
    const emptyFilters = HomeSearchFilters();
    emit(const SearchComposerState(filters: emptyFilters));
    await _refreshCount(emit, emptyFilters);
  }

  /// Compte les résultats du mode courant.
  ///
  /// Réutilise le comptage existant, qui lit `totalElements` d'une page de taille 1
  /// en appliquant tous les filtres. Un échec masque le nombre sans remonter
  /// d'erreur : le compteur est une aide à la décision, jamais un bloquant.
  Future<void> _refreshCount(
    Emitter<SearchComposerState> emit,
    HomeSearchFilters filters,
  ) async {
    emit(state.copyWith(isCounting: true));
    try {
      final int total;
      if (_mode.isTrips) {
        final q = filters.toAnnouncementQuery();
        total = await _announcementRepository.countAnnouncements(
          departureCity: q.departureCity,
          arrivalCity: q.arrivalCity,
          departureDateFrom: q.departureDateFrom,
          departureDateTo: q.departureDateTo,
          minAvailableKg: q.minAvailableKg,
          maxAvailableKg: q.maxAvailableKg,
          maxPricePerKg: q.maxPricePerKg,
          kiloProOnly: q.kiloProOnly,
          minRating: q.minRating,
          weekendOnly: q.weekendOnly,
          transportMode: q.transportMode,
          kycVerifiedOnly: q.kycVerifiedOnly,
          contentType: q.contentType,
          userLat: q.userLat,
          userLng: q.userLng,
          radiusKm: q.radiusKm,
          urgent: q.urgent,
        );
      } else {
        final q = filters.toPackageRequestQuery();
        final page = await _packageRequestRepository.search(
          departure: q.departure,
          arrival: q.arrival,
          dateFrom: q.dateFrom,
          dateTo: q.dateTo,
          maxWeight: q.maxWeight,
          parcelSize: q.parcelSize,
          lat: q.userLat,
          lng: q.userLng,
          radiusKm: q.radiusKm,
          urgent: q.urgent,
          matchingMyTrips: q.matchingMyTrips,
          size: 1,
        );
        total = page.totalElements;
      }
      emit(state.copyWith(resultCount: total, isCounting: false));
    } catch (_) {
      emit(state.copyWith(clearResultCount: true, isCounting: false));
    }
  }
}
