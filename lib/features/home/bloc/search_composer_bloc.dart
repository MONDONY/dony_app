import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

/// Porte l'écran de composition d'une recherche.
///
/// Les filtres sont réglés au doigt. Le compteur se met à jour à chaque
/// changement : c'est lui qui remplace la liste de résultats absente de cet
/// écran. (La saisie « en une phrase » et son parseur serveur ont été retirés :
/// 2 % des recherches du test du 27/09 au 12/10 en venaient.)
class SearchComposerBloc
    extends Bloc<SearchComposerEvent, SearchComposerState> {
  SearchComposerBloc(
    this._announcementRepository,
    this._packageRequestRepository,
    this._analytics, {
    required SearchMode mode,
    required HomeSearchFilters initialFilters,
  }) : _mode = mode,
       super(SearchComposerState(filters: initialFilters)) {
    on<SearchComposerStarted>(_onStarted);
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
        gpProOnly: false,
        suitcase23Only: false,
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
          gpProOnly: q.gpProOnly,
          minRating: q.minRating,
          weekendOnly: q.weekendOnly,
          transportMode: q.transportMode,
          kycVerifiedOnly: q.kycVerifiedOnly,
          contentType: q.contentType,
          userLat: q.userLat,
          userLng: q.userLng,
          radiusKm: q.radiusKm,
          urgent: q.urgent,
          maxStops: q.maxStops,
          paymentMethods: q.paymentMethods,
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
