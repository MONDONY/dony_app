import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
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

  bool get isSubmitting => status == SupplementRequestStatus.submitting;

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
      !isSubmitting &&
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
};

/// Feuille « Demander un supplément » du voyageur : montant (suggestion de la
/// grille ou du kilo, ou saisi), motif, détail, photo obligatoire, devis
/// rafraîchi pendant la saisie, puis envoi (`POST /bids/{bidId}/supplements`).
/// Le serveur fige la commission et prévient l'expéditeur.
class SupplementRequestCubit extends Cubit<SupplementRequestState> {
  SupplementRequestCubit(
    this._repository,
    this._media,
    this._analytics, {
    this.quoteDebounce = const Duration(milliseconds: 400),
  }) : super(const SupplementRequestState());

  final BidSupplementRepository _repository;
  final DonyMediaService _media;
  final AnalyticsService _analytics;

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
      emit(state.copyWith(options: options));
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
      ),
    );
    _scheduleQuote();
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

  /// Statut à garder pendant une saisie : un chargement raté reste visible.
  SupplementRequestStatus get _editingStatus =>
      state.status == SupplementRequestStatus.loadFailed
      ? SupplementRequestStatus.loadFailed
      : SupplementRequestStatus.editing;

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
    if (bid == null || !state.canSubmit) return;
    final reason = state.reason!;
    final amount = state.amount!;
    final suggestion = state.suggestion;
    emit(state.copyWith(status: SupplementRequestStatus.submitting));
    try {
      final key =
          state.photoKey ??
          await _repository.uploadPhoto(bid.id, state.photoPath!);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SupplementRequestStatus.submitting,
          photoKey: () => key,
        ),
      );
      final created = await _repository.create(
        bid.id,
        netAmount: amount,
        reason: reason,
        reasonText: _clip(state.reasonText),
        gridItemLabel: reason == BidSupplementReason.gridItem
            ? suggestion?.label
            : null,
        photoKey: key,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SupplementRequestStatus.success,
          created: created,
        ),
      );
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
          },
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(
        state.copyWith(
          status: _closingCodes.contains(error.code)
              ? SupplementRequestStatus.closed
              : SupplementRequestStatus.failure,
          error: error,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidSupplementRequestFailed,
          properties: {
            'reason': reason.analyticsValue,
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
    }
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
