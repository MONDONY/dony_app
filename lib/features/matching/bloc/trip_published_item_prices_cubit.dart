import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ce que montre la carte « Prix par article » de l'écran de succès d'un
/// trajet tout juste publié.
enum PublishedItemPricesStatus {
  /// Grille du profil ou prix de la route en cours de lecture : rien
  /// d'affiché.
  checking,

  /// Le trajet publié porte des prix par article : ils sont montrés en
  /// pastilles, sans proposition.
  filled,

  /// Grille vide, prix pratiqués sur la route connus : « Modifier » /
  /// « Ajouter ».
  proposal,

  /// Grille vide, aucun prix de route (back ancien, hors ligne, devise de la
  /// grille différente de celle du trajet) : seul « Ajouter mes prix ».
  empty,

  /// Ajout des prix proposés en cours.
  adding,

  /// Prix ajoutés à la grille du profil (par « Ajouter » ou depuis
  /// l'éditeur).
  added,

  /// Rien à montrer : grille illisible, ou grille déjà remplie alors que le
  /// trajet publié n'en porte pas (on ne montre pas comme prix du trajet des
  /// prix qui n'y sont pas).
  hidden,
}

class TripPublishedItemPricesState extends Equatable {
  const TripPublishedItemPricesState({
    this.status = PublishedItemPricesStatus.checking,
    this.items = const [],
    this.suggestions = const [],
    this.addedCount = 0,
    this.addFailed = false,
  });

  final PublishedItemPricesStatus status;

  /// Prix par article figés sur le trajet publié (devise du trajet).
  final List<GridPreviewItem> items;

  /// Prix pratiqués sur la route, proposés pour une grille vide (2 à 4).
  final List<PriceGridSuggestion> suggestions;

  /// Articles présents dans la grille après l'ajout.
  final int addedCount;

  /// Le dernier « Ajouter » a échoué : la proposition reste, avec un message.
  final bool addFailed;

  TripPublishedItemPricesState copyWith({
    PublishedItemPricesStatus? status,
    List<GridPreviewItem>? items,
    List<PriceGridSuggestion>? suggestions,
    int? addedCount,
    bool? addFailed,
  }) => TripPublishedItemPricesState(
    status: status ?? this.status,
    items: items ?? this.items,
    suggestions: suggestions ?? this.suggestions,
    addedCount: addedCount ?? this.addedCount,
    addFailed: addFailed ?? this.addFailed,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    suggestions,
    addedCount,
    addFailed,
  ];
}

/// Carte « Prix par article » de l'écran de succès d'un trajet publié.
///
/// La grille du profil est figée sur le trajet à la publication (copie
/// serveur `snapshotToAnnouncement`, seulement en `MIXED`) : des prix ajoutés
/// ensuite valent pour les trajets suivants, jamais pour celui qui vient
/// d'être publié. La lecture de la grille et l'ajout passent par
/// `PriceGridBloc` (l'écran relaie ses états par [gridLoaded] et
/// [gridFailed]) ; ce cubit ne tient que l'état de la carte et ses
/// analytics.
class TripPublishedItemPricesCubit extends Cubit<TripPublishedItemPricesState> {
  TripPublishedItemPricesCubit(this._repository, this._analytics)
    : super(const TripPublishedItemPricesState());

  final PriceSuggestionRepository _repository;
  final AnalyticsService _analytics;

  /// Nombre maximal de prix proposés sur la carte.
  static const maxSuggestions = 4;

  /// Prix de la route, `null` tant qu'ils ne sont pas connus.
  List<PriceGridSuggestion>? _suggestions;

  /// La grille du profil est vide, `null` tant qu'elle n'est pas lue.
  bool? _gridEmpty;

  /// Retour de l'éditeur : la grille relue décide de l'état suivant.
  bool _recheckingAfterEdit = false;

  /// [publishedItems] : prix par article du trajet publié. Non vide, la
  /// carte les montre et rien d'autre n'est lu. Sinon la grille du profil
  /// doit être relayée par [gridLoaded], et les prix de la route viennent de
  /// [routeSuggestion] (ceux que l'étape prix a déjà chargés) ou sont
  /// redemandés pour [departureCity] → [arrivalCity] dans [currency].
  Future<void> start({
    required List<GridPreviewItem> publishedItems,
    required String departureCity,
    required String arrivalCity,
    required SupportedCurrency currency,
    TripPriceSuggestionState? routeSuggestion,
  }) async {
    if (publishedItems.isNotEmpty) {
      emit(
        state.copyWith(
          status: PublishedItemPricesStatus.filled,
          items: publishedItems,
        ),
      );
      _logShown('filled', 0);
      return;
    }
    final known =
        routeSuggestion != null &&
        routeSuggestion.status == TripPriceSuggestionStatus.loaded &&
        routeSuggestion.currency == currency;
    if (known) {
      _suggestions = _limit(gridSuggestionsFrom(routeSuggestion));
    } else {
      final response = await _repository.getSuggestions(
        departureCity: departureCity,
        arrivalCity: arrivalCity,
        currency: currency.code,
      );
      if (isClosed) return;
      _suggestions = _limit(
        gridSuggestionsFrom(
          TripPriceSuggestionState(
            status: TripPriceSuggestionStatus.loaded,
            currency: currency,
            suggestion: response,
          ),
        ),
      );
    }
    _resolve();
  }

  List<PriceGridSuggestion> _limit(List<PriceGridSuggestion> list) =>
      list.take(maxSuggestions).toList();

  /// Grille du profil lue (premier chargement, après l'ajout, ou au retour
  /// de l'éditeur).
  void gridLoaded(int itemCount) {
    switch (state.status) {
      case PublishedItemPricesStatus.checking:
        _gridEmpty = itemCount == 0;
        _resolve();
      case PublishedItemPricesStatus.adding:
        emit(
          state.copyWith(
            status: PublishedItemPricesStatus.added,
            addedCount: itemCount,
            addFailed: false,
          ),
        );
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.tripPublishedItemPricesAdded,
            properties: {'count': itemCount},
          ),
        );
      case PublishedItemPricesStatus.proposal ||
              PublishedItemPricesStatus.empty ||
              PublishedItemPricesStatus.added
          when _recheckingAfterEdit:
        _recheckingAfterEdit = false;
        if (itemCount > 0) {
          emit(
            state.copyWith(
              status: PublishedItemPricesStatus.added,
              addedCount: itemCount,
              addFailed: false,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: state.suggestions.isEmpty
                  ? PublishedItemPricesStatus.empty
                  : PublishedItemPricesStatus.proposal,
              addedCount: 0,
            ),
          );
        }
      default:
        break;
    }
  }

  /// Lecture ou ajout refusé par le serveur (ou hors ligne).
  void gridFailed(Object error) {
    switch (state.status) {
      case PublishedItemPricesStatus.checking:
        emit(state.copyWith(status: PublishedItemPricesStatus.hidden));
      case PublishedItemPricesStatus.adding:
        emit(
          state.copyWith(
            status: PublishedItemPricesStatus.proposal,
            addFailed: true,
          ),
        );
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.tripPublishedItemPricesAddFailed,
            properties: {
              'error_code': error is AppException
                  ? (error.code ?? 'unknown')
                  : 'unknown',
            },
          ),
        );
      default:
        _recheckingAfterEdit = false;
    }
  }

  /// « Ajouter » : rend les prix à ajouter (l'écran les confie à
  /// `PriceGridBloc`), `null` hors proposition.
  List<PriceGridSuggestion>? addRequested() {
    if (state.status != PublishedItemPricesStatus.proposal) return null;
    emit(
      state.copyWith(
        status: PublishedItemPricesStatus.adding,
        addFailed: false,
      ),
    );
    return state.suggestions;
  }

  /// « Modifier », « Ajouter mes prix » ou « Voir mes prix » : l'éditeur
  /// s'ouvre. Rend les prix à préremplir (vide hors proposition).
  List<PriceGridSuggestion> editOpened() {
    unawaited(
      _analytics.logEvent(AnalyticsEvents.tripPublishedItemPricesEditOpened),
    );
    _recheckingAfterEdit = true;
    return state.status == PublishedItemPricesStatus.proposal
        ? state.suggestions
        : const [];
  }

  void _resolve() {
    final suggestions = _suggestions;
    final gridEmpty = _gridEmpty;
    if (suggestions == null || gridEmpty == null) return;
    if (state.status != PublishedItemPricesStatus.checking) return;
    if (!gridEmpty) {
      emit(state.copyWith(status: PublishedItemPricesStatus.hidden));
      return;
    }
    if (suggestions.isEmpty) {
      emit(state.copyWith(status: PublishedItemPricesStatus.empty));
      _logShown('none', 0);
      return;
    }
    emit(
      state.copyWith(
        status: PublishedItemPricesStatus.proposal,
        suggestions: suggestions,
      ),
    );
    _logShown('proposal', suggestions.length);
  }

  void _logShown(String variant, int count) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripPublishedItemPricesShown,
        properties: {'variant': variant, 'suggestions_count': count},
      ),
    );
  }
}
