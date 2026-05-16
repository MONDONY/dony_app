import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
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

  @override
  List<Object?> get props => [
        threadId, departureDate, departureTime, arrivalTime,
        pickupAddress, deliveryAddress, description,
        acceptedContentTypes, refusedTypes,
      ];
}

/// Sender refuses the trip linked to an AWAITING_PAYMENT thread, with a reason.
class NegotiationRefuseTripRequested extends NegotiationEvent {
  const NegotiationRefuseTripRequested({
    required this.threadId,
    this.reason,
  });
  final String threadId;
  final String? reason;

  @override
  List<Object?> get props => [threadId, reason];
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
  const NegotiationError(this.error);
  final AppException error;
  @override
  List<Object?> get props => [error];
}

class NegotiationBloc extends Bloc<NegotiationEvent, NegotiationState> {
  NegotiationBloc(this._repository) : super(const NegotiationInitial()) {
    on<NegotiationFetchRequested>(_onFetch);
    on<NegotiationStartRequested>(_onStart);
    on<NegotiationCounterRequested>(_onCounter);
    on<NegotiationAcceptRequested>(_onAccept);
    on<NegotiationRejectRequested>(_onReject);
    on<NegotiationSubmitTripRequested>(_onSubmitTrip);
    on<NegotiationCreateDedicatedTripRequested>(_onCreateDedicatedTrip);
    on<NegotiationRefuseTripRequested>(_onRefuseTrip);
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
      );
      emit(NegotiationLoaded(thread));
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
      emit(NegotiationError(unwrapDioError(err)));
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
      final thread =
          await _repository.refuseTrip(e.threadId, reason: e.reason);
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
      );
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
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
      emit(NegotiationError(unwrapDioError(err)));
    }
  }
}
