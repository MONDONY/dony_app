import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/supplement_commission_unfunded.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Longueur maximale du détail, alignée sur le serveur
/// (`CreateSupplementRequest.reasonText`, `@Size(max = 500)`).
const int kSupplementReasonTextMaxLength = 500;

enum SupplementRequestStatus {
  /// Options en cours de chargement.
  loading,

  /// Options introuvables (réseau, colis sorti de la fenêtre) : la feuille
  /// propose de réessayer.
  loadFailed,
  editing,

  /// Espèces : vérification locale (`requirePaymentAuth`) ouverte avant un
  /// appel qui prélève la commission. Le bouton est désactivé.
  authorizing,
  submitting,
  success,

  /// La demande n'est plus possible (départ trop proche, demande déjà en
  /// cours, plafond atteint, statut changé) : la feuille se ferme et le colis
  /// est relu.
  closed,

  /// Échec qui laisse le formulaire ouvert (réseau, montant hors bornes).
  failure,

  /// Photo illisible : rien n'a changé dans le formulaire.
  photoFailed,

  /// Espèces : le solde ne couvre pas la commission du supplément (422
  /// `supplement-commission-unfunded`). Rien n'a été créé : la feuille
  /// propose la carte, un autre portefeuille ou la recharge.
  unfunded,

  /// Espèces : aucune carte commission enregistrée (422
  /// `commission-method-missing`). Rien n'a été créé.
  cardMissing,

  /// Espèces : la demande existe mais sa commission n'est pas encore
  /// prélevée (3DS abandonnée, débit sans réponse 502/503). « Réessayer »
  /// appelle `…/commission/confirm`, jamais un nouveau `POST`.
  commissionRetry,
}

class SupplementRequestState {
  const SupplementRequestState({
    this.status = SupplementRequestStatus.loading,
    this.options,
    this.amount,
    this.suggestion,
    this.reason,
    this.reasonText = '',
    this.photoPath,
    this.photoKey,
    this.quote,
    this.created,
    this.error,
    this.isCash = false,
    this.commissionSource = SupplementCommissionSource.wallet,
    this.fundingCurrency,
    this.unfunded,
    this.awaitingCommission = false,
    this.pending,
  });

  final SupplementRequestStatus status;
  final SupplementOptions? options;

  /// Net demandé, lu dans le champ montant. Nul si le champ est vide ou
  /// illisible.
  final double? amount;

  /// Suggestion choisie (puce), tant que le montant n'a pas été modifié à la
  /// main.
  final SupplementSuggestion? suggestion;
  final BidSupplementReason? reason;
  final String reasonText;

  /// Photo locale du colis, obligatoire : preuve de l'écart pour
  /// l'expéditeur.
  final String? photoPath;

  /// Clé de la photo une fois envoyée : un nouvel essai ne la renvoie pas.
  final String? photoKey;

  /// Devis du montant saisi (net, commission, total expéditeur).
  final SupplementQuote? quote;

  /// Demande créée par le serveur ([SupplementRequestStatus.success]).
  final BidSupplement? created;
  final AppException? error;

  /// Colis payé en espèces : la commission du supplément est prélevée au
  /// voyageur à la demande ; la feuille propose d'où.
  final bool isCash;

  /// Espèces : solde (défaut) ou carte commission.
  final SupplementCommissionSource commissionSource;

  /// Espèces, solde : autre portefeuille choisi pour compléter la
  /// commission, au taux du jour. `null` : devise active (défaut du back).
  final String? fundingCurrency;

  /// Dernier refus « solde insuffisant » : de quoi proposer les autres
  /// moyens. Effacé quand le montant change.
  final SupplementCommissionUnfunded? unfunded;

  /// La demande est créée mais attend sa commission : le formulaire est figé
  /// et la feuille ne propose plus que « Réessayer ».
  final bool awaitingCommission;

  /// Demande en `COMMISSION_PENDING` connue de l'app (3DS abandonnée).
  /// `null` après un débit sans réponse : « Réessayer » la relit sur la fiche
  /// du colis.
  final BidSupplement? pending;

  bool get isSubmitting => status == SupplementRequestStatus.submitting;

  /// Vérification locale ou appel au serveur en cours.
  bool get isBusy =>
      isSubmitting || status == SupplementRequestStatus.authorizing;

  /// Champs du formulaire figés : envoi en cours ou demande déjà créée.
  bool get isLocked => isBusy || awaitingCommission;

  /// Montant saisi dans les bornes du serveur.
  bool get amountInRange {
    final o = options;
    final a = amount;
    return o != null && a != null && a >= o.minNet && a <= o.maxNet;
  }

  /// Montant saisi mais hors des bornes : la feuille l'explique sous le champ.
  bool get amountOutOfRange =>
      amount != null && options != null && !amountInRange;

  bool get canSubmit =>
      !isBusy &&
      !awaitingCommission &&
      status != SupplementRequestStatus.loading &&
      status != SupplementRequestStatus.loadFailed &&
      amountInRange &&
      reason != null &&
      photoPath != null &&
      (reason != BidSupplementReason.other || reasonText.trim().isNotEmpty);

  SupplementRequestState copyWith({
    SupplementRequestStatus? status,
    SupplementOptions? options,
    double? Function()? amount,
    SupplementSuggestion? Function()? suggestion,
    BidSupplementReason? reason,
    String? reasonText,
    String? Function()? photoPath,
    String? Function()? photoKey,
    SupplementQuote? Function()? quote,
    BidSupplement? created,
    AppException? error,
    bool? isCash,
    SupplementCommissionSource? commissionSource,
    String? Function()? fundingCurrency,
    SupplementCommissionUnfunded? Function()? unfunded,
    bool? awaitingCommission,
    BidSupplement? Function()? pending,
  }) => SupplementRequestState(
    status: status ?? SupplementRequestStatus.editing,
    options: options ?? this.options,
    amount: amount != null ? amount() : this.amount,
    suggestion: suggestion != null ? suggestion() : this.suggestion,
    reason: reason ?? this.reason,
    reasonText: reasonText ?? this.reasonText,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
    photoKey: photoKey != null ? photoKey() : this.photoKey,
    quote: quote != null ? quote() : this.quote,
    created: created ?? this.created,
    error: error,
    isCash: isCash ?? this.isCash,
    commissionSource: commissionSource ?? this.commissionSource,
    fundingCurrency: fundingCurrency != null
        ? fundingCurrency()
        : this.fundingCurrency,
    unfunded: unfunded != null ? unfunded() : this.unfunded,
    awaitingCommission: awaitingCommission ?? this.awaitingCommission,
    pending: pending != null ? pending() : this.pending,
  );
}

/// Codes qui rendent la demande impossible pour ce colis : réessayer depuis
/// la même feuille échouerait à l'identique.
const _closingCodes = {
  'supplement-disabled',
  'invalid-bid-status',
  'supplement-rail-unsupported',
  'supplement-limit-reached',
  'supplement-locked',
  'supplement-already-active',
  'bid-not-found',
  'forbidden',
  // Espèces : carte commission refusée, la demande est annulée côté serveur.
  _cardDeclined,
};

const _cardDeclined = 'supplement-commission-card-declined';
const _cardMissing = 'commission-method-missing';
const _fundingCurrencyInvalid = 'funding-currency-invalid';
const _authInterruptedCode = 'commission/3ds-interrupted';

/// Feuille « Demander un supplément » du voyageur : montant (suggestion de la
/// grille ou du kilo, ou saisi), motif, détail, photo obligatoire, devis
/// rafraîchi pendant la saisie, puis envoi (`POST /bids/{bidId}/supplements`).
/// Le serveur fige la commission et prévient l'expéditeur.
///
/// Colis payé en espèces (PR A4) : la commission du supplément est prélevée
/// au voyageur à la demande, depuis son solde ([SupplementCommissionSource.wallet],
/// éventuellement complété par un autre portefeuille) ou sa carte commission
/// (3DS possible, [SupplementCommissionFlow]). L'écran passe
/// `requirePaymentAuth` avant [submit] et [retryCommission]
/// ([beginAuthorization] / [authorizationDenied]).
class SupplementRequestCubit extends Cubit<SupplementRequestState> {
  SupplementRequestCubit(
    this._repository,
    this._media,
    this._analytics, {
    this.quoteDebounce = const Duration(milliseconds: 400),
    SupplementCommissionFlow? commissionFlow,
  }) : _flow =
           commissionFlow ?? SupplementCommissionFlow(_repository, _analytics),
       super(const SupplementRequestState());

  final BidSupplementRepository _repository;
  final DonyMediaService _media;
  final AnalyticsService _analytics;
  final SupplementCommissionFlow _flow;

  /// Statut à rendre quand la vérification locale est refusée.
  SupplementRequestStatus _beforeAuth = SupplementRequestStatus.editing;

  /// Attente après la dernière frappe avant de demander le devis.
  final Duration quoteDebounce;

  BidModel? _bid;
  Timer? _quoteTimer;
  int _quoteSeq = 0;

  Future<void> load(BidModel bid) async {
    _bid = bid;
    emit(state.copyWith(status: SupplementRequestStatus.loading));
    try {
      final options = await _repository.options(bid.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          options: options,
          isCash:
              bid.paymentMethod == BidPaymentMethod.cash ||
              options.rail == SupplementCheckout.railCash,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidSupplementSheetOpened,
          properties: {
            'payment_method': bid.paymentMethod.name,
            'status': bid.status,
          },
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SupplementRequestStatus.loadFailed,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  /// Puce de suggestion : fixe le montant et le motif (article de la grille
  /// ou poids en plus). Le champ montant est mis à jour par la feuille.
  void selectSuggestion(SupplementSuggestion suggestion) {
    emit(
      state.copyWith(
        status: _editingStatus,
        suggestion: () => suggestion,
        amount: () => suggestion.unitNet,
        reason: suggestion.isGridItem
            ? BidSupplementReason.gridItem
            : BidSupplementReason.extraWeight,
        quote: () => null,
      ),
    );
    _scheduleQuote();
  }

  /// Montant saisi à la main. Un montant différent de la suggestion choisie
  /// la désélectionne (le motif reste).
  void amountChanged(String text) {
    final amount = parseSupplementAmount(text);
    if (amount == state.amount) return;
    final keepSuggestion = state.suggestion?.unitNet == amount;
    emit(
      state.copyWith(
        status: _editingStatus,
        amount: () => amount,
        suggestion: keepSuggestion ? null : () => null,
        quote: () => null,
        unfunded: () => null,
        fundingCurrency: () => null,
      ),
    );
    _scheduleQuote();
  }

  /// Espèces : d'où prélever la commission. [fundingCurrency] choisit un
  /// autre portefeuille pour compléter le solde (proposé après un « solde
  /// insuffisant »), ignoré pour la carte.
  void selectCommissionSource(
    SupplementCommissionSource source, {
    String? fundingCurrency,
  }) {
    if (state.isLocked) return;
    emit(
      state.copyWith(
        status: _editingStatus,
        commissionSource: source,
        fundingCurrency: () => source == SupplementCommissionSource.wallet
            ? fundingCurrency
            : null,
      ),
    );
  }

  /// Ouvre la vérification locale avant un appel qui prélève la commission.
  /// Rend `false` si un envoi est déjà en cours (double tap) : l'appelant
  /// n'ouvre alors pas d'invite.
  bool beginAuthorization() {
    if (isClosed || state.isBusy) return false;
    _beforeAuth = state.status;
    emit(
      state.copyWith(
        status: SupplementRequestStatus.authorizing,
        error: state.error,
      ),
    );
    return true;
  }

  /// Vérification refusée ou abandonnée : la feuille revient où elle était.
  void authorizationDenied() {
    if (isClosed || state.status != SupplementRequestStatus.authorizing) {
      return;
    }
    emit(state.copyWith(status: _beforeAuth, error: state.error));
  }

  void selectReason(BidSupplementReason reason) =>
      emit(state.copyWith(status: _editingStatus, reason: reason));

  void reasonTextChanged(String text) =>
      emit(state.copyWith(status: _editingStatus, reasonText: text));

  Future<void> takePhoto() async {
    if (state.isSubmitting) return;
    try {
      final file = await _media.pick(source: ImageSource.camera);
      if (file == null || isClosed) return;
      emit(
        state.copyWith(
          status: _editingStatus,
          photoPath: () => file.path,
          photoKey: () => null,
        ),
      );
    } catch (e) {
      AppLog.warn('Unreadable supplement photo: $e');
      if (isClosed) return;
      emit(state.copyWith(status: SupplementRequestStatus.photoFailed));
    }
  }

  void removePhoto() => emit(
    state.copyWith(
      status: _editingStatus,
      photoPath: () => null,
      photoKey: () => null,
    ),
  );

  /// Statut à garder pendant une saisie : un chargement raté et un refus
  /// « solde insuffisant » ou « carte manquante » restent visibles.
  SupplementRequestStatus get _editingStatus => switch (state.status) {
    SupplementRequestStatus.loadFailed ||
    SupplementRequestStatus.unfunded ||
    SupplementRequestStatus.cardMissing => state.status,
    _ => SupplementRequestStatus.editing,
  };

  void _scheduleQuote() {
    _quoteTimer?.cancel();
    final seq = ++_quoteSeq;
    if (!state.amountInRange) return;
    _quoteTimer = Timer(quoteDebounce, () => unawaited(_quote(seq)));
  }

  Future<void> _quote(int seq) async {
    final bid = _bid;
    final amount = state.amount;
    if (bid == null || amount == null || isClosed) return;
    try {
      final quote = await _repository.quote(bid.id, amount);
      // Une frappe plus récente a demandé un autre devis.
      if (isClosed || seq != _quoteSeq) return;
      emit(state.copyWith(status: state.status, quote: () => quote));
    } catch (e) {
      // Le devis n'est qu'un aperçu : le serveur recalcule tout à l'envoi.
      AppLog.warn('Supplement quote failed: $e');
    }
  }

  Future<void> submit() async {
    final bid = _bid;
    if (bid == null) return;
    // Espèces : l'écran a ouvert la vérification locale juste avant.
    final authorized = state.status == SupplementRequestStatus.authorizing;
    final ready = authorized
        ? state.copyWith(status: _beforeAuth, error: state.error).canSubmit
        : state.canSubmit;
    if (!ready) return;
    final reason = state.reason!;
    final suggestion = state.suggestion;
    emit(state.copyWith(status: SupplementRequestStatus.submitting));
    String key;
    try {
      key =
          state.photoKey ??
          await _repository.uploadPhoto(bid.id, state.photoPath!);
    } catch (e) {
      if (isClosed) return;
      _onCreateError(bid, reason, e);
      return;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: SupplementRequestStatus.submitting,
        photoKey: () => key,
      ),
    );
    await _create(bid, reason, suggestion, key);
  }

  /// Espèces : relance la commission d'une demande déjà créée. Une demande
  /// en `COMMISSION_PENDING` passe par `…/commission/confirm` (jamais un
  /// nouveau `POST`, qui rendrait 409 `supplement-already-active`) ; une
  /// demande déjà partie chez l'expéditeur clôt la feuille en succès ; s'il
  /// n'y a aucune demande (le serveur n'avait rien créé), elle est envoyée.
  Future<void> retryCommission() async {
    final bid = _bid;
    if (bid == null || !state.awaitingCommission) return;
    if (state.isSubmitting) return;
    final reason = state.reason!;
    final suggestion = state.suggestion;
    emit(
      state.copyWith(
        status: SupplementRequestStatus.submitting,
        awaitingCommission: true,
      ),
    );
    BidSupplement? target = state.pending;
    try {
      target ??= await _repository.current(bid.id);
      if (isClosed) return;
      if (target == null || !target.status.isOpen) {
        // Rien en attente : le serveur n'avait rien créé (ou l'a clos). La
        // photo est déjà envoyée (la création ne part qu'après elle).
        await _create(bid, reason, suggestion, state.photoKey!);
        return;
      }
      final settled = target.status == BidSupplementStatus.commissionPending
          ? await _flow.resume(bid.id, target.id)
          : target;
      if (isClosed) return;
      _finish(bid, reason, suggestion, settled);
    } on SupplementCommissionAuthInterrupted {
      if (isClosed) return;
      _onAuthInterrupted(reason, target);
    } catch (e) {
      if (isClosed) return;
      _onCommissionError(reason, target, e);
    }
  }

  /// `POST /bids/{bidId}/supplements`, puis, en espèces, la commission
  /// jusqu'à l'expéditeur (3DS et confirmation si la carte le demande).
  Future<void> _create(
    BidModel bid,
    BidSupplementReason reason,
    SupplementSuggestion? suggestion,
    String photoKey,
  ) async {
    final cash = state.isCash;
    final source = state.commissionSource;
    final funding = cash && source == SupplementCommissionSource.wallet
        ? state.fundingCurrency
        : null;
    if (funding != null) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.commissionFundingCurrencyChosen,
          properties: {
            'currency': funding,
            'context': AnalyticsPaymentContext.bidSupplement,
          },
        ),
      );
    }
    final BidSupplement created;
    try {
      created = await _repository.create(
        bid.id,
        netAmount: state.amount!,
        reason: reason,
        reasonText: _clip(state.reasonText),
        gridItemLabel: reason == BidSupplementReason.gridItem
            ? suggestion?.label
            : null,
        photoKey: photoKey,
        commissionSource: cash ? source : null,
        fundingCurrency: funding,
      );
    } catch (e) {
      if (isClosed) return;
      _onCreateError(bid, reason, e);
      return;
    }
    if (isClosed) return;
    if (!created.needsCommissionAuth) {
      _finish(bid, reason, suggestion, created);
      return;
    }
    // Carte commission avec 3DS : la demande existe déjà, une 3DS
    // abandonnée se reprend par « Réessayer ».
    emit(
      state.copyWith(
        status: SupplementRequestStatus.submitting,
        awaitingCommission: true,
        pending: () => created,
      ),
    );
    try {
      final settled = await _flow.settle(bid.id, created);
      if (isClosed) return;
      _finish(bid, reason, suggestion, settled);
    } on SupplementCommissionAuthInterrupted {
      if (isClosed) return;
      _onAuthInterrupted(reason, created);
    } catch (e) {
      if (isClosed) return;
      _onCommissionError(reason, created, e);
    }
  }

  /// La demande est créée : envoyée à l'expéditeur, ou (carte en cours de
  /// traitement chez Stripe) en attente de la commission, que le webhook
  /// tranchera.
  void _finish(
    BidModel bid,
    BidSupplementReason reason,
    SupplementSuggestion? suggestion,
    BidSupplement created,
  ) {
    emit(
      state.copyWith(
        status: SupplementRequestStatus.success,
        created: created,
        awaitingCommission: false,
        pending: () => null,
      ),
    );
    final amount = created.netAmount ?? state.amount ?? 0;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidSupplementRequested,
        properties: {
          'reason': reason.analyticsValue,
          'suggestion': suggestion == null
              ? 'custom'
              : (suggestion.isGridItem ? 'grid_item' : 'kg'),
          'amount_bracket': analyticsAmountBracket(amount),
          'currency': state.options?.currency ?? bid.currency,
          'payment_method': bid.paymentMethod.name,
          if (state.isCash)
            'commission_source': state.commissionSource.analyticsValue,
        },
      ),
    );
    if (state.isCash) _flow.logCharged(created, state.commissionSource);
  }

  /// Échec avant ou pendant la création (rien n'a été prélevé, sauf débit
  /// carte sans réponse : voir [SupplementRequestStatus.commissionRetry]).
  void _onCreateError(BidModel bid, BidSupplementReason reason, Object e) {
    final error = unwrapDioError(e);
    final code = error.code ?? 'unknown';
    final source = state.commissionSource;
    final unfunded = SupplementCommissionUnfunded.fromError(error);
    if (unfunded != null) {
      emit(
        state.copyWith(
          status: SupplementRequestStatus.unfunded,
          unfunded: () => unfunded,
          error: error,
        ),
      );
      _flow.logFailed(
        source,
        reason: 'insufficient_balance',
        errorCode: code,
        currency: unfunded.currency,
      );
    } else if (code == _cardMissing) {
      emit(
        state.copyWith(
          status: SupplementRequestStatus.cardMissing,
          error: error,
        ),
      );
      _flow.logFailed(source, reason: 'card_missing', errorCode: code);
    } else if (state.isCash &&
        source == SupplementCommissionSource.card &&
        (error is ServiceUnavailableException || error is TimeoutException)) {
      // Débit de la carte resté sans réponse : la demande a pu être créée en
      // `COMMISSION_PENDING`. « Réessayer » la retrouve et la confirme.
      emit(
        state.copyWith(
          status: SupplementRequestStatus.commissionRetry,
          awaitingCommission: true,
          pending: () => null,
          error: error,
        ),
      );
      _flow.logFailed(source, reason: 'generic', errorCode: code);
    } else {
      if (code == _cardDeclined) {
        _flow.logFailed(source, reason: 'declined', errorCode: code);
      }
      emit(
        state.copyWith(
          status: _closingCodes.contains(code)
              ? SupplementRequestStatus.closed
              : SupplementRequestStatus.failure,
          fundingCurrency: code == _fundingCurrencyInvalid ? () => null : null,
          error: error,
        ),
      );
    }
    _logRequestFailed(reason, code);
  }

  /// 3DS abandonnée ou refusée : la demande reste en attente côté serveur.
  void _onAuthInterrupted(BidSupplementReason reason, BidSupplement? pending) {
    emit(
      state.copyWith(
        status: SupplementRequestStatus.commissionRetry,
        awaitingCommission: true,
        pending: () => pending,
      ),
    );
    _flow.logFailed(
      SupplementCommissionSource.card,
      reason: 'authentication_failed',
      errorCode: _authInterruptedCode,
    );
    _logRequestFailed(reason, _authInterruptedCode);
  }

  /// Échec de la confirmation d'une demande déjà créée : carte refusée ou
  /// détachée (demande annulée par le serveur), sinon on réessaiera.
  void _onCommissionError(
    BidSupplementReason reason,
    BidSupplement? pending,
    Object e,
  ) {
    final error = unwrapDioError(e);
    final code = error.code ?? 'unknown';
    final definitive = code == _cardDeclined || code == _cardMissing;
    _flow.logFailed(
      SupplementCommissionSource.card,
      reason: code == _cardDeclined
          ? 'declined'
          : (code == _cardMissing ? 'card_missing' : 'generic'),
      errorCode: code,
    );
    emit(
      state.copyWith(
        status: definitive
            ? SupplementRequestStatus.closed
            : SupplementRequestStatus.commissionRetry,
        awaitingCommission: !definitive,
        pending: () => definitive ? null : pending,
        error: error,
      ),
    );
    _logRequestFailed(reason, code);
  }

  void _logRequestFailed(BidSupplementReason reason, String code) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidSupplementRequestFailed,
        properties: {'reason': reason.analyticsValue, 'error_code': code},
      ),
    );
  }

  static String? _clip(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= kSupplementReasonTextMaxLength
        ? trimmed
        : trimmed.substring(0, kSupplementReasonTextMaxLength);
  }

  @override
  Future<void> close() {
    _quoteTimer?.cancel();
    return super.close();
  }
}

/// Lit un montant saisi (« 15 », « 15,5 », « 1 500 ») ; nul si illisible ou
/// négatif.
double? parseSupplementAmount(String text) {
  final cleaned = text.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0 || value.isNaN || value.isInfinite) {
    return null;
  }
  return value;
}
