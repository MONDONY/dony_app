import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AmendmentRequestStatus {
  /// Options en cours de chargement.
  loading,

  /// Options introuvables (réseau) : la feuille propose de réessayer.
  loadFailed,
  editing,

  /// Devis du total en cours (après un changement de kilos ou d'articles).
  quoting,

  /// Vérification locale ouverte ou création en cours.
  submitting,

  /// Carte : demande créée, le montant attend d'être autorisé par la feuille
  /// de paiement ([AmendmentRequestState.checkout]).
  readyToAuthorize,

  /// Carte : autorisation faite, confirmation serveur en cours.
  confirming,
  sent,

  /// La modification n'est plus possible pour ce colis : la feuille se ferme.
  closed,

  /// Échec qui laisse le formulaire ouvert.
  failure,
}

class AmendmentRequestState extends Equatable {
  const AmendmentRequestState({
    this.status = AmendmentRequestStatus.loading,
    this.options,
    this.addedKg = 0,
    this.addedVolumeM3 = 0,
    this.items = const {},
    this.method,
    this.grossQuote,
    this.checkout,
    this.error,
  });

  final AmendmentRequestStatus status;
  final AmendmentOptions? options;
  final double addedKg;

  /// Volume ajouté en m³ (colis d'un trajet bateau au m³), à la place des kilos.
  final double addedVolumeM3;

  /// Quantité par identifiant d'article de grille (quantités > 0 seulement).
  final Map<String, int> items;
  final BidPaymentMethod? method;

  /// Total à payer en plus, calculé par le serveur.
  final double? grossQuote;
  final AmendmentCheckout? checkout;
  final AppException? error;

  bool get hasContent => addedKg > 0 || addedVolumeM3 > 0 || items.isNotEmpty;

  /// Quelque chose est ajouté, le devis du serveur est là et un moyen de
  /// paiement est choisi.
  bool get canSubmit =>
      (status == AmendmentRequestStatus.editing ||
          status == AmendmentRequestStatus.failure) &&
      hasContent &&
      grossQuote != null &&
      method != null;

  /// Une vérification, une création ou une confirmation est en cours : la
  /// feuille ne se ferme pas, le bouton est désactivé.
  bool get isBusy =>
      status == AmendmentRequestStatus.submitting ||
      status == AmendmentRequestStatus.readyToAuthorize ||
      status == AmendmentRequestStatus.confirming;

  AmendmentRequestState copyWith({
    AmendmentRequestStatus? status,
    AmendmentOptions? options,
    double? addedKg,
    double? addedVolumeM3,
    Map<String, int>? items,
    BidPaymentMethod? method,
    double? Function()? grossQuote,
    AmendmentCheckout? Function()? checkout,
    AppException? Function()? error,
  }) => AmendmentRequestState(
    status: status ?? this.status,
    options: options ?? this.options,
    addedKg: addedKg ?? this.addedKg,
    addedVolumeM3: addedVolumeM3 ?? this.addedVolumeM3,
    items: items ?? this.items,
    method: method ?? this.method,
    grossQuote: grossQuote != null ? grossQuote() : this.grossQuote,
    checkout: checkout != null ? checkout() : this.checkout,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [
    status,
    options,
    addedKg,
    addedVolumeM3,
    items,
    method,
    grossQuote,
    checkout,
    error,
  ];
}

/// Codes qui rendent la modification impossible pour ce colis : réessayer
/// depuis la même feuille échouerait à l'identique.
const _closingCodes = {
  'amendment-disabled',
  'amendment-not-eligible',
  'amendment-already-open',
  'amendment-limit-reached',
  'amendment-rail-unavailable',
  'amendment-expired',
  'amendment-not-found',
  'bid-not-found',
  'forbidden',
};

/// Feuille « Modifier mon colis » de l'expéditeur : kilos et articles de
/// grille ajoutés à un colis accepté, payés sur un moyen au choix.
///
/// Le total vient toujours du serveur (devis après un délai de saisie) : rien
/// n'est additionné ici. Espèces et mobile money : [submit] crée la demande
/// (rien n'est débité). Carte : l'écran pose [beginAuthorization], passe
/// `requirePaymentAuth`, puis appelle [submit] (ou [authorizationDenied]) ;
/// [AmendmentRequestStatus.readyToAuthorize] ouvre la feuille de paiement qui
/// bloque le montant, puis [cardAuthorized] confirme (ou
/// [authorizationAbandoned] annule la demande si la feuille est fermée).
/// Le paiement lui-même (`payment_*`, `context: bid_amendment`) est tracé par
/// la feuille de paiement, jamais ici.
class AmendmentRequestCubit extends Cubit<AmendmentRequestState> {
  AmendmentRequestCubit(
    this._repository,
    this._analytics, {
    this.quoteDebounce = const Duration(milliseconds: 400),
  }) : super(const AmendmentRequestState());

  final BidAmendmentRepository _repository;
  final AnalyticsService _analytics;
  final Duration quoteDebounce;

  String? _bidId;

  /// Colis d'un trajet bateau au m³ : le volume part à la place des kilos.
  bool _perM3 = false;
  Timer? _quoteTimer;

  /// Numéro du dernier devis demandé : une réponse périmée est ignorée.
  int _quoteSeq = 0;

  /// Vérification locale ouverte : [submit] est alors attendu.
  bool _authorizing = false;

  Future<void> load(BidModel bid) async {
    _bidId = bid.id;
    _perM3 = bid.isPricedPerM3;
    if (state.status != AmendmentRequestStatus.loading) {
      emit(const AmendmentRequestState());
    }
    try {
      final options = await _repository.options(bid.id);
      if (isClosed) return;
      emit(
        AmendmentRequestState(
          status: AmendmentRequestStatus.editing,
          options: options,
          method: options.paymentMethods.isEmpty
              ? null
              : options.paymentMethods.first,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidAmendmentSheetOpened,
          properties: {
            'rails_count': options.paymentMethods.length,
            'price_unit': ?_priceUnit,
          },
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        AmendmentRequestState(
          status: AmendmentRequestStatus.loadFailed,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  /// Kilos en plus : bornés à `[0, kilos libres]`, par pas de 0,5.
  void setKg(double kg) {
    final max = _maxKg();
    var value = (kg * 2).round() / 2;
    if (max != null && value > max) value = (max * 2).floor() / 2;
    if (value < 0) value = 0;
    _changed(addedKg: value);
  }

  /// Volume en plus (colis au m³) : par pas de 0,1 m³, borné à
  /// `[0, volume libre]`. Sans effet sur un colis au kilo.
  void setVolume(double m3) {
    if (!_perM3) return;
    final max = _maxVolume();
    var value = _tenth(m3);
    if (max != null && value > max) value = (max * 10).floor() / 10;
    if (value < 0) value = 0;
    _changed(addedVolumeM3: value);
  }

  /// Dixième de m³ le plus proche ; la marge absorbe la dérive des flottants
  /// (`0.1 * 3` vaut 0,30000000000000004).
  static double _tenth(double m3) => (m3 * 10 + 1e-9).round() / 10;

  void setItemQuantity(String id, int quantity) {
    final unit = state.options?.gridItems
        .where((g) => g.id == id)
        .map((g) => g.unitPriceDisplay)
        .firstOrNull;
    final max = state.options?.maxAmount;
    if (unit != null && unit > 0 && max != null && quantity > max ~/ unit) {
      quantity = max ~/ unit;
    }
    final items = Map<String, int>.from(state.items);
    if (quantity > 0) {
      items[id] = quantity;
    } else {
      items.remove(id);
    }
    _changed(items: items);
  }

  void selectMethod(BidPaymentMethod method) {
    // Montant déjà bloqué : le formulaire ne change plus.
    if (state.isBusy || state.checkout != null) return;
    emit(state.copyWith(method: method));
  }

  /// Plafond d'affichage des kilos : kilos libres, sinon le plafond du net
  /// divisé par le prix au kilo (le serveur reste l'autorité).
  double? _maxKg() {
    final options = state.options;
    if (options == null) return null;
    if (options.availableKg != null) return options.availableKg;
    final price = options.pricePerKgDisplay;
    if (price == null || price <= 0) return null;
    return options.maxAmount / price;
  }

  /// Plafond d'affichage du volume : volume libre du trajet, sinon le plafond
  /// du net divisé par le prix au m³ (le serveur reste l'autorité).
  double? _maxVolume() {
    final options = state.options;
    if (options == null) return null;
    final free = options.availableVolumeM3;
    if (free != null) return (free * 10 + 1e-9).floor() / 10;
    final price = options.pricePerM3Display;
    if (price == null || price <= 0) return null;
    return options.maxAmount / price;
  }

  void _changed({
    double? addedKg,
    double? addedVolumeM3,
    Map<String, int>? items,
  }) {
    if (state.options == null || state.isBusy || state.checkout != null) {
      return;
    }
    final next = state.copyWith(
      addedKg: addedKg,
      addedVolumeM3: addedVolumeM3,
      items: items,
      grossQuote: () => null,
      error: () => null,
    );
    _quoteTimer?.cancel();
    final seq = ++_quoteSeq;
    if (!next.hasContent) {
      emit(next.copyWith(status: AmendmentRequestStatus.editing));
      return;
    }
    emit(next.copyWith(status: AmendmentRequestStatus.quoting));
    _quoteTimer = Timer(quoteDebounce, () => unawaited(_quote(seq)));
  }

  Future<void> _quote(int seq) async {
    final bidId = _bidId;
    if (bidId == null) return;
    try {
      final gross = await _repository.quote(
        bidId,
        addedKg: state.addedKg,
        addedVolumeM3: _perM3 ? state.addedVolumeM3 : null,
        items: state.items,
      );
      if (isClosed || seq != _quoteSeq) return;
      emit(
        state.copyWith(
          status: AmendmentRequestStatus.editing,
          grossQuote: () => gross,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _quoteSeq) return;
      final error = unwrapDioError(e);
      emit(
        state.copyWith(
          status: AmendmentRequestStatus.failure,
          error: () => error,
        ),
      );
      _logRequestFailed(error.code);
    }
  }

  /// Carte : verrouille le bouton pendant la vérification locale. Faux si
  /// rien n'est prêt à être envoyé ou si une action est déjà en cours.
  bool beginAuthorization() {
    if (!state.canSubmit) return false;
    _authorizing = true;
    emit(state.copyWith(status: AmendmentRequestStatus.submitting));
    return true;
  }

  /// Vérification locale refusée : rien n'est parti, le formulaire revient.
  void authorizationDenied() {
    _authorizing = false;
    if (state.status != AmendmentRequestStatus.submitting) return;
    emit(state.copyWith(status: AmendmentRequestStatus.editing));
  }

  Future<void> submit() async {
    // Carte : le montant est déjà bloqué (la confirmation a échoué). On
    // reconfirme la demande existante, on n'en crée jamais une seconde.
    if (state.checkout != null &&
        state.status == AmendmentRequestStatus.failure) {
      await cardAuthorized();
      return;
    }
    final bidId = _bidId;
    final method = state.method;
    final fromAuthorization = _authorizing;
    _authorizing = false;
    if (bidId == null || method == null) return;
    if (!fromAuthorization && !state.canSubmit) return;
    emit(
      state.copyWith(
        status: AmendmentRequestStatus.submitting,
        error: () => null,
      ),
    );
    try {
      final checkout = await _repository.create(
        bidId,
        addedKg: state.addedKg,
        addedVolumeM3: _perM3 ? state.addedVolumeM3 : null,
        items: state.items,
        method: method,
      );
      if (isClosed) return;
      if (checkout.needsPaymentSheet) {
        emit(
          state.copyWith(
            status: AmendmentRequestStatus.readyToAuthorize,
            checkout: () => checkout,
          ),
        );
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.bidAmendmentPaymentStarted,
            properties: {'method': _analyticsMethod(method)},
          ),
        );
        return;
      }
      emit(state.copyWith(status: AmendmentRequestStatus.sent));
      _logRequested(method);
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      final code = error.code ?? 'unknown';
      emit(
        state.copyWith(
          status: _closingCodes.contains(code)
              ? AmendmentRequestStatus.closed
              : AmendmentRequestStatus.failure,
          error: () => error,
        ),
      );
      _logRequestFailed(code);
    }
  }

  /// Carte : le montant est bloqué par la feuille de paiement, le serveur le
  /// vérifie et présente la demande au voyageur.
  Future<void> cardAuthorized() async {
    final bidId = _bidId;
    final amendment = state.checkout?.amendment;
    if (bidId == null || amendment == null) return;
    emit(state.copyWith(status: AmendmentRequestStatus.confirming));
    try {
      await _repository.confirmAuthorization(bidId, amendment.id);
      if (isClosed) return;
      emit(state.copyWith(status: AmendmentRequestStatus.sent));
      _logRequested(state.method ?? BidPaymentMethod.stripe);
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(
        state.copyWith(
          status: AmendmentRequestStatus.failure,
          error: () => error,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidAmendmentActionFailed,
          properties: {
            'action': 'confirm_authorization',
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
    }
  }

  /// Carte : feuille de paiement fermée sans bloquer le montant. La demande
  /// créée est annulée (sans quoi elle bloquerait la remise jusqu'à son
  /// expiration) et le formulaire revient.
  Future<void> authorizationAbandoned() async {
    final bidId = _bidId;
    final amendment = state.checkout?.amendment;
    if (state.status != AmendmentRequestStatus.readyToAuthorize) return;
    emit(
      state.copyWith(
        status: AmendmentRequestStatus.editing,
        checkout: () => null,
      ),
    );
    if (bidId == null || amendment == null) return;
    try {
      await _repository.cancel(bidId, amendment.id);
    } catch (_) {
      // Le serveur expire l'autorisation non confirmée : rien à montrer.
    }
  }

  void _logRequested(BidPaymentMethod method) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidAmendmentRequested,
        properties: {
          'method': _analyticsMethod(method),
          'added_kg': state.addedKg,
          if (_perM3) 'added_m3': state.addedVolumeM3,
          'price_unit': ?_priceUnit,
          'items_count': state.items.length,
          'amount_bracket': analyticsAmountBracket(state.grossQuote ?? 0),
          'currency': state.options?.currency ?? 'EUR',
        },
      ),
    );
  }

  void _logRequestFailed(String? code) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidAmendmentRequestFailed,
        properties: {'error_code': code ?? 'unknown'},
      ),
    );
  }

  /// `m3` pour un colis au m³ ; rien pour un colis au kilo (propriétés
  /// historiques inchangées).
  String? get _priceUnit => _perM3 ? 'm3' : null;

  static String _analyticsMethod(BidPaymentMethod method) => switch (method) {
    BidPaymentMethod.stripe => AnalyticsPaymentMethod.card,
    BidPaymentMethod.cash => AnalyticsPaymentMethod.cash,
    _ => AnalyticsPaymentMethod.mobileMoney,
  };

  @override
  Future<void> close() {
    _quoteTimer?.cancel();
    return super.close();
  }
}
