import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/models/negotiation_thread.dart';
import '../data/negotiation_repository.dart';

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

class NegotiationStartRequested extends NegotiationEvent {
  const NegotiationStartRequested({
    required this.packageRequestId,
    required this.proposedPriceEur,
    required this.travelerTravelDate,
    required this.travelerAvailableKg,
    this.travelerAnnouncementId,
    this.body,
  });
  final String packageRequestId;
  final double proposedPriceEur;
  final DateTime travelerTravelDate;
  final double travelerAvailableKg;
  final String? travelerAnnouncementId;
  final String? body;

  @override
  List<Object?> get props => [
        packageRequestId,
        proposedPriceEur,
        travelerTravelDate,
        travelerAvailableKg,
        travelerAnnouncementId,
        body,
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

/// Traveler links a trip (existing announcement) to an AWAITING_TRIP thread.
class NegotiationSubmitTripRequested extends NegotiationEvent {
  const NegotiationSubmitTripRequested({
    required this.threadId,
    required this.travelerAnnouncementId,
  });
  final String threadId;
  final String travelerAnnouncementId;

  @override
  List<Object?> get props => [threadId, travelerAnnouncementId];
}

/// Sender confirms payment on an AWAITING_PAYMENT thread → finalize as ACCEPTED.
class NegotiationCheckoutRequested extends NegotiationEvent {
  const NegotiationCheckoutRequested({
    required this.threadId,
    required this.paymentIntentId,
  });
  final String threadId;
  final String paymentIntentId;

  @override
  List<Object?> get props => [threadId, paymentIntentId];
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
  const NegotiationRejected(this.threadId);
  final String threadId;
  @override
  List<Object?> get props => [threadId];
}

class NegotiationError extends NegotiationState {
  const NegotiationError(this.message, {this.code});
  final String message;
  final String? code;
  @override
  List<Object?> get props => [message, code];
}

class NegotiationBloc extends Bloc<NegotiationEvent, NegotiationState> {
  NegotiationBloc(this._repository) : super(const NegotiationInitial()) {
    on<NegotiationFetchRequested>(_onFetch);
    on<NegotiationStartRequested>(_onStart);
    on<NegotiationCounterRequested>(_onCounter);
    on<NegotiationAcceptRequested>(_onAccept);
    on<NegotiationRejectRequested>(_onReject);
    on<NegotiationSubmitTripRequested>(_onSubmitTrip);
    on<NegotiationCheckoutRequested>(_onCheckout);
  }

  final NegotiationRepository _repository;

  Future<void> _onFetch(
    NegotiationFetchRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    emit(const NegotiationLoading());
    try {
      final thread = await _repository.getById(e.threadId);
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(err.toString()));
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
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(err.toString()));
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
    } catch (err) {
      emit(NegotiationError(err.toString()));
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
    } catch (err) {
      emit(NegotiationError(err.toString()));
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
      emit(NegotiationError(err.toString()));
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
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(err.toString()));
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
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(err.toString()));
    }
  }
}
