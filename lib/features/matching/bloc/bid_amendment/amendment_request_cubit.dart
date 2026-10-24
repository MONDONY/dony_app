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
    this.items = const {},
    this.method,
    this.grossQuote,
    this.checkout,
    this.error,
  });

  final AmendmentRequestStatus status;
  final AmendmentOptions? options;
  final double addedKg;

  /// Quantité par identifiant d'article de grille (quantités > 0 seulement).
  final Map<String, int> items;
  final BidPaymentMethod? method;

  /// Total à payer en plus, calculé par le serveur.
  final double? grossQuote;
  final AmendmentCheckout? checkout;
  final AppException? error;

  bool get hasContent => addedKg > 0 || items.isNotEmpty;

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
    Map<String, int>? items,
    BidPaymentMethod? method,
    double? Function()? grossQuote,
    AmendmentCheckout? Function()? checkout,
    AppException? Function()? error,
  }) => AmendmentRequestState(
    status: status ?? this.status,
    options: options ?? this.options,
    addedKg: addedKg ?? this.addedKg,
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
  Timer? _quoteTimer;

  /// Numéro du dernier devis demandé : une réponse périmée est ignorée.
  int _quoteSeq = 0;

  /// Vérification locale ouverte : [submit] est alors attendu.
  bool _authorizing = false;

  Future<void> load(BidModel bid) async {
    _bidId = bid.id;
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
          properties: {'rails_count': options.paymentMethods.length},
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
    final max = state.options?.availableKg;
    var value = (kg * 2).round() / 2;
    if (max != null && value > max) value = (max * 2).floor() / 2;
    if (value < 0) value = 0;
    _changed(addedKg: value);
  }

  void setItemQuantity(String id, int quantity) {
    final items = Map<String, int>.from(state.items);
    if (quantity > 0) {
      items[id] = quantity;
    } else {
      items.remove(id);
    }
    _changed(items: items);
  }

  void selectMethod(BidPaymentMethod method) {
    if (state.isBusy) return;
    emit(state.copyWith(method: method));
  }

  void _changed({double? addedKg, Map<String, int>? items}) {
    if (state.options == null || state.isBusy) return;
    final next = state.copyWith(
      addedKg: addedKg,
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
