import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:equatable/equatable.dart';

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

class NegotiationBloc extends Bloc<NegotiationEvent, NegotiationState> {
  NegotiationBloc(this._repository, {required AnalyticsService analytics})
    : _analytics = analytics,
      super(const NegotiationInitial()) {
    on<NegotiationFetchRequested>(_onFetch);
    on<NegotiationStartRequested>(_onStart);
    on<NegotiationStartWithDedicatedTripRequested>(_onStartWithDedicatedTrip);
    on<NegotiationCounterRequested>(_onCounter);
    on<NegotiationAcceptRequested>(_onAccept);
    on<NegotiationRejectRequested>(_onReject);
    on<NegotiationCancelRequested>(_onCancel);
    on<NegotiationSubmitTripRequested>(_onSubmitTrip);
    on<NegotiationCreateDedicatedTripRequested>(_onCreateDedicatedTrip);
    on<NegotiationCheckoutRequested>(_onCheckout);
    on<NegotiationRefuseTripRequested>(_onRefuseTrip);
    on<NegotiationNudgeRequested>(_onNudge);
  }

  final NegotiationRepository _repository;
  final AnalyticsService _analytics;

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
}
