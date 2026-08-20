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
class SearchComposerBloc
    extends Bloc<SearchComposerEvent, SearchComposerState> {
  SearchComposerBloc(
    this._parseRepository,
    this._announcementRepository,
    this._packageRequestRepository,
    this._analytics, {
    required SearchMode mode,
    required HomeSearchFilters initialFilters,
  }) : _mode = mode,
       super(SearchComposerState(filters: initialFilters)) {
    on<SearchComposerStarted>(_onStarted);
    on<SearchComposerPhraseSubmitted>(_onPhraseSubmitted);
    on<SearchComposerUnresolvedAnswered>(_onUnresolvedAnswered);
    on<SearchComposerCleared>(_onCleared);

    // Le réglage au doigt produit une rafale d'événements : seul le COMPTAGE
    // réseau, coûteux, doit attendre la dernière avant de partir — jamais
    // l'application du filtre lui-même. `debounceTime` en amont du handler
    // retardait aussi l'`emit` des filtres : un enchaînement rapide (départ
    // PUIS arrivée PUIS validation, plus vite que les 400 ms) perdait
    // silencieusement la ville de départ, jamais comptée nulle part. Ici,
    // `switchMap` seul (= `restartable()` de `bloc_concurrency`, réécrit sans
    // ajouter la dépendance) laisse chaque `emit(filters)` s'appliquer
    // immédiatement et n'annule que le comptage encore en vol.
    on<SearchComposerFiltersChanged>(
      _onFiltersChanged,
      transformer: (events, mapper) => events.switchMap(mapper),
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
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.searchComposerOpened,
        properties: {'mode': _mode.name},
      ),
    );
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

      emit(
        state.copyWith(
          filters: applied,
          recognized: result.recognized,
          unresolved: result.unresolved,
          isParsing: false,
        ),
      );

      // La phrase elle-même n'est jamais envoyée : seules des mesures agrégées.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.searchPhraseParsed,
          properties: {
            'recognized_count': result.recognized.length,
            'unresolved_count': result.unresolved.length,
            'used_voice': event.fromVoice,
          },
        ),
      );

      // Règle projet : les events métier se tirent dans le BLoC, jamais le
      // widget. `duration_ms` est calculé par l'appelant (`SearchComposerScreen`,
      // seul point qui voit l'ouverture et la fermeture de la feuille de
      // dictée) et transmis via l'event plutôt que mesuré ici.
      if (event.fromVoice) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.searchVoiceUsed,
            properties: {
              if (event.voiceDurationMs != null)
                'duration_ms': event.voiceDurationMs!,
            },
          ),
        );
      }

      if (result.recognized.isEmpty) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.searchParseFailed,
            properties: {
              'unresolved_kinds': result.unresolved
                  .map((u) => u.kind.name)
                  .toList(),
            },
          ),
        );
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
    // Toujours synchrone, jamais debounced : voir le commentaire sur
    // `on<SearchComposerFiltersChanged>` dans le constructeur.
    emit(state.copyWith(filters: event.filters));
    // Seul ce qui suit — le comptage réseau — attend : `switchMap` annule
    // cette attente (et l'appel réseau qui suivrait) si un nouvel événement
    // arrive avant son terme, sans jamais toucher l'`emit` déjà appliqué.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refreshCount(emit, event.filters);
  }

  Future<void> _onUnresolvedAnswered(
    SearchComposerUnresolvedAnswered event,
    Emitter<SearchComposerState> emit,
  ) async {
    var filters = state.filters;
    final value = event.value;

    // Une valeur vide (« Peu importe ») signifie « pas de contrainte » : elle
    // retire un filtre déjà réglé plutôt que de le laisser tel quel, sinon un
    // prix ou une date posés avant la phrase survivraient à un choix qui dit
    // explicitement le contraire.
    switch (event.kind) {
      case UnresolvedKind.priceVague:
        if (value.isEmpty) {
          filters = filters.copyWith(clearMaxPricePerKg: true);
        } else {
          final price = double.tryParse(value);
          if (price != null) filters = filters.copyWith(maxPricePerKg: price);
        }
      case UnresolvedKind.cityUnknown:
      case UnresolvedKind.cityAmbiguous:
        if (value.isNotEmpty) filters = filters.copyWith(arrivalCity: value);
      case UnresolvedKind.dateVague:
        if (value.isEmpty) {
          filters = filters.copyWith(
            datePreset: DonyDatePreset.none,
            clearCustomDate: true,
          );
        } else if (value == 'thisWeek') {
          // `unresolved_question.dart` propose des noms de `DonyDatePreset`
          // pour cette question, pas des dates ISO : `DateTime.tryParse` y
          // échouerait toujours en silence (aucun filtre posé, la question
          // disparaît quand même de l'écran).
          filters = filters.copyWith(
            datePreset: DonyDatePreset.thisWeek,
            clearCustomDate: true,
          );
        } else if (value == 'thisMonth') {
          filters = filters.copyWith(
            datePreset: DonyDatePreset.thisMonth,
            clearCustomDate: true,
          );
        } else {
          // Filet de sécurité au cas où une vraie date ISO arriverait un jour
          // depuis une autre source de valeurs pour cette question.
          final date = DateTime.tryParse(value);
          if (date != null) filters = filters.copyWith(customDate: date);
        }
    }

    emit(
      state.copyWith(
        filters: filters,
        unresolved: state.unresolved
            .where((u) => u.kind != event.kind)
            .toList(),
      ),
    );

    await _refreshCount(emit, filters);
  }

  Future<void> _onCleared(
    SearchComposerCleared event,
    Emitter<SearchComposerState> emit,
  ) async {
    final cleared = _clearedForMode(state.filters, _mode);
    emit(SearchComposerState(filters: cleared));
    await _refreshCount(emit, cleared);
  }

  /// Efface les filtres communs et ceux du mode courant. Ceux de l'autre mode
  /// sont préservés : les effacer serait une surprise invisible pour
  /// l'utilisateur qui ne consulte pas ce mode-là depuis cet écran.
  static HomeSearchFilters _clearedForMode(
    HomeSearchFilters value,
    SearchMode mode,
  ) {
    final common = value.copyWith(
      clearCorridor: true,
      datePreset: DonyDatePreset.none,
      clearCustomDate: true,
      urgentOnly: false,
      clearNearMe: true,
    );
    if (mode.isTrips) {
      return common.copyWith(
        clearMaxPricePerKg: true,
        clearWeight: true,
        kiloProOnly: false,
        clearMinRating: true,
        weekendOnly: false,
        clearTransportMode: true,
        kycVerifiedOnly: false,
        clearContentType: true,
        clearUrgencyFilter: true,
      );
    }
    return common.copyWith(
      clearMaxWeight: true,
      clearParcelSize: true,
      matchingMyTrips: false,
    );
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
