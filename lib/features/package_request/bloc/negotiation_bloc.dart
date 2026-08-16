import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:equatable/equatable.dart';
// `flutter_stripe` also exports a `PaymentMethod` class (Stripe's own payment
// method model) which collides with dony's own `PaymentMethod` enum imported
// above — hide it, this bloc only needs `Stripe`/`StripeException` from here.
import 'package:flutter_stripe/flutter_stripe.dart' hide PaymentMethod;

sealed class NegotiationEvent extends Equatable {
  const NegotiationEvent();
  @override
  List<Object?> get props => [];
}

class NegotiationFetchRequested extends NegotiationEvent {
  const NegotiationFetchRequested(this.threadId);
  final String threadId;
  @override
  List<Object?> get props => [threadId];
}

/// Sends a nudge on this thread to prompt the other party to act. Backend
/// validates whether the current viewer is allowed to nudge (returns 429
/// `nudge/rate-limited` when relancé too soon).
class NegotiationNudgeRequested extends NegotiationEvent {
  const NegotiationNudgeRequested(this.threadId);
  final String threadId;
  @override
  List<Object?> get props => [threadId];
}

class NegotiationStartRequested extends NegotiationEvent {
  const NegotiationStartRequested({
    required this.packageRequestId,
    required this.proposedPriceEur,
    required this.travelerTravelDate,
    required this.travelerAvailableKg,
    this.travelerAnnouncementId,
    this.body,
    this.isFirmPrice = false,
    this.createDedicatedTrip = false,
    this.dedicatedTripPayload,
  });
  final String packageRequestId;
  final double proposedPriceEur;
  final DateTime travelerTravelDate;
  final double travelerAvailableKg;
  final String? travelerAnnouncementId;
  final String? body;

  /// True when the traveler accepted a firm (non-negotiable) price.
  final bool isFirmPrice;

  /// True when no existing trip matches: the traveler creates a dedicated
  /// trip atomically with the offer instead of picking one.
  final bool createDedicatedTrip;

  /// Mirrors NegotiationCreateDedicatedTripRequest fields. Required when
  /// [createDedicatedTrip] is true.
  final Map<String, dynamic>? dedicatedTripPayload;

  @override
  List<Object?> get props => [
    packageRequestId,
    proposedPriceEur,
    travelerTravelDate,
    travelerAvailableKg,
    travelerAnnouncementId,
    body,
    isFirmPrice,
    createDedicatedTrip,
    dedicatedTripPayload,
  ];
}

/// Mirrors `NegotiationCreateDedicatedTripRequest` fields (backend DTO) —
/// shared shape between [NegotiationCreateDedicatedTripRequested] (linked to
/// an existing AWAITING_TRIP thread) and
/// [NegotiationStartWithDedicatedTripRequested] (no thread yet, created
/// atomically with the offer).
class DedicatedTripPayload extends Equatable {
  const DedicatedTripPayload({
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.description,
    this.acceptedContentTypes,
    this.refusedTypes,
    this.useCardForCommission = false,
  });

  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final Map<String, dynamic> pickupAddress;
  final Map<String, dynamic> deliveryAddress;
  final String? description;
  final List<String>? acceptedContentTypes;
  final List<String>? refusedTypes;

  /// CASH only: traveler consents to pay the commission on their card when
  /// the wallet is short (charged at finalize, wallet-first then card).
  final bool useCardForCommission;

  Map<String, dynamic> toJson() => {
    'departureDate': departureDate.toIso8601String().substring(0, 10),
    if (departureTime != null) 'departureTime': departureTime,
    if (arrivalTime != null) 'arrivalTime': arrivalTime,
    'pickupAddress': pickupAddress,
    'deliveryAddress': deliveryAddress,
    if (description != null) 'description': description,
    if (acceptedContentTypes != null)
      'acceptedContentTypes': acceptedContentTypes,
    if (refusedTypes != null) 'refusedTypes': refusedTypes,
    'useCardForCommission': useCardForCommission,
  };

  @override
  List<Object?> get props => [
    departureDate,
    departureTime,
    arrivalTime,
    pickupAddress,
    deliveryAddress,
    description,
    acceptedContentTypes,
    refusedTypes,
    useCardForCommission,
  ];
}

/// Creates the offer AND a dedicated trip atomically (no existing negotiation
/// thread yet) — used from `CreateTripScreen` when
/// `LockedTripContext.threadId` is null (traveler reached the create-trip
/// form directly from a package request, not from an AWAITING_TRIP thread).
class NegotiationStartWithDedicatedTripRequested extends NegotiationEvent {
  const NegotiationStartWithDedicatedTripRequested({
    required this.packageRequestId,
    required this.proposedPriceEur,
    required this.travelerTravelDate,
    required this.travelerAvailableKg,
    required this.dedicatedTrip,
    this.body,
    this.isFirmPrice = false,
  });
  final String packageRequestId;
  final double proposedPriceEur;
  final DateTime travelerTravelDate;
  final double travelerAvailableKg;
  final DedicatedTripPayload dedicatedTrip;
  final String? body;

  /// True when the traveler accepted a firm (non-negotiable) price.
  final bool isFirmPrice;

  @override
  List<Object?> get props => [
    packageRequestId,
    proposedPriceEur,
    travelerTravelDate,
    travelerAvailableKg,
    dedicatedTrip,
    body,
    isFirmPrice,
  ];
}

class NegotiationCounterRequested extends NegotiationEvent {
  const NegotiationCounterRequested({
    required this.threadId,
    required this.proposedPriceEur,
    this.body,
  });
  final String threadId;
  final double proposedPriceEur;
  final String? body;

  @override
  List<Object?> get props => [threadId, proposedPriceEur, body];
}

class NegotiationAcceptRequested extends NegotiationEvent {
  const NegotiationAcceptRequested({required this.threadId, this.body});
  final String threadId;
  final String? body;

  @override
  List<Object?> get props => [threadId, body];
}

class NegotiationRejectRequested extends NegotiationEvent {
  const NegotiationRejectRequested({required this.threadId, this.reason});
  final String threadId;
  final String? reason;

  @override
  List<Object?> get props => [threadId, reason];
}

/// Either party ends the negotiation thread ("end negotiation"). Terminal,
/// mirrors [NegotiationRejectRequested].
class NegotiationCancelRequested extends NegotiationEvent {
  const NegotiationCancelRequested({required this.threadId, this.reason});
  final String threadId;
  final String? reason;

  @override
  List<Object?> get props => [threadId, reason];
}

/// Traveler links a trip (existing announcement) to an AWAITING_TRIP thread.
class NegotiationSubmitTripRequested extends NegotiationEvent {
  const NegotiationSubmitTripRequested({
    required this.threadId,
    required this.travelerAnnouncementId,
    required this.paymentMethod,
    this.useCardForCommission = false,
  });
  final String threadId;
  final String travelerAnnouncementId;
  final PaymentMethod paymentMethod;

  /// CASH only: traveler consents to pay the commission on their card when the
  /// wallet is short (charged at finalize, wallet-first then card).
  final bool useCardForCommission;

  @override
  List<Object?> get props => [
    threadId,
    travelerAnnouncementId,
    paymentMethod,
    useCardForCommission,
  ];
}

/// Traveler creates a dedicated trip (no existing announcement matches) and
/// links it to an AWAITING_TRIP thread in a single atomic call.
class NegotiationCreateDedicatedTripRequested extends NegotiationEvent {
  const NegotiationCreateDedicatedTripRequested({
    required this.threadId,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.description,
    this.acceptedContentTypes,
    this.refusedTypes,
    required this.paymentMethod,
    this.useCardForCommission = false,
  });
  final String threadId;
  final DateTime departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final Map<String, dynamic> pickupAddress;
  final Map<String, dynamic> deliveryAddress;
  final String? description;
  final List<String>? acceptedContentTypes;
  final List<String>? refusedTypes;
  final PaymentMethod paymentMethod;

  /// CASH only: traveler consents to pay the commission on their card when the
  /// wallet is short (charged at finalize, wallet-first then card). Mirrors
  /// [NegotiationSubmitTripRequested.useCardForCommission].
  final bool useCardForCommission;

  @override
  List<Object?> get props => [
    threadId,
    departureDate,
    departureTime,
    arrivalTime,
    pickupAddress,
    deliveryAddress,
    description,
    acceptedContentTypes,
    refusedTypes,
    paymentMethod,
    useCardForCommission,
  ];
}

/// Sender confirms payment on an AWAITING_PAYMENT thread → finalize as ACCEPTED.
class NegotiationCheckoutRequested extends NegotiationEvent {
  const NegotiationCheckoutRequested({
    required this.threadId,
    required this.paymentIntentId,
    this.paymentMethod,
  });
  final String threadId;
  final String paymentIntentId;

  /// Mode de paiement finalisé par l'expéditeur (parmi ceux acceptés). `null` →
  /// le backend garde le mode déjà porté par le thread.
  final PaymentMethod? paymentMethod;

  @override
  List<Object?> get props => [threadId, paymentIntentId, paymentMethod];
}

/// Sender refuses the linked trip on an AWAITING_PAYMENT thread.
class NegotiationRefuseTripRequested extends NegotiationEvent {
  const NegotiationRefuseTripRequested({required this.threadId, this.reason});
  final String threadId;
  final String? reason;
  @override
  List<Object?> get props => [threadId, reason];
}

/// Traveler changes the trip already linked to an `OPEN` thread (before
/// payment). Distinct from [NegotiationSubmitTripRequested], which still
/// serves the legacy `AWAITING_TRIP` recovery loop (post-`refuseTrip`).
class NegotiationChangeTripRequested extends NegotiationEvent {
  const NegotiationChangeTripRequested({
    required this.threadId,
    required this.travelerAnnouncementId,
  });
  final String threadId;
  final String travelerAnnouncementId;

  @override
  List<Object?> get props => [threadId, travelerAnnouncementId];
}

/// Traveler settles the Yadony commission for a cash-agreed offer the sender
/// already accepted. Nothing is sealed until this succeeds : the sender's
/// acceptance alone doesn't finalize a cash deal, the traveler must confirm
/// by paying the commission (or renouncing) within the settlement deadline.
class NegotiationSettleCommissionRequested extends NegotiationEvent {
  const NegotiationSettleCommissionRequested(
    this.threadId, {
    this.useCard = false,
  });
  final String threadId;

  /// True forces `commissionSource=CARD` (retry chosen by the traveler after
  /// an insufficient-wallet response). False uses `WALLET_FIRST`.
  final bool useCard;

  @override
  List<Object?> get props => [threadId, useCard];
}

/// Traveler explicitly renounces settling the commission. The request is
/// released immediately for another traveler instead of waiting out the
/// settlement deadline.
class NegotiationDeclineCommissionRequested extends NegotiationEvent {
  const NegotiationDeclineCommissionRequested(this.threadId);
  final String threadId;
  @override
  List<Object?> get props => [threadId];
}

sealed class NegotiationState extends Equatable {
  const NegotiationState();
  @override
  List<Object?> get props => [];
}

class NegotiationInitial extends NegotiationState {
  const NegotiationInitial();
}

class NegotiationLoading extends NegotiationState {
  const NegotiationLoading();
}

class NegotiationActionInProgress extends NegotiationState {
  const NegotiationActionInProgress(this.thread);
  final NegotiationThread thread;
  @override
  List<Object?> get props => [thread];
}

class NegotiationLoaded extends NegotiationState {
  const NegotiationLoaded(this.thread);
  final NegotiationThread thread;
  @override
  List<Object?> get props => [thread];
}

class NegotiationRejected extends NegotiationState {
  const NegotiationRejected(this.threadId, {this.cancelled = false});
  final String threadId;

  /// True when this thread ended via [NegotiationCancelRequested] ("end
  /// negotiation" from the ... menu) rather than [NegotiationRejectRequested]
  /// (reject bottom sheet) — the only difference between the two flows,
  /// used by the screen to pick the right snackbar wording.
  final bool cancelled;
  @override
  List<Object?> get props => [threadId, cancelled];
}

class NegotiationError extends NegotiationState {
  const NegotiationError(this.error);
  final AppException error;
  @override
  List<Object?> get props => [error];
}

/// Nudge sent successfully. Carries the refreshed thread (server-computed
/// `canNudge` now false) plus, by its very type, a one-shot signal for the
/// UI to show a "Relance envoyée" confirmation — distinct from
/// [NegotiationLoaded] so the CTA bar can react to this specific action
/// without hijacking every other success transition into the loaded state.
class NegotiationNudgeSent extends NegotiationState {
  const NegotiationNudgeSent(this.thread);
  final NegotiationThread thread;
  @override
  List<Object?> get props => [thread];
}

/// Nudge failed. Dedicated type (not [NegotiationError]) so the screen's
/// generic error listener doesn't also surface a second, generic error
/// snackbar — the CTA bar alone maps `error.code == 'nudge/rate-limited'` to
/// "Déjà relancé récemment", any other code to a generic retry message.
class NegotiationNudgeError extends NegotiationState {
  const NegotiationNudgeError(this.error);
  final AppException error;
  @override
  List<Object?> get props => [error];
}

/// The Yadony commission for this cash-agreed offer has been settled : the
/// deal is now sealed. Reached either directly (wallet had enough) or after
/// a successful 3D Secure authentication + [NegotiationRepository.confirmCommission].
class NegotiationCommissionSettled extends NegotiationState {
  const NegotiationCommissionSettled(this.threadId);
  final String threadId;
  @override
  List<Object?> get props => [threadId];
}

/// The traveler's wallet balance doesn't cover the required commission.
/// Dedicated type (not [NegotiationError]) : it carries the amounts to
/// display, not a generic error, mirroring [BidWalletInsufficient] on the
/// classic bid-acceptance flow.
class NegotiationCommissionInsufficientWallet extends NegotiationState {
  const NegotiationCommissionInsufficientWallet({
    required this.availableBalance,
    required this.requiredCommission,
    required this.hasCard,
    required this.threadId,
    this.currency,
  });
  final double availableBalance;
  final double requiredCommission;
  final bool hasCard;
  final String threadId;
  final String? currency;
  @override
  List<Object?> get props => [
    availableBalance,
    requiredCommission,
    hasCard,
    threadId,
    currency,
  ];
}

/// The traveler explicitly renounced settling the commission : the request
/// was released immediately for another traveler.
class NegotiationCommissionDeclined extends NegotiationState {
  const NegotiationCommissionDeclined(this.threadId);
  final String threadId;
  @override
  List<Object?> get props => [threadId];
}

class NegotiationBloc extends Bloc<NegotiationEvent, NegotiationState> {
  NegotiationBloc(
    this._repository, {
    required AnalyticsService analytics,
    Stripe? stripe,
  }) : _analytics = analytics,
       _stripe = stripe ?? Stripe.instance,
       super(const NegotiationInitial()) {
    on<NegotiationFetchRequested>(_onFetch);
    on<NegotiationStartRequested>(_onStart);
    on<NegotiationStartWithDedicatedTripRequested>(_onStartWithDedicatedTrip);
    on<NegotiationCounterRequested>(_onCounter);
    on<NegotiationAcceptRequested>(_onAccept);
    on<NegotiationRejectRequested>(_onReject);
    on<NegotiationCancelRequested>(_onCancel);
    on<NegotiationSubmitTripRequested>(_onSubmitTrip);
    on<NegotiationChangeTripRequested>(_onChangeTrip);
    on<NegotiationCreateDedicatedTripRequested>(_onCreateDedicatedTrip);
    on<NegotiationCheckoutRequested>(_onCheckout);
    on<NegotiationRefuseTripRequested>(_onRefuseTrip);
    on<NegotiationNudgeRequested>(_onNudge);
    on<NegotiationSettleCommissionRequested>(_onSettleCommission);
    on<NegotiationDeclineCommissionRequested>(_onDeclineCommission);
  }

  final NegotiationRepository _repository;
  final AnalyticsService _analytics;
  final Stripe _stripe;

  /// Maps the 422 reasons the back-end returns from `submitTrip` /
  /// `createDedicatedTrip` when the traveler can't honor any payment method
  /// the sender accepted, to a PII-free analytics reason.
  static const _paymentBlockReasons = {
    'payment-method/card-capability-required': 'no_card',
    'payment-method/cash-funds-required': 'no_cash_funds',
    'payment-method/none-available': 'none',
  };

  /// `null` when [err] isn't one of the trip-linking payment-capability block
  /// reasons above (network error, or an unrelated business error).
  static String? _paymentBlockReason(AppException err) =>
      _paymentBlockReasons[err.code];

  /// Fires `payment_method_selected` for the sender's final choice at
  /// checkout — the only point where a real user picks a payment method
  /// now that trip-linking uses a backend-computed capability set.
  /// `null` when the backend keeps the thread's already-decided method.
  void _logCheckoutPaymentMethodSelected(PaymentMethod? method) {
    if (method == null) {
      return;
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.paymentMethodSelected,
        properties: {'method': method.wireName},
      ),
    );
  }

  /// Tranche de montant pour l'analytics, sans PII et **sans symbole monétaire**.
  ///
  /// Les bornes s'entendaient auparavant en euros et portaient le « € » dans leur
  /// libellé, alors qu'elles s'appliquaient au montant brut quelle que soit la
  /// devise : une proposition de 5 000 XOF, soit environ 7,60 €, atterrissait
  /// dans « >100€ » et faussait toute lecture des données. La tranche est donc
  /// neutre et la devise est envoyée à côté, ce qui permet de segmenter
  /// correctement sans jamais convertir de montant.
  static String _amountBracket(double amount) {
    if (amount < 20) return '<20';
    if (amount < 50) return '20-50';
    if (amount < 100) return '50-100';
    return '>100';
  }

  Future<void> _onFetch(
    NegotiationFetchRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    emit(const NegotiationLoading());
    try {
      final thread = await _repository.getById(e.threadId);
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onStart(
    NegotiationStartRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    emit(const NegotiationLoading());
    try {
      final thread = await _repository.start(
        packageRequestId: e.packageRequestId,
        proposedPriceEur: e.proposedPriceEur,
        travelerTravelDate: e.travelerTravelDate,
        travelerAvailableKg: e.travelerAvailableKg,
        travelerAnnouncementId: e.travelerAnnouncementId,
        body: e.body,
        createDedicatedTrip: e.createDedicatedTrip,
        dedicatedTripPayload: e.dedicatedTripPayload,
      );
      emit(NegotiationLoaded(thread));
      if (e.isFirmPrice) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.firmPriceTaken,
            properties: {'request_id': e.packageRequestId},
          ),
        );
      } else {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.negotiationOfferMade,
            properties: {
              'amount_bracket': _amountBracket(e.proposedPriceEur),
              'currency': ActiveCurrency.current?.code ?? 'unknown',
              'context': 'sender',
            },
          ),
        );
      }
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onStartWithDedicatedTrip(
    NegotiationStartWithDedicatedTripRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    emit(const NegotiationLoading());
    try {
      final thread = await _repository.start(
        packageRequestId: e.packageRequestId,
        proposedPriceEur: e.proposedPriceEur,
        travelerTravelDate: e.travelerTravelDate,
        travelerAvailableKg: e.travelerAvailableKg,
        body: e.body,
        createDedicatedTrip: true,
        dedicatedTripPayload: e.dedicatedTrip.toJson(),
      );
      emit(NegotiationLoaded(thread));
      if (e.isFirmPrice) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.firmPriceTaken,
            properties: {'request_id': e.packageRequestId},
          ),
        );
      } else {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.negotiationOfferMade,
            properties: {
              'amount_bracket': _amountBracket(e.proposedPriceEur),
              'currency': ActiveCurrency.current?.code ?? 'unknown',
              'context': 'sender',
            },
          ),
        );
      }
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onCounter(
    NegotiationCounterRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.counter(
        e.threadId,
        proposedPriceEur: e.proposedPriceEur,
        body: e.body,
      );
      emit(NegotiationLoaded(thread));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.negotiationOfferMade,
          properties: {
            'amount_bracket': _amountBracket(e.proposedPriceEur),
            'currency': ActiveCurrency.current?.code ?? 'unknown',
            'context': 'counter',
          },
        ),
      );
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onAccept(
    NegotiationAcceptRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.accept(e.threadId, body: e.body);
      emit(NegotiationLoaded(thread));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.negotiationOfferAccepted,
          properties: {
            'amount_bracket': _amountBracket(thread.currentPriceEur),
            'currency': thread.currency,
          },
        ),
      );
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onReject(
    NegotiationRejectRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      await _repository.reject(e.threadId, reason: e.reason);
      emit(NegotiationRejected(e.threadId));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onCancel(
    NegotiationCancelRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      await _repository.cancel(e.threadId, reason: e.reason);
      unawaited(_analytics.logEvent(AnalyticsEvents.negotiationCancelled));
      emit(NegotiationRejected(e.threadId, cancelled: true));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onSubmitTrip(
    NegotiationSubmitTripRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.submitTrip(
        e.threadId,
        travelerAnnouncementId: e.travelerAnnouncementId,
        paymentMethod: e.paymentMethod,
        useCardForCommission: e.useCardForCommission,
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      final appErr = unwrapDioError(err);
      final blockReason = _paymentBlockReason(appErr);
      if (blockReason != null) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.tripLinkPaymentBlocked,
            properties: {'reason': blockReason},
          ),
        );
      }
      emit(NegotiationError(appErr));
    }
  }

  Future<void> _onChangeTrip(
    NegotiationChangeTripRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.changeTrip(
        e.threadId,
        travelerAnnouncementId: e.travelerAnnouncementId,
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onCreateDedicatedTrip(
    NegotiationCreateDedicatedTripRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.createDedicatedTrip(
        e.threadId,
        departureDate: e.departureDate,
        departureTime: e.departureTime,
        arrivalTime: e.arrivalTime,
        pickupAddress: e.pickupAddress,
        deliveryAddress: e.deliveryAddress,
        description: e.description,
        acceptedContentTypes: e.acceptedContentTypes,
        refusedTypes: e.refusedTypes,
        paymentMethod: e.paymentMethod,
        useCardForCommission: e.useCardForCommission,
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      final appErr = unwrapDioError(err);
      final blockReason = _paymentBlockReason(appErr);
      if (blockReason != null) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.tripLinkPaymentBlocked,
            properties: {'reason': blockReason},
          ),
        );
      }
      emit(NegotiationError(appErr));
    }
  }

  Future<void> _onCheckout(
    NegotiationCheckoutRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.checkout(
        e.threadId,
        paymentIntentId: e.paymentIntentId,
        paymentMethod: e.paymentMethod,
      );
      emit(NegotiationLoaded(thread));
      _logCheckoutPaymentMethodSelected(e.paymentMethod);
    } catch (err) {
      final appErr = unwrapDioError(err);
      // Course gagnée par le webhook Stripe : `payment_intent.amount_capturable_updated`
      // finalise le thread en ACCEPTED de façon asynchrone (côté serveur). Il peut
      // arriver AVANT ce /checkout synchrone (safety-net). Dans ce cas le backend
      // répond 409 `thread/not-awaiting-payment` alors que le paiement a RÉUSSI.
      // On ne montre donc pas d'erreur : on recharge le thread (désormais finalisé)
      // pour que l'écran affiche l'état « Demande acceptée et payée ».
      if (appErr is ConflictException &&
          appErr.message == 'thread/not-awaiting-payment') {
        try {
          final thread = await _repository.getById(e.threadId);
          emit(NegotiationLoaded(thread));
          _logCheckoutPaymentMethodSelected(e.paymentMethod);
          return;
        } catch (_) {
          // Re-fetch échoué → on retombe sur l'erreur d'origine ci-dessous.
        }
      }
      emit(NegotiationError(appErr));
    }
  }

  Future<void> _onRefuseTrip(
    NegotiationRefuseTripRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.refuseTrip(e.threadId, reason: e.reason);
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }

  Future<void> _onNudge(
    NegotiationNudgeRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread = await _repository.nudge(e.threadId);
      unawaited(_analytics.logEvent(AnalyticsEvents.negotiationNudgeSent));
      emit(NegotiationNudgeSent(thread));
    } catch (err) {
      emit(NegotiationNudgeError(unwrapDioError(err)));
    }
  }

  Future<void> _onSettleCommission(
    NegotiationSettleCommissionRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    // Garde-fou anti double-débit : un règlement de commission est un débit
    // d'argent, jamais deux en vol simultanément. Un second event reçu
    // pendant qu'un premier règlement/renoncement est encore en cours
    // (ActionInProgress/Loading) est ignoré silencieusement. Ceci vient en
    // plus de la désactivation du bouton côté écran, pas à sa place.
    if (current is NegotiationActionInProgress ||
        current is NegotiationLoading) {
      return;
    }
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      // Reprise d'une authentification bancaire interrompue : le voyageur a
      // basculé vers son application bancaire et l'OS a tué dony entre-temps.
      // Il faut confirmer le PaymentIntent existant, surtout pas en relancer
      // un : la clé d'idempotence Stripe rejouerait « authentification
      // requise » en boucle et il ne pourrait plus jamais aboutir. Si la
      // confirmation n'aboutit pas, le serveur marque l'échec et incrémente
      // son compteur de réessai, ce qui autorise le nouveau règlement ci-dessous.
      final resumed =
          current is NegotiationLoaded &&
          current.thread.commissionStatus == 'REQUIRES_3DS';
      if (resumed) {
        final c = await _repository.confirmCommission(e.threadId);
        if (c.accepted) {
          emit(NegotiationCommissionSettled(e.threadId));
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.negotiationCommissionSettled,
              properties: {'thread_id': e.threadId},
            ),
          );
          return;
        }
      }
      final response = await _repository.settleCommission(
        e.threadId,
        commissionSource: e.useCard ? 'CARD' : 'WALLET_FIRST',
      );
      await _handleCommissionResponse(response, e.threadId, emit);
    } catch (err) {
      _emitCommissionFailure(err, e.threadId, emit);
    }
  }

  /// Codes que le serveur renvoie quand la course est perdue : la demande est
  /// partie à un autre voyageur, ou l'attente s'est terminée autrement.
  static const _commissionRaceLostCodes = {
    'request/already-accepted',
    'thread/not-awaiting-commission',
  };

  /// Émet l'échec, et recharge le fil quand la place est prise : sans ce
  /// rechargement l'écran reste bloqué sur l'ancien état, le bouton « Régler la
  /// commission » redevient actif, et le voyageur peut retaper indéfiniment sans
  /// jamais apprendre que le colis lui a échappé.
  void _emitCommissionFailure(
    Object err,
    String threadId,
    Emitter<NegotiationState> emit,
  ) {
    final failure = unwrapDioError(err);
    emit(NegotiationError(failure));
    if (_commissionRaceLostCodes.contains(failure.code)) {
      add(NegotiationFetchRequested(threadId));
    }
  }

  /// Mirrors `BidAcceptanceBloc._handleResponse`, scoped to a negotiation
  /// thread instead of a materialized bid : the traveler is in front of
  /// their phone at this instant, so a strong (3DS) authentication is
  /// achievable right away.
  Future<void> _handleCommissionResponse(
    AcceptanceResponse r,
    String threadId,
    Emitter<NegotiationState> emit,
  ) async {
    switch (r.status) {
      case AcceptanceStatus.accepted:
        emit(NegotiationCommissionSettled(threadId));
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.negotiationCommissionSettled,
            properties: {'thread_id': threadId},
          ),
        );
        return;
      case AcceptanceStatus.requires3ds:
        try {
          await _stripe.handleNextAction(r.clientSecret!);
          final c = await _repository.confirmCommission(threadId);
          if (c.accepted) {
            emit(NegotiationCommissionSettled(threadId));
            unawaited(
              _analytics.logEvent(
                AnalyticsEvents.negotiationCommissionSettled,
                properties: {'thread_id': threadId},
              ),
            );
          } else {
            emit(
              NegotiationError(
                ValidationException(
                  c.error ?? 'Confirmation du règlement échouée',
                  code: 'commission/confirm-failed',
                ),
              ),
            );
          }
        } on StripeException {
          emit(
            const NegotiationError(
              ValidationException(
                'Authentification bancaire interrompue',
                code: 'commission/3ds-interrupted',
              ),
            ),
          );
        }
        return;
      case AcceptanceStatus.insufficientWallet:
        emit(
          NegotiationCommissionInsufficientWallet(
            availableBalance: r.availableBalance ?? 0,
            requiredCommission: r.requiredCommission ?? 0,
            hasCard: r.hasCard ?? false,
            threadId: threadId,
            currency: r.currency,
          ),
        );
        return;
      case AcceptanceStatus.failed:
        emit(
          NegotiationError(
            ValidationException(
              r.error ?? 'Règlement de la commission refusé',
              code: 'commission/failed',
            ),
          ),
        );
        return;
    }
  }

  Future<void> _onDeclineCommission(
    NegotiationDeclineCommissionRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    // Même garde-fou que _onSettleCommission : le renoncement libère la
    // demande, un double envoi ne doit pas déclencher deux appels réseau
    // concurrents (idempotence non garantie côté backend supposée).
    if (current is NegotiationActionInProgress ||
        current is NegotiationLoading) {
      return;
    }
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      await _repository.declineCommission(e.threadId);
      unawaited(
        _analytics.logEvent(AnalyticsEvents.negotiationCommissionDeclined),
      );
      emit(NegotiationCommissionDeclined(e.threadId));
    } catch (err) {
      _emitCommissionFailure(err, e.threadId, emit);
    }
  }
}
