import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/kg_price_stepper.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TripPriceSuggestionStatus { initial, loading, loaded }

/// D'où vient le prix conseillé affiché.
enum TripPriceSuggestionSource {
  /// Médiane des trajets de la route, calculée par le back.
  backend,

  /// Médiane embarquée de la devise ([KgPriceReference]) : back ancien (404),
  /// erreur réseau ou route trop peu fréquentée.
  fallback,
}

/// Lieu d'ouverture de l'éditeur des prix par article.
enum TripItemPricesSource {
  /// « Ajouter mes prix » de la carte vide.
  step,

  /// « Modifier » de la carte remplie.
  cardEdit;

  String get wire => switch (this) {
    step => 'step',
    cardEdit => 'card_edit',
  };
}

class TripPriceSuggestionState extends Equatable {
  const TripPriceSuggestionState({
    this.status = TripPriceSuggestionStatus.initial,
    this.currency = SupportedCurrency.eur,
    this.suggestion,
  });

  final TripPriceSuggestionStatus status;

  /// Devise demandée, celle du trajet.
  final SupportedCurrency currency;

  /// Réponse du back, `null` sans réponse exploitable.
  final TripPriceSuggestion? suggestion;

  /// Réponse du back dans la devise du trajet (un back qui répondrait dans
  /// une autre devise est ignoré : ses montants seraient faux ici).
  TripPriceSuggestion? get _usable {
    final s = suggestion;
    if (s == null || s.currency != currency.code) return null;
    return s;
  }

  TripPriceSuggestionSource get source => _usable?.pricePerKg != null
      ? TripPriceSuggestionSource.backend
      : TripPriceSuggestionSource.fallback;

  /// Prix au kilo conseillé, toujours dans les bornes du sélecteur.
  double get suggestedPricePerKg {
    final backend = _usable?.pricePerKg;
    final bounds = kgPriceStepperBoundsFor(currency);
    return clampKgPrice(
      backend ?? KgPriceReference.forCurrency(currency).marketMedian,
      bounds,
    );
  }

  /// Le prix conseillé est une vraie médiane de la route : la pastille
  /// « Prix le plus courant sur ce trajet » n'est montrée que dans ce cas.
  bool get isMostCommonOnRoute => source == TripPriceSuggestionSource.backend;

  /// Prix pratiqués par article sur la route, vides sans réponse du back.
  List<TripPriceSuggestionItem> get items => _usable?.items ?? const [];

  TripPriceSuggestionState copyWith({
    TripPriceSuggestionStatus? status,
    SupportedCurrency? currency,
    TripPriceSuggestion? Function()? suggestion,
  }) => TripPriceSuggestionState(
    status: status ?? this.status,
    currency: currency ?? this.currency,
    suggestion: suggestion != null ? suggestion() : this.suggestion,
  );

  @override
  List<Object?> get props => [status, currency, suggestion];
}

/// Prix conseillés de l'étape « Prix & conditions » d'un trajet, et suivi
/// des gestes faits sur le prix (analytics émis ici, jamais dans le widget).
class TripPriceSuggestionCubit extends Cubit<TripPriceSuggestionState> {
  TripPriceSuggestionCubit(this._repository, this._analytics)
    : super(const TripPriceSuggestionState());

  final PriceSuggestionRepository _repository;
  final AnalyticsService _analytics;

  /// Dernière route demandée, pour ne pas recharger la même deux fois.
  String? _lastKey;

  /// Charge les prix conseillés de la route. Sans effet si la même route et
  /// la même devise sont déjà chargées ou en cours.
  Future<void> load({
    required String departureCity,
    required String arrivalCity,
    required SupportedCurrency currency,
  }) async {
    final from = departureCity.trim();
    final to = arrivalCity.trim();
    if (from.isEmpty || to.isEmpty) return;
    final key = '${from.toLowerCase()}|${to.toLowerCase()}|${currency.code}';
    if (key == _lastKey) return;
    _lastKey = key;
    emit(
      TripPriceSuggestionState(
        status: TripPriceSuggestionStatus.loading,
        currency: currency,
      ),
    );
    final suggestion = await _repository.getSuggestions(
      departureCity: from,
      arrivalCity: to,
      currency: currency.code,
    );
    // Une autre route a été demandée pendant l'attente : la réponse est
    // périmée.
    if (isClosed || key != _lastKey) return;
    final next = TripPriceSuggestionState(
      status: TripPriceSuggestionStatus.loaded,
      currency: currency,
      suggestion: suggestion,
    );
    emit(next);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripPriceSuggestionLoaded,
        properties: {
          'has_kg_price': next.isMostCommonOnRoute,
          'sample_size_bracket': sampleSizeBracket(
            next._usable?.sampleSize ?? 0,
          ),
          'items_count': next.items.length,
          'source': next.source.name,
          'currency': currency.code,
        },
      ),
    );
  }

  /// Le voyageur a monté ou baissé son prix d'un pas.
  void priceAdjusted({required bool up, required bool fromSuggested}) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripPriceAdjusted,
        properties: {
          'direction': up ? 'up' : 'down',
          'from_suggested': fromSuggested,
        },
      ),
    );
  }

  /// « Revenir au prix conseillé ».
  void priceResetToSuggested() {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripPriceResetToSuggested,
        properties: {'source': state.source.name},
      ),
    );
  }

  /// Modification d'un trajet vendu aux seuls prix par article : le
  /// voyageur ajoute un prix au kilo.
  void kgPriceAddedOnEdit() {
    unawaited(_analytics.logEvent(AnalyticsEvents.tripKgPriceAddedOnEdit));
  }

  /// … puis le retire (le trajet reste aux seuls prix par article).
  void kgPriceRemovedOnEdit() {
    unawaited(_analytics.logEvent(AnalyticsEvents.tripKgPriceRemovedOnEdit));
  }

  /// Ouverture de l'éditeur des prix par article.
  void itemPricesOpened(TripItemPricesSource source) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripItemPricesOpened,
        properties: {
          'source': source.wire,
          'suggested_items_count': state.items.length,
        },
      ),
    );
  }
}

/// Tranche du nombre de trajets derrière une médiane (jamais le compte exact).
String sampleSizeBracket(int size) {
  if (size <= 0) return '0';
  if (size < 3) return '1-2';
  if (size < 10) return '3-9';
  if (size < 50) return '10-49';
  return '50+';
}

/// Prix pratiqués sur la route, prêts à remplir une grille vide.
///
/// La grille est tenue dans la devise active du voyageur : des prix de route
/// dans une autre devise y seraient faux, on n'en propose alors aucun. Chaque
/// montant est ramené dans les bornes d'un article de grille.
List<PriceGridSuggestion> gridSuggestionsFrom(
  TripPriceSuggestionState suggestion,
) {
  final gridCurrency = ActiveCurrency.current ?? SupportedCurrency.eur;
  if (suggestion.currency != gridCurrency) return const [];
  final min = minGridItemPriceFor(gridCurrency);
  final max = maxUnitPriceFor(gridCurrency);
  return [
    for (final item in suggestion.items)
      PriceGridSuggestion(
        label: item.label,
        unitPriceNet: item.unitPrice.clamp(min, max).toDouble(),
      ),
  ];
}
