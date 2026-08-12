import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/models/package_request.dart';
import '../data/package_request_repository.dart';

/// Manages the "Complete delivery details" step for an accepted package
/// request: loads the request (read-only recap + accepted payment methods) and
/// submits the recipient info (name, phone, optional city).
///
/// The screen keeps its TextEditingControllers for local form state, but the
/// network calls + loading/error/success transitions flow through this BLoC,
/// allowing BlocListener-based snackbar + navigation and BlocBuilder-based
/// button loading state.
sealed class CompleteDetailsEvent extends Equatable {
  const CompleteDetailsEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the package request so the screen can show a read-only recap of the
/// already-known details + the accepted payment methods.
class CompleteDetailsStarted extends CompleteDetailsEvent {
  const CompleteDetailsStarted(this.requestId);
  final String requestId;
  @override
  List<Object?> get props => [requestId];
}

class CompleteDetailsSubmitted extends CompleteDetailsEvent {
  const CompleteDetailsSubmitted({
    required this.requestId,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientCity,
  });

  final String requestId;
  final String recipientName;
  final String recipientPhone;
  final String? recipientCity;

  @override
  List<Object?> get props => [
        requestId,
        recipientName,
        recipientPhone,
        recipientCity,
      ];
}

enum CompleteDetailsStatus { initial, loading, success, error }

class CompleteDetailsState extends Equatable {
  const CompleteDetailsState({
    this.status = CompleteDetailsStatus.initial,
    this.errorMessage,
    this.request,
    this.loaded = false,
  });

  final CompleteDetailsStatus status;
  final String? errorMessage;

  /// The loaded request — used to render the read-only recap and to constrain
  /// the payment-method picker to the server-computed SET
  /// (`NegotiationThread.availablePaymentMethods`) when available, falling
  /// back to [PackageRequest.acceptedPaymentMethods] otherwise (cf.
  /// `_availableMethods` in complete_details_screen.dart).
  final PackageRequest? request;

  /// True once the initial load attempt completed (success or failure). The
  /// recipient form stays usable even if the recap could not be loaded.
  final bool loaded;

  bool get isLoading => status == CompleteDetailsStatus.loading;
  bool get isSuccess => status == CompleteDetailsStatus.success;

  CompleteDetailsState copyWith({
    CompleteDetailsStatus? status,
    String? errorMessage,
    PackageRequest? request,
    bool? loaded,
  }) =>
      CompleteDetailsState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        request: request ?? this.request,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [status, errorMessage, request, loaded];
}

class CompleteDetailsBloc
    extends Bloc<CompleteDetailsEvent, CompleteDetailsState> {
  CompleteDetailsBloc(this._repository) : super(const CompleteDetailsState()) {
    on<CompleteDetailsStarted>(_onStarted);
    on<CompleteDetailsSubmitted>(_onSubmit);
  }

  final PackageRequestRepository _repository;

  Future<void> _onStarted(
    CompleteDetailsStarted event,
    Emitter<CompleteDetailsState> emit,
  ) async {
    try {
      final request = await _repository.getById(event.requestId);
      emit(state.copyWith(request: request, loaded: true));
    } catch (_) {
      // Recap is best-effort: the recipient form must remain usable even if the
      // request could not be loaded (e.g. transient network error).
      emit(state.copyWith(loaded: true));
    }
  }

  Future<void> _onSubmit(
    CompleteDetailsSubmitted event,
    Emitter<CompleteDetailsState> emit,
  ) async {
    emit(state.copyWith(status: CompleteDetailsStatus.loading));
    try {
      await _repository.completeDetails(
        event.requestId,
        recipientName: event.recipientName,
        recipientPhone: event.recipientPhone,
        recipientCity: event.recipientCity,
      );
      emit(state.copyWith(status: CompleteDetailsStatus.success));
    } catch (err) {
      emit(state.copyWith(
        status: CompleteDetailsStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }
}
